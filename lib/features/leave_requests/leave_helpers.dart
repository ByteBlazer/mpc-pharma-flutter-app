import '../departments/department_models.dart';
import 'leave_models.dart';

/// Mirrors server defaults (IST calendar dates).
const leaveEarliestApplyOffsetDays = 0;
const leaveMaxForwardDays = 14;

DateTime istNow() {
  final utc = DateTime.now().toUtc();
  return utc.add(const Duration(hours: 5, minutes: 30));
}

DateTime istToday() {
  final ist = istNow();
  return DateTime(ist.year, ist.month, ist.day);
}

DateTime leaveEarliestAllowedDate() =>
    istToday().add(Duration(days: leaveEarliestApplyOffsetDays));

DateTime leaveLatestAllowedDate() =>
    istToday().add(Duration(days: leaveMaxForwardDays));

String formatLeaveDateForApi(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Display format for leave screens and modals.
String formatLeaveDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  final y = date.year.toString().padLeft(4, '0');
  return '$d-$m-$y';
}

String formatLeaveDateString(String apiDate) {
  final parsed = parseLeaveDate(apiDate);
  if (parsed == null) return apiDate;
  return formatLeaveDate(parsed);
}

String leaveDateRangeLabel(LeaveRequest leave) {
  final from = formatLeaveDateString(leave.fromDate);
  final to = formatLeaveDateString(leave.toDate);
  return leave.isSingleDay ? from : '$from → $to';
}

String formatLeaveDateTimeDisplay(DateTime dateTime) {
  final local = dateTime.toLocal();
  final date = formatLeaveDate(
    DateTime(local.year, local.month, local.day),
  );
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$date $hour:$minute';
}

DateTime? parseLeaveDate(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

bool isLeaveDateInAllowedWindow(DateTime date) {
  final earliest = leaveEarliestAllowedDate();
  final latest = leaveLatestAllowedDate();
  return !date.isBefore(earliest) && !date.isAfter(latest);
}

String? validateLeaveDateRange({
  required DateTime fromDate,
  required DateTime toDate,
  required LeaveSession session,
}) {
  if (fromDate.isAfter(toDate)) {
    return 'From date cannot be after to date.';
  }
  if (fromDate != toDate &&
      session != LeaveSession.fullDay) {
    return 'Half-day leave is only allowed for a single date.';
  }

  for (
    var day = fromDate;
    !day.isAfter(toDate);
    day = day.add(const Duration(days: 1))
  ) {
    if (!isLeaveDateInAllowedWindow(day)) {
      return 'Leave date ${formatLeaveDate(day)} is outside the allowed '
          'window (${formatLeaveDate(leaveEarliestAllowedDate())} to '
          '${formatLeaveDate(leaveLatestAllowedDate())}, IST).';
    }
  }
  return null;
}

List<Department> departmentsForUser(
  List<Department> departments,
  String userId,
) {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) return const [];
  return departments
      .where(
        (department) =>
            department.isActive &&
            department.users.any((user) => user.id == trimmedUserId),
      )
      .toList();
}

List<DepartmentUser> activeDepartmentLeads(Department department) {
  return department.users
      .where((user) => user.isDepartmentLead && user.isActive)
      .toList();
}

bool userIsDepartmentLead(List<Department> departments, String userId) {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) return false;
  return departments.any(
    (department) => department.users.any(
      (user) => user.id == trimmedUserId && user.isDepartmentLead,
    ),
  );
}

Set<String> departmentIdsLedByUser(
  List<Department> departments,
  String userId,
) {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) return const {};
  return {
    for (final department in departments)
      if (department.users.any(
        (user) => user.id == trimmedUserId && user.isDepartmentLead,
      ))
        department.id,
  };
}

bool canActOnLeaveRequest({
  required LeaveRequest leave,
  required Set<String> leadDepartmentIds,
}) {
  return leave.status.isPending && leadDepartmentIds.contains(leave.departmentId);
}

String leavesToCsv(List<LeaveRequest> leaves) {
  final rows = <List<String>>[
    [
      'Leave ID',
      'Requester',
      'Department',
      'Nominated Approver',
      'From Date',
      'To Date',
      'Session',
      'Status',
      'Request Comment',
      'Acted By',
      'Action Comment',
      'Action At',
      'Created At',
    ],
    ...leaves.map(
      (leave) => [
        leave.leaveId.toString(),
        leave.requesterName,
        leave.departmentName,
        leave.nominatedApproverName,
        leave.fromDateDisplay,
        leave.toDateDisplay,
        leave.leaveSession.label,
        leave.status.label,
        leave.requestComment,
        leave.actedByName ?? '',
        leave.actionComment ?? '',
        leave.actionAt == null
            ? ''
            : formatLeaveDateTimeDisplay(leave.actionAt!),
        leave.createdAt == null
            ? ''
            : formatLeaveDateTimeDisplay(leave.createdAt!),
      ],
    ),
  ];
  return rows
      .map(
        (row) => row
            .map(
              (cell) =>
                  '"${cell.replaceAll('"', '""')}"',
            )
            .join(','),
      )
      .join('\n');
}

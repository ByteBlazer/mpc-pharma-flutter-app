typedef JsonMap = Map<String, dynamic>;

enum LeaveSession {
  fullDay('FULL_DAY'),
  firstHalf('FIRST_HALF'),
  secondHalf('SECOND_HALF');

  const LeaveSession(this.apiValue);

  final String apiValue;

  static LeaveSession fromApi(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    return LeaveSession.values.firstWhere(
      (session) => session.apiValue == normalized,
      orElse: () => LeaveSession.fullDay,
    );
  }

  String get label => switch (this) {
    LeaveSession.fullDay => 'Full day',
    LeaveSession.firstHalf => 'First half (morning)',
    LeaveSession.secondHalf => 'Second half (evening)',
  };
}

enum LeaveStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED'),
  withdrawn('WITHDRAWN');

  const LeaveStatus(this.apiValue);

  final String apiValue;

  static LeaveStatus fromApi(String? value) {
    final normalized = value?.trim().toUpperCase() ?? '';
    return LeaveStatus.values.firstWhere(
      (status) => status.apiValue == normalized,
      orElse: () => LeaveStatus.pending,
    );
  }

  String get label => switch (this) {
    LeaveStatus.pending => 'Pending',
    LeaveStatus.approved => 'Approved',
    LeaveStatus.rejected => 'Rejected',
    LeaveStatus.withdrawn => 'Withdrawn',
  };

  bool get isPending => this == LeaveStatus.pending;
}

class LeaveRequest {
  const LeaveRequest({
    required this.leaveId,
    required this.requesterId,
    required this.requesterName,
    required this.departmentId,
    required this.departmentName,
    required this.nominatedApproverId,
    required this.nominatedApproverName,
    required this.fromDate,
    required this.toDate,
    required this.leaveSession,
    required this.status,
    required this.requestComment,
    required this.actedById,
    required this.actedByName,
    required this.actionComment,
    required this.actionAt,
    required this.createdAt,
    required this.lastUpdatedAt,
  });

  factory LeaveRequest.fromJson(JsonMap json) {
    return LeaveRequest(
      leaveId: _intValue(json['leaveId']),
      requesterId: _string(json['requesterId']),
      requesterName: _string(json['requesterName']),
      departmentId: _string(json['departmentId']),
      departmentName: _string(json['departmentName']),
      nominatedApproverId: _string(json['nominatedApproverId']),
      nominatedApproverName: _string(json['nominatedApproverName']),
      fromDate: _string(json['fromDate']),
      toDate: _string(json['toDate']),
      leaveSession: LeaveSession.fromApi(_string(json['leaveSession'])),
      status: LeaveStatus.fromApi(_string(json['status'])),
      requestComment: _string(json['requestComment']),
      actedById: _nullableString(json['actedById']),
      actedByName: _nullableString(json['actedByName']),
      actionComment: _nullableString(json['actionComment']),
      actionAt: _nullableDate(json['actionAt']),
      createdAt: _nullableDate(json['createdAt']),
      lastUpdatedAt: _nullableDate(json['lastUpdatedAt']),
    );
  }

  final int leaveId;
  final String requesterId;
  final String requesterName;
  final String departmentId;
  final String departmentName;
  final String nominatedApproverId;
  final String nominatedApproverName;
  final String fromDate;
  final String toDate;
  final LeaveSession leaveSession;
  final LeaveStatus status;
  final String requestComment;
  final String? actedById;
  final String? actedByName;
  final String? actionComment;
  final DateTime? actionAt;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;

  bool get isSingleDay => fromDate == toDate;

  String get dateRangeLabel =>
      isSingleDay ? fromDate : '$fromDate → $toDate';

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final haystack = [
      leaveId.toString(),
      requesterId,
      requesterName,
      departmentId,
      departmentName,
      nominatedApproverId,
      nominatedApproverName,
      fromDate,
      toDate,
      leaveSession.label,
      status.label,
      requestComment,
      actionComment ?? '',
      actedByName ?? '',
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static String? _nullableString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _nullableDate(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}

class LeaveListResponse {
  const LeaveListResponse({
    required this.success,
    required this.message,
    required this.leaves,
    required this.totalLeaves,
  });

  factory LeaveListResponse.fromJson(JsonMap json) {
    final leavesJson = json['leaves'];
    return LeaveListResponse(
      success: json['success'] == true,
      message: LeaveRequest._string(json['message']),
      leaves: leavesJson is List
          ? leavesJson
                .whereType<JsonMap>()
                .map(LeaveRequest.fromJson)
                .toList()
          : const [],
      totalLeaves: LeaveRequest._intValue(json['totalLeaves']),
    );
  }

  final bool success;
  final String message;
  final List<LeaveRequest> leaves;
  final int totalLeaves;
}

class ApplyLeaveRequest {
  const ApplyLeaveRequest({
    required this.departmentId,
    required this.nominatedApproverAppUserId,
    required this.fromDate,
    required this.toDate,
    required this.leaveSession,
    this.comment = '',
  });

  final String departmentId;
  final String nominatedApproverAppUserId;
  final String fromDate;
  final String toDate;
  final LeaveSession leaveSession;
  final String comment;

  JsonMap toJson() => {
    'departmentId': departmentId,
    'nominatedApproverAppUserId': nominatedApproverAppUserId,
    'fromDate': fromDate,
    'toDate': toDate,
    'leaveSession': leaveSession.apiValue,
    if (comment.trim().isNotEmpty) 'comment': comment.trim(),
  };
}

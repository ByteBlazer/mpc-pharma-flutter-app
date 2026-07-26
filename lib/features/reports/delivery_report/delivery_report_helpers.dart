import 'delivery_report_models.dart';
import '../../leave_requests/leave_helpers.dart';

const deliveryReportMaxDateRangeDays = 32;
const deliveryReportMaxOnScreenRows = 10000;
const deliveryReportLargeExportWarningThreshold = 5000;
const deliveryReportCommentLinkMinLength = 60;
const deliveryReportCommentPreviewMaxLines = 2;

/// Rolling one-calendar-month window ending today (IST calendar day).
(DateTime fromDate, DateTime toDate) defaultDeliveryReportDateRange() {
  final today = istToday();
  final from = DateTime(today.year, today.month - 1, today.day);
  return (from, today);
}

String formatDeliveryReportDateForApi(DateTime date) =>
    formatLeaveDateForApi(date);

String formatDeliveryReportDocDate(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  return _formatDayMonthYear(DateTime(local.year, local.month, local.day));
}

String formatDeliveryReportTimestamp(DateTime? dateTime) {
  if (dateTime == null) return '';
  final local = dateTime.toLocal();
  final date = _formatDayMonthYear(
    DateTime(local.year, local.month, local.day),
  );
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'pm' : 'am';
  return '$date, $hour:$minute $period';
}

String deliveryReportStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'DELIVERED':
      return 'DELIVERED';
    case 'UNDELIVERED':
      return 'DELIVERY FAILED';
    default:
      return status.toUpperCase();
  }
}

int deliveryReportStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'DELIVERED':
      return 0xFF4CAF50;
    case 'UNDELIVERED':
      return 0xFFF44336;
    default:
      return 0xFF666666;
  }
}

bool shouldShowDeliveryReportCommentLink({
  required DeliveryReportRow row,
  required bool isTruncated,
}) {
  if (!row.isUndelivered) return false;
  final comment = row.comment.trim();
  if (comment.isEmpty) return false;
  return isTruncated || comment.length > deliveryReportCommentLinkMinLength;
}

String? validateDeliveryReportDateRange({
  required DateTime? fromDate,
  required DateTime? toDate,
}) {
  if (fromDate == null && toDate == null) return null;
  if (fromDate == null || toDate == null) {
    return 'Select both document dates together, or clear both to use defaults.';
  }
  if (fromDate.isAfter(toDate)) {
    return 'From date cannot be after to date.';
  }
  final inclusiveDays = toDate.difference(fromDate).inDays + 1;
  if (inclusiveDays > deliveryReportMaxDateRangeDays) {
    return 'Document date range cannot exceed $deliveryReportMaxDateRangeDays days.';
  }
  return null;
}

Map<String, String> buildDeliveryReportQueryParameters({
  required DateTime? fromDate,
  required DateTime? toDate,
  String? customerId,
  String? docId,
  String? route,
  String? originWarehouse,
  String? tripStartLocation,
  String? driverUserId,
  Iterable<String> customerCities = const [],
  String? tripId,
}) {
  final params = <String, String>{};

  if (fromDate != null && toDate != null) {
    params['fromDate'] = formatDeliveryReportDateForApi(fromDate);
    params['toDate'] = formatDeliveryReportDateForApi(toDate);
  }

  void addIfPresent(String key, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isNotEmpty) params[key] = trimmed;
  }

  addIfPresent('customerId', customerId);
  addIfPresent('docId', docId);
  addIfPresent('route', route);
  addIfPresent('originWarehouse', originWarehouse);
  addIfPresent('tripStartLocation', tripStartLocation);
  addIfPresent('driverUserId', driverUserId);

  final cities = customerCities
      .map((city) => city.trim())
      .where((city) => city.isNotEmpty)
      .toList(growable: false);
  if (cities.isNotEmpty) {
    params['customerCity'] = cities.join(',');
  }

  final parsedTripId = int.tryParse(tripId?.trim() ?? '');
  if (parsedTripId != null && parsedTripId > 0) {
    params['tripId'] = parsedTripId.toString();
  }

  return params;
}

String _formatDayMonthYear(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

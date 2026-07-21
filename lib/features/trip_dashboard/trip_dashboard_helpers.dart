import '../my_trips/my_trips_models.dart';
import 'trip_dashboard_models.dart';

const kochiMapCenterLat = 9.9312;
const kochiMapCenterLng = 76.2673;

const _istOffset = Duration(hours: 5, minutes: 30);

DateTime _toIst(DateTime instant) => instant.toUtc().add(_istOffset);

DateTime _istNow() => _toIst(DateTime.now());

bool _isSameIstDay(DateTime a, DateTime b) {
  final ia = _toIst(a);
  final ib = _toIst(b);
  return ia.year == ib.year && ia.month == ib.month && ia.day == ib.day;
}

String formatSmartTimestamp(DateTime? instant, {String suffix = ''}) {
  if (instant == null) return '';
  final ist = _toIst(instant);
  final now = _istNow();
  final time = _formatIstTime(ist);
  String prefix;
  if (_isSameIstDay(instant, now)) {
    prefix = 'Today $time';
  } else if (_isSameIstDay(instant, now.subtract(const Duration(days: 1)))) {
    prefix = 'Yesterday $time';
  } else {
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
    prefix = '${months[ist.month - 1]} ${ist.day} $time';
  }
  if (suffix.isEmpty) return prefix;
  return '$prefix$suffix';
}

String _formatIstTime(DateTime ist) {
  final period = ist.hour >= 12 ? 'PM' : 'AM';
  var hour12 = ist.hour % 12;
  if (hour12 == 0) hour12 = 12;
  final minute = ist.minute.toString().padLeft(2, '0');
  return '$hour12:$minute $period';
}

String formatDeliveryStatusTimestamp({
  required String statusLabel,
  required DateTime? deliveredAt,
}) {
  if (deliveredAt == null) return statusLabel;
  final ist = _toIst(deliveredAt);
  final now = _istNow();
  final time = _formatIstTime(ist);
  if (_isSameIstDay(deliveredAt, now)) {
    return '$statusLabel at $time today';
  }
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
  return '$statusLabel at $time on ${ist.day} ${months[ist.month - 1]}';
}

String docStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'UNDELIVERED':
      return 'Delivery failed';
    case 'DELIVERED':
      return 'Delivered';
    case 'ON_TRIP':
      return 'On trip';
    case 'AT_TRANSIT_HUB':
      return 'At transit hub';
    case 'TRIP_SCHEDULED':
      return 'Trip scheduled';
    case 'READY_FOR_DISPATCH':
      return 'Ready for dispatch';
    case 'PENDING':
      return 'Pending';
    default:
      return 'Unknown';
  }
}

int docStatusColor(String status) {
  switch (status.toUpperCase()) {
    case 'DELIVERED':
      return 0xFF4CAF50;
    case 'UNDELIVERED':
      return 0xFFF44336;
    case 'ON_TRIP':
      return 0xFF2196F3;
    case 'AT_TRANSIT_HUB':
      return 0xFFFF9800;
    default:
      return 0xFF666666;
  }
}

String formatInrAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final value = double.tryParse(trimmed);
  if (value == null) return '₹$trimmed';
  final negative = value < 0;
  final abs = value.abs();
  final whole = abs.truncate();
  final fraction = ((abs - whole) * 100).round();
  final grouped = _groupIndianDigits(whole.toString());
  if (fraction == 0) {
    return '${negative ? '-' : ''}₹$grouped';
  }
  final frac = fraction.toString().padLeft(2, '0');
  return '${negative ? '-' : ''}₹$grouped.$frac';
}

String _groupIndianDigits(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$lastThree';
}

List<DashboardTripSummary> filterTripsByTab(
  List<DashboardTripSummary> trips,
  int tabIndex,
) {
  switch (tabIndex) {
    case 0:
      return trips.where((t) => t.isStarted).toList();
    case 1:
      return trips.where((t) => t.isScheduled).toList();
    case 2:
      return trips.where((t) => t.isEnded).toList();
    default:
      return trips;
  }
}

int tabIndexForTripStatus(String status) {
  switch (status.toUpperCase()) {
    case 'STARTED':
      return 0;
    case 'SCHEDULED':
      return 1;
    case 'ENDED':
      return 2;
    default:
      return 0;
  }
}

List<CustomerMapCluster> clusterCustomerMarkers(SingleTripDetails detail) {
  final directDocs = <TripDoc>[];
  for (final group in detail.docGroups) {
    for (final doc in group.docs) {
      if (doc.isDirectDelivery && doc.hasCustomerGeo) {
        directDocs.add(doc);
      }
    }
  }

  final order = <String>[];
  final map = <String, List<TripDoc>>{};
  for (final doc in directDocs) {
    final customerId = doc.customerId.trim();
    final key = customerId.isNotEmpty
        ? customerId
        : '${doc.customerFirmName.trim()}-${doc.customerGeoLatitude}-${doc.customerGeoLongitude}';
    map.putIfAbsent(key, () {
      order.add(key);
      return [];
    });
    map[key]!.add(doc);
  }

  return [
    for (final key in order)
      CustomerMapCluster(key: key, docs: map[key]!),
  ];
}

class TripProgressSummary {
  const TripProgressSummary({
    required this.totalCustomers,
    required this.completed,
    required this.failed,
    required this.pending,
    required this.lotDropoffsPending,
    required this.durationLabel,
    required this.durationCaption,
  });

  final int totalCustomers;
  final int completed;
  final int failed;
  final int pending;
  final int lotDropoffsPending;
  final String durationLabel;
  final String durationCaption;
}

TripProgressSummary computeTripProgress({
  required SingleTripDetails detail,
  required DateTime now,
}) {
  final clusters = clusterCustomerMarkers(detail);
  var completed = 0;
  var failed = 0;
  var pending = 0;

  for (final cluster in clusters) {
    final docs = cluster.docs;
    final allDelivered = docs.every((d) => d.isDelivered);
    final anyFailed = docs.any((d) => d.isUndelivered);
    if (allDelivered && docs.isNotEmpty) {
      completed++;
    } else if (anyFailed) {
      failed++;
    } else {
      pending++;
    }
  }

  var lotPending = 0;
  for (final group in detail.docGroups) {
    if (group.showDropOffButton) lotPending++;
  }

  final status = detail.status.toUpperCase();
  String durationLabel = '';
  String durationCaption = '';
  final startedAt = detail.startedAt;
  if (startedAt != null &&
      (status == 'STARTED' || status == 'ENDED')) {
    final end = status == 'ENDED'
        ? (detail.lastUpdatedAt ?? now)
        : now;
    durationLabel = _formatDuration(startedAt, end);
    durationCaption = status == 'STARTED'
        ? 'Time since trip started'
        : 'Total trip duration';
  }

  return TripProgressSummary(
    totalCustomers: clusters.length,
    completed: completed,
    failed: failed,
    pending: pending,
    lotDropoffsPending: lotPending,
    durationLabel: durationLabel,
    durationCaption: durationCaption,
  );
}

String _formatDuration(DateTime start, DateTime end) {
  final diff = end.difference(start);
  if (diff.isNegative) return '0h 0m';
  final hours = diff.inHours;
  final minutes = diff.inMinutes.remainder(60);
  return '${hours}h ${minutes}m';
}

String mapHeading({
  required int tabIndex,
  required int? selectedTripId,
  required String route,
  required bool detailLoading,
}) {
  if (selectedTripId != null) {
    if (detailLoading) return 'Trip #$selectedTripId';
    final routePart = route.trim();
    if (routePart.isEmpty) return 'Trip #$selectedTripId';
    return 'Trip #$selectedTripId — $routePart';
  }
  switch (tabIndex) {
    case 0:
      return 'All ongoing trips — driver locations';
    default:
      return 'Select a trip to view details';
  }
}

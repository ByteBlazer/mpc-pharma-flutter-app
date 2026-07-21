import '../../utils/api_message.dart';
import '../my_trips/my_trips_models.dart'
    show JsonMap, TripDoc, asInt, parseDate;

class AllTripsResponse {
  const AllTripsResponse({
    required this.success,
    required this.message,
    required this.trips,
    required this.totalTrips,
  });

  factory AllTripsResponse.fromJson(JsonMap json) {
    final list = (json['trips'] as List?) ?? const [];
    return AllTripsResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      trips: list
          .whereType<JsonMap>()
          .map(DashboardTripSummary.fromJson)
          .toList(),
      totalTrips: asInt(json['totalTrips']) ?? 0,
    );
  }

  final bool success;
  final String message;
  final List<DashboardTripSummary> trips;
  final int totalTrips;
}

class DashboardTripSummary {
  const DashboardTripSummary({
    required this.tripId,
    required this.createdBy,
    required this.driverName,
    required this.driverId,
    required this.driverPhoneNumber,
    required this.vehicleNumber,
    required this.status,
    required this.route,
    required this.createdAt,
    required this.lastUpdatedAt,
    required this.startedAt,
    required this.driverLastKnownLatitude,
    required this.driverLastKnownLongitude,
    required this.driverLastLocationUpdateTime,
    required this.pendingDirectDeliveries,
    required this.totalDirectDeliveries,
    required this.pendingLotDropOffs,
  });

  factory DashboardTripSummary.fromJson(JsonMap json) {
    return DashboardTripSummary(
      tripId: asInt(json['tripId']) ?? 0,
      createdBy: json['createdBy']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      driverPhoneNumber: json['driverPhoneNumber']?.toString() ?? '',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']),
      lastUpdatedAt: parseDate(json['lastUpdatedAt']),
      startedAt: parseDate(json['startedAt']),
      driverLastKnownLatitude:
          json['driverLastKnownLatitude']?.toString() ?? '',
      driverLastKnownLongitude:
          json['driverLastKnownLongitude']?.toString() ?? '',
      driverLastLocationUpdateTime:
          parseDate(json['driverLastLocationUpdateTime']),
      pendingDirectDeliveries: asInt(json['pendingDirectDeliveries']) ?? 0,
      totalDirectDeliveries: asInt(json['totalDirectDeliveries']) ?? 0,
      pendingLotDropOffs: asInt(json['pendingLotDropOffs']) ?? 0,
    );
  }

  final int tripId;
  final String createdBy;
  final String driverName;
  final String driverId;
  final String driverPhoneNumber;
  final String vehicleNumber;
  final String status;
  final String route;
  final DateTime? createdAt;
  final DateTime? lastUpdatedAt;
  final DateTime? startedAt;
  final String driverLastKnownLatitude;
  final String driverLastKnownLongitude;
  final DateTime? driverLastLocationUpdateTime;
  final int pendingDirectDeliveries;
  final int totalDirectDeliveries;
  final int pendingLotDropOffs;

  bool get isScheduled => status.toUpperCase() == 'SCHEDULED';
  bool get isStarted => status.toUpperCase() == 'STARTED';
  bool get isEnded => status.toUpperCase() == 'ENDED';

  double? get driverLat => double.tryParse(driverLastKnownLatitude.trim());
  double? get driverLng => double.tryParse(driverLastKnownLongitude.trim());

  bool get hasDriverGps => driverLat != null && driverLng != null;

  String get listTitle {
    final routePart = route.trim();
    if (routePart.isEmpty) return 'Trip #$tripId';
    return 'Trip #$tripId $routePart';
  }

  String get driverMarkerTitle {
    final parts = <String>[
      if (driverName.trim().isNotEmpty) driverName.trim(),
      if (vehicleNumber.trim().isNotEmpty) vehicleNumber.trim(),
      if (route.trim().isNotEmpty) route.trim(),
    ];
    return parts.join(' - ');
  }
}

class DocSearchResult {
  const DocSearchResult({
    required this.docId,
    required this.docStatus,
    this.tripId,
    this.tripStatus,
  });

  factory DocSearchResult.fromJson(JsonMap json) {
    return DocSearchResult(
      docId: json['docId']?.toString() ?? '',
      docStatus: json['docStatus']?.toString() ?? '',
      tripId: asInt(json['tripId']),
      tripStatus: json['tripStatus']?.toString(),
    );
  }

  final String docId;
  final String docStatus;
  final int? tripId;
  final String? tripStatus;

  bool get isReadyForDispatch =>
      docStatus.toUpperCase() == 'READY_FOR_DISPATCH';
  bool get isAtTransitHub => docStatus.toUpperCase() == 'AT_TRANSIT_HUB';
  bool get isOnTrip => tripId != null && tripStatus != null;
}

class DeliveryStatusDetails {
  const DeliveryStatusDetails({
    required this.success,
    required this.message,
    required this.docId,
    required this.status,
    this.comment = '',
    this.signature = '',
    this.deliveredAt,
  });

  factory DeliveryStatusDetails.fromJson(JsonMap json) {
    return DeliveryStatusDetails(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      docId: json['docId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      signature: json['signature']?.toString() ?? '',
      deliveredAt: parseDate(json['deliveredAt']),
    );
  }

  final bool success;
  final String message;
  final String docId;
  final String status;
  final String comment;
  final String signature;
  final DateTime? deliveredAt;
}

class ForceEndTripResult {
  const ForceEndTripResult({
    required this.statusCode,
    required this.success,
    required this.message,
    this.markedUndeliveredCount = 0,
  });

  factory ForceEndTripResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    final ok = statusCode >= 200 && statusCode < 300;
    return ForceEndTripResult(
      statusCode: statusCode,
      success: ok && json['success'] != false,
      message: formatApiMessage(json['message'] ?? json['error'], fallback: ''),
      markedUndeliveredCount: asInt(json['markedUndeliveredCount']) ?? 0,
    );
  }

  factory ForceEndTripResult.unreachable() {
    return const ForceEndTripResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;
  final int markedUndeliveredCount;

  String get displayMessage =>
      message.isEmpty ? 'Something went wrong. Please try again.' : message;
}

/// Customer stop on map — grouped direct-delivery docs at one location.
class CustomerMapCluster {
  const CustomerMapCluster({
    required this.key,
    required this.docs,
  });

  final String key;
  final List<TripDoc> docs;

  TripDoc get representative => docs.first;

  double? get latitude => representative.customerLat;
  double? get longitude => representative.customerLng;

  bool get hasGeo => representative.hasCustomerGeo;
}

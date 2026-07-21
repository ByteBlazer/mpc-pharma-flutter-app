import 'dart:convert';

import '../../utils/api_message.dart';
import '../../utils/build_timestamp.dart';

typedef JsonMap = Map<String, dynamic>;

class MyTripsListResponse {
  const MyTripsListResponse({
    required this.success,
    required this.message,
    required this.trips,
    required this.totalTrips,
  });

  factory MyTripsListResponse.fromJson(JsonMap json) {
    final list = (json['trips'] as List?) ?? const [];
    return MyTripsListResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      trips: list.whereType<JsonMap>().map(DriverTripSummary.fromJson).toList(),
      totalTrips: asInt(json['totalTrips']) ?? 0,
    );
  }

  final bool success;
  final String message;
  final List<DriverTripSummary> trips;
  final int totalTrips;

  DriverTripSummary? get startedTrip {
    for (final trip in trips) {
      if (trip.isStarted) return trip;
    }
    return null;
  }
}

class DriverTripSummary {
  const DriverTripSummary({
    required this.tripId,
    required this.createdBy,
    required this.driverName,
    required this.driverId,
    required this.vehicleNumber,
    required this.status,
    required this.route,
    required this.createdAt,
    required this.deliveryCountStatusMsg,
    required this.dropOffCountStatusMsg,
  });

  factory DriverTripSummary.fromJson(JsonMap json) {
    return DriverTripSummary(
      tripId: asInt(json['tripId']) ?? 0,
      createdBy: json['createdBy']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      driverId: json['driverId']?.toString() ?? '',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      createdAt: parseDate(json['createdAt']),
      deliveryCountStatusMsg:
          json['deliveryCountStatusMsg']?.toString() ?? '',
      dropOffCountStatusMsg: json['dropOffCountStatusMsg']?.toString() ?? '',
    );
  }

  final int tripId;
  final String createdBy;
  final String driverName;
  final String driverId;
  final String vehicleNumber;
  final String status;
  final String route;
  final DateTime? createdAt;
  final String deliveryCountStatusMsg;
  final String dropOffCountStatusMsg;

  bool get isScheduled => status.toUpperCase() == 'SCHEDULED';
  bool get isStarted => status.toUpperCase() == 'STARTED';

  String get createdAtFormatted {
    final at = createdAt;
    if (at == null) return '';
    return formatBuildTimestampIst(at);
  }
}

class TripActionResult {
  const TripActionResult({
    required this.statusCode,
    required this.success,
    required this.message,
  });

  factory TripActionResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    final ok = statusCode >= 200 && statusCode < 300;
    return TripActionResult(
      statusCode: statusCode,
      success: ok && json['success'] != false,
      message: formatApiMessage(json['message'] ?? json['error'], fallback: ''),
    );
  }

  factory TripActionResult.unreachable() {
    return const TripActionResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;

  String get displayMessage =>
      message.isEmpty ? 'Something went wrong. Please try again.' : message;
}

class SingleTripDetails {
  const SingleTripDetails({
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
    required this.deliveryCountStatusMsg,
    required this.dropOffCountStatusMsg,
    required this.docGroups,
    required this.driverLastKnownLatitude,
    required this.driverLastKnownLongitude,
  });

  factory SingleTripDetails.fromJson(JsonMap json) {
    final groups = (json['docGroups'] as List?) ?? const [];
    return SingleTripDetails(
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
      deliveryCountStatusMsg:
          json['deliveryCountStatusMsg']?.toString() ?? '',
      dropOffCountStatusMsg: json['dropOffCountStatusMsg']?.toString() ?? '',
      docGroups: groups.whereType<JsonMap>().map(TripDocGroup.fromJson).toList(),
      driverLastKnownLatitude:
          json['driverLastKnownLatitude']?.toString() ?? '',
      driverLastKnownLongitude:
          json['driverLastKnownLongitude']?.toString() ?? '',
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
  final String deliveryCountStatusMsg;
  final String dropOffCountStatusMsg;
  final List<TripDocGroup> docGroups;
  final String driverLastKnownLatitude;
  final String driverLastKnownLongitude;

  double? get driverLat => double.tryParse(driverLastKnownLatitude.trim());
  double? get driverLng => double.tryParse(driverLastKnownLongitude.trim());

  bool get hasDriverGps => driverLat != null && driverLng != null;

  String get createdAtFormatted {
    final at = createdAt;
    if (at == null) return '';
    return formatBuildTimestampIst(at);
  }
}

class TripDocGroup {
  const TripDocGroup({
    required this.heading,
    required this.droppable,
    required this.dropOffCompleted,
    required this.showDropOffButton,
    required this.expandGroupByDefault,
    required this.docs,
  });

  factory TripDocGroup.fromJson(JsonMap json) {
    final docs = (json['docs'] as List?) ?? const [];
    return TripDocGroup(
      heading: json['heading']?.toString() ?? '',
      droppable: json['droppable'] == true,
      dropOffCompleted: json['dropOffCompleted'] == true,
      showDropOffButton: json['showDropOffButton'] == true,
      expandGroupByDefault: json['expandGroupByDefault'] == true,
      docs: docs.whereType<JsonMap>().map(TripDoc.fromJson).toList(),
    );
  }

  final String heading;
  final bool droppable;
  final bool dropOffCompleted;
  final bool showDropOffButton;
  final bool expandGroupByDefault;
  final List<TripDoc> docs;

  bool get hasOnTripDocs => docs.any((d) => d.isOnTrip);
}

class TripDoc {
  const TripDoc({
    required this.id,
    required this.status,
    required this.lot,
    required this.comment,
    required this.docAmount,
    required this.customerId,
    required this.customerFirmName,
    required this.customerAddress,
    required this.customerCity,
    required this.customerPincode,
    required this.customerPhone,
    required this.customerGeoLatitude,
    required this.customerGeoLongitude,
  });

  factory TripDoc.fromJson(JsonMap json) {
    return TripDoc(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      lot: json['lot']?.toString(),
      comment: json['comment']?.toString() ?? '',
      docAmount: json['docAmount']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      customerFirmName: json['customerFirmName']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerCity: json['customerCity']?.toString() ?? '',
      customerPincode: json['customerPincode']?.toString() ?? '',
      customerPhone: json['customerPhone']?.toString() ?? '',
      customerGeoLatitude: json['customerGeoLatitude']?.toString() ?? '',
      customerGeoLongitude: json['customerGeoLongitude']?.toString() ?? '',
    );
  }

  final String id;
  final String status;
  final String? lot;
  final String comment;
  final String docAmount;
  final String customerId;
  final String customerFirmName;
  final String customerAddress;
  final String customerCity;
  final String customerPincode;
  final String customerPhone;
  final String customerGeoLatitude;
  final String customerGeoLongitude;

  bool get isOnTrip => status.toUpperCase() == 'ON_TRIP';
  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';

  bool get isDirectDelivery {
    final value = lot?.trim() ?? '';
    return value.isEmpty;
  }

  String get statusLabel {
    if (isDelivered) return 'Delivered';
    if (isUndelivered) return 'Not Delivered';
    return 'On Trip';
  }

  String get addressLine {
    final parts = <String>[
      if (customerAddress.trim().isNotEmpty) customerAddress.trim(),
      if (customerCity.trim().isNotEmpty) customerCity.trim(),
      if (customerPincode.trim().isNotEmpty) customerPincode.trim(),
    ];
    return parts.join(', ');
  }

  double? get customerLat => double.tryParse(customerGeoLatitude.trim());
  double? get customerLng => double.tryParse(customerGeoLongitude.trim());

  bool get hasCustomerGeo => customerLat != null && customerLng != null;
}

class RecentSignatureResult {
  const RecentSignatureResult({
    required this.found,
    required this.signatureBase64,
    required this.message,
  });

  factory RecentSignatureResult.found(String signature) {
    return RecentSignatureResult(
      found: true,
      signatureBase64: signature,
      message: '',
    );
  }

  factory RecentSignatureResult.none([String message = '']) {
    return RecentSignatureResult(
      found: false,
      signatureBase64: '',
      message: message,
    );
  }

  final bool found;
  final String signatureBase64;
  final String message;
}

class MarkDeliveriesBatchResult {
  const MarkDeliveriesBatchResult({
    required this.statusCode,
    required this.success,
    required this.message,
    this.docIds = const [],
    this.customerId = '',
  });

  factory MarkDeliveriesBatchResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    final ids = (json['docIds'] as List?) ?? const [];
    return MarkDeliveriesBatchResult(
      statusCode: statusCode,
      success: statusCode >= 200 &&
          statusCode < 300 &&
          json['success'] != false,
      message: formatApiMessage(json['message'] ?? json['error'], fallback: ''),
      docIds: ids.map((e) => e.toString()).toList(),
      customerId: json['customerId']?.toString() ?? '',
    );
  }

  factory MarkDeliveriesBatchResult.unreachable() {
    return const MarkDeliveriesBatchResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;
  final List<String> docIds;
  final String customerId;

  String get displayMessage =>
      message.isEmpty ? 'Something went wrong. Please try again.' : message;
}

/// Groups direct-delivery docs by [TripDoc.customerId] (first-seen order).
List<CustomerDeliveryCluster> clusterDirectDeliveries(List<TripDoc> docs) {
  final order = <String>[];
  final map = <String, List<TripDoc>>{};
  for (final doc in docs) {
    final key = doc.customerId.trim().isEmpty
        ? '__unknown_${doc.id}'
        : doc.customerId.trim();
    if (!map.containsKey(key)) {
      order.add(key);
      map[key] = [];
    }
    map[key]!.add(doc);
  }
  return [
    for (final key in order)
      CustomerDeliveryCluster(customerId: key, docs: map[key]!),
  ];
}

class CustomerDeliveryCluster {
  const CustomerDeliveryCluster({
    required this.customerId,
    required this.docs,
  });

  final String customerId;
  final List<TripDoc> docs;

  List<TripDoc> get onTripDocs => docs.where((d) => d.isOnTrip).toList();

  TripDoc get representative => docs.first;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String encodeSignatureBytes(List<int> bytes) => base64Encode(bytes);

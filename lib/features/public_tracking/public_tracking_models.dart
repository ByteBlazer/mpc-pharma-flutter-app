import '../../utils/api_message.dart';
import '../my_trips/my_trips_models.dart' show JsonMap, asInt, parseDate;

class TrackingLocation {
  const TrackingLocation({
    required this.latitude,
    required this.longitude,
    this.receivedAt,
  });

  factory TrackingLocation.fromJson(JsonMap json) {
    return TrackingLocation(
      latitude: json['latitude']?.toString() ?? '',
      longitude: json['longitude']?.toString() ?? '',
      receivedAt: parseDate(json['receivedAt']),
    );
  }

  final String latitude;
  final String longitude;
  final DateTime? receivedAt;

  double? get lat => double.tryParse(latitude.trim());
  double? get lng => double.tryParse(longitude.trim());

  bool get hasCoordinates => lat != null && lng != null;
}

class DocTrackingResponse {
  const DocTrackingResponse({
    required this.success,
    required this.message,
    required this.docId,
    required this.docAmountRaw,
    required this.status,
    this.comment = '',
    this.deliveryTimestamp,
    this.customerFirmName = '',
    this.customerAddress = '',
    this.customerCity = '',
    this.customerPincode = '',
    this.customerLocation,
    this.driverLastKnownLocation,
    this.eta = -1,
    this.numEnrouteCustomers = -1,
    this.enrouteCustomersServiceTime,
  });

  factory DocTrackingResponse.fromJson(JsonMap json) {
    return DocTrackingResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      docId: json['docId']?.toString() ?? '',
      docAmountRaw: _readAmount(json['docAmount']),
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      deliveryTimestamp: parseDate(json['deliveryTimestamp']),
      customerFirmName: json['customerFirmName']?.toString() ?? '',
      customerAddress: json['customerAddress']?.toString() ?? '',
      customerCity: json['customerCity']?.toString() ?? '',
      customerPincode: json['customerPincode']?.toString() ?? '',
      customerLocation: json['customerLocation'] is JsonMap
          ? TrackingLocation.fromJson(json['customerLocation'] as JsonMap)
          : null,
      driverLastKnownLocation: json['driverLastKnownLocation'] is JsonMap
          ? TrackingLocation.fromJson(
              json['driverLastKnownLocation'] as JsonMap,
            )
          : null,
      eta: asInt(json['eta']) ?? -1,
      numEnrouteCustomers: asInt(json['numEnrouteCustomers']) ?? -1,
      enrouteCustomersServiceTime: asInt(json['enrouteCustomersServiceTime']),
    );
  }

  final bool success;
  final String message;
  final String docId;
  final String docAmountRaw;
  final String status;
  final String comment;
  final DateTime? deliveryTimestamp;
  final String customerFirmName;
  final String customerAddress;
  final String customerCity;
  final String customerPincode;
  final TrackingLocation? customerLocation;
  final TrackingLocation? driverLastKnownLocation;
  final int eta;
  final int numEnrouteCustomers;
  final int? enrouteCustomersServiceTime;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';
  bool get isTerminal => isDelivered || isUndelivered;

  bool get hasMap =>
      (customerLocation?.hasCoordinates ?? false) ||
      (driverLastKnownLocation?.hasCoordinates ?? false);

  String get deliveringTo {
    return [
      customerFirmName,
      customerAddress,
      customerCity,
      customerPincode,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  static String _readAmount(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString().trim();
  }
}

class DocTrackingException implements Exception {
  const DocTrackingException(this.message);

  final String message;

  @override
  String toString() => message;
}

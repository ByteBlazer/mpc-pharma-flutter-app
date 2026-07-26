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

/// Another invoice on the same trip as the tracked document.
///
/// Returned by API#1 as optional `otherTripDocuments` — omitted on older backends.
class TripTrackingDocument {
  const TripTrackingDocument({
    required this.docId,
    required this.docAmountRaw,
    required this.status,
    this.comment = '',
  });

  factory TripTrackingDocument.fromJson(JsonMap json) {
    return TripTrackingDocument(
      docId: json['docId']?.toString() ?? '',
      docAmountRaw: DocTrackingResponse.readAmount(json['docAmount']),
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
    );
  }

  final String docId;
  final String docAmountRaw;
  final String status;
  final String comment;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';
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
    this.otherTripDocuments = const [],
  });

  factory DocTrackingResponse.fromJson(JsonMap json) {
    return DocTrackingResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      docId: json['docId']?.toString() ?? '',
      docAmountRaw: DocTrackingResponse.readAmount(json['docAmount']),
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
      otherTripDocuments: _readOtherTripDocuments(json['otherTripDocuments']),
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
  final List<TripTrackingDocument> otherTripDocuments;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';
  bool get isTerminal => isDelivered || isUndelivered;

  /// True when API#1 includes sibling invoices on the same trip.
  bool get hasOtherTripDocuments => otherTripDocuments.isNotEmpty;

  /// Primary tracked invoice plus any siblings from [otherTripDocuments].
  List<TripTrackingDocument> get allTripDocuments {
    final primaryId = docId.trim();
    final siblings = otherTripDocuments
        .where((doc) => doc.docId.trim().isNotEmpty && doc.docId != primaryId)
        .toList(growable: false);
    if (primaryId.isEmpty) return siblings;
    return [
      TripTrackingDocument(
        docId: docId,
        docAmountRaw: docAmountRaw,
        status: status,
        comment: comment,
      ),
      ...siblings,
    ];
  }

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

  String get customerAddressLine {
    return [
      customerAddress,
      customerCity,
      customerPincode,
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  static String readAmount(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString().trim();
  }

  static List<TripTrackingDocument> _readOtherTripDocuments(Object? value) {
    if (value is! List) return const [];
    final documents = <TripTrackingDocument>[];
    for (final item in value) {
      if (item is! JsonMap) continue;
      final doc = TripTrackingDocument.fromJson(item);
      if (doc.docId.trim().isEmpty) continue;
      documents.add(doc);
    }
    return List<TripTrackingDocument>.unmodifiable(documents);
  }
}

class DocTrackingException implements Exception {
  const DocTrackingException(this.message);

  final String message;

  @override
  String toString() => message;
}

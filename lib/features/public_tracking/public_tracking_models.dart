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
    this.deliveredAt,
    this.signature = '',
  });

  factory TripTrackingDocument.fromJson(JsonMap json) {
    return TripTrackingDocument(
      docId: json['docId']?.toString() ?? '',
      docAmountRaw: DocTrackingResponse.readAmount(json['docAmount']),
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      deliveredAt: parseDate(json['deliveredAt']),
      signature: json['signature']?.toString() ?? '',
    );
  }

  final String docId;
  final String docAmountRaw;
  final String status;
  final String comment;
  final DateTime? deliveredAt;
  final String signature;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';
  bool get isTerminal => isDelivered || isUndelivered;
  bool get hasSignature => signature.trim().isNotEmpty;

  bool get isPending => !isTerminal;
}

/// Counts of invoice statuses for this customer's docs on the trip.
class PublicTrackingTripDocumentCounts {
  const PublicTrackingTripDocumentCounts({
    required this.delivered,
    required this.failed,
    required this.pending,
    required this.total,
  });

  factory PublicTrackingTripDocumentCounts.fromDocuments(
    List<TripTrackingDocument> documents,
  ) {
    var delivered = 0;
    var failed = 0;
    var pending = 0;
    for (final doc in documents) {
      if (doc.isDelivered) {
        delivered++;
      } else if (doc.isUndelivered) {
        failed++;
      } else {
        pending++;
      }
    }
    return PublicTrackingTripDocumentCounts(
      delivered: delivered,
      failed: failed,
      pending: pending,
      total: documents.length,
    );
  }

  final int delivered;
  final int failed;
  final int pending;
  final int total;

  bool get allDelivered => total > 0 && delivered == total;
  bool get allFailed => total > 0 && failed == total;
  bool get hasPending => pending > 0;
}

class DocTrackingResponse {
  const DocTrackingResponse({
    required this.success,
    required this.message,
    required this.docId,
    required this.docAmountRaw,
    required this.status,
    this.comment = '',
    this.deliveredAt,
    this.deliveryTimestamp,
    this.signature = '',
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
    final deliveryTimestamp = parseDate(json['deliveryTimestamp']);
    final deliveredAt =
        parseDate(json['deliveredAt']) ?? deliveryTimestamp;
    return DocTrackingResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      docId: json['docId']?.toString() ?? '',
      docAmountRaw: DocTrackingResponse.readAmount(json['docAmount']),
      status: json['status']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      deliveredAt: deliveredAt,
      deliveryTimestamp: deliveryTimestamp,
      signature: json['signature']?.toString() ?? '',
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
  final DateTime? deliveredAt;
  final DateTime? deliveryTimestamp;
  final String signature;
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
    final primaryDeliveredAt = deliveredAt ?? deliveryTimestamp;
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
        deliveredAt: primaryDeliveredAt,
        signature: signature,
      ),
      ...siblings,
    ];
  }

  /// True when every invoice on the page is DELIVERED or UNDELIVERED.
  bool get allDocumentsTerminal {
    final docs = allTripDocuments;
    if (docs.isEmpty) return isTerminal;
    return docs.every((doc) => doc.isTerminal);
  }

  PublicTrackingTripDocumentCounts get tripDocumentCounts =>
      PublicTrackingTripDocumentCounts.fromDocuments(allTripDocuments);

  /// True when at least one invoice on this trip is still in progress.
  bool get hasPendingTripDocuments {
    final counts = tripDocumentCounts;
    if (counts.total == 0) return !isTerminal;
    return counts.hasPending;
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

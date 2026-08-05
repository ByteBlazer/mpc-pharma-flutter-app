import 'dart:convert';

import '../my_trips/my_trips_models.dart' show JsonMap, asInt, parseDate;

class CustomerDeliverySummary {
  const CustomerDeliverySummary({
    required this.docId,
    required this.status,
    this.tripId,
    this.docAmountRaw = '',
    this.docDate,
    this.lastUpdatedAt,
  });

  factory CustomerDeliverySummary.fromJson(JsonMap json) {
    return CustomerDeliverySummary(
      docId: json['docId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      tripId: asInt(json['tripId']),
      docAmountRaw: _readAmount(json['docAmount']),
      docDate: parseDate(json['docDate']),
      lastUpdatedAt: parseDate(json['lastUpdatedAt']),
    );
  }

  final String docId;
  final String status;
  final int? tripId;
  final String docAmountRaw;
  final DateTime? docDate;
  final DateTime? lastUpdatedAt;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';
  bool get isAtTransitHub => status.toUpperCase() == 'AT_TRANSIT_HUB';

  static String _readAmount(Object? value) {
    if (value == null) return '';
    if (value is num) return value.toString();
    return value.toString().trim();
  }

  static List<CustomerDeliverySummary> parseResponseBody(String body) {
    if (body.trim().isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! JsonMap) return const [];
    final list = decoded['deliveries'];
    if (list is! List) return const [];
    return list
        .whereType<JsonMap>()
        .map(CustomerDeliverySummary.fromJson)
        .where((item) => item.docId.trim().isNotEmpty)
        .toList(growable: false);
  }
}

/// How a delivery-tracking card group should be rendered.
enum CustomerDeliveryGroupKind {
  trip,
  transitHub,
  standalone,
}

/// Deliveries shown together on one delivery-tracking card.
class CustomerDeliveryTripGroup {
  const CustomerDeliveryTripGroup({
    required this.kind,
    required this.tripId,
    required this.deliveries,
  });

  final CustomerDeliveryGroupKind kind;
  final int? tripId;
  final List<CustomerDeliverySummary> deliveries;

  bool get hasTripId => tripId != null;

  bool get showTrackButton => kind == CustomerDeliveryGroupKind.trip;

  int get invoiceCount => deliveries.length;

  /// Doc id for the trip-level Track link (first invoice after status sort).
  String get trackingDocId => deliveries.first.docId;
}

int tripInvoiceStatusSortOrder(String status) {
  switch (status.toUpperCase()) {
    case 'ON_TRIP':
      return 0;
    case 'DELIVERED':
      return 2;
    case 'UNDELIVERED':
      return 3;
    default:
      return 1;
  }
}

List<CustomerDeliverySummary> sortTripDeliveries(
  List<CustomerDeliverySummary> deliveries,
) {
  if (deliveries.length <= 1) return deliveries;
  final sorted = List<CustomerDeliverySummary>.from(deliveries);
  sorted.sort((a, b) {
    final order = tripInvoiceStatusSortOrder(
      a.status,
    ).compareTo(tripInvoiceStatusSortOrder(b.status));
    if (order != 0) return order;
    return 0;
  });
  return sorted;
}

List<CustomerDeliveryTripGroup> groupCustomerDeliveriesByTrip(
  List<CustomerDeliverySummary> deliveries,
) {
  if (deliveries.isEmpty) return const [];

  const transitHubKey = 'transit-hub';
  final orderedKeys = <String>[];
  final grouped = <String, List<CustomerDeliverySummary>>{};

  for (final delivery in deliveries) {
    final key = delivery.tripId != null
        ? 'trip:${delivery.tripId}'
        : delivery.isAtTransitHub
        ? transitHubKey
        : 'doc:${delivery.docId}';
    grouped.putIfAbsent(key, () {
      orderedKeys.add(key);
      return <CustomerDeliverySummary>[];
    }).add(delivery);
  }

  return orderedKeys
      .map((key) {
        final items = sortTripDeliveries(grouped[key]!);
        final kind = switch (key) {
          transitHubKey => CustomerDeliveryGroupKind.transitHub,
          _ when key.startsWith('trip:') => CustomerDeliveryGroupKind.trip,
          _ => CustomerDeliveryGroupKind.standalone,
        };
        return CustomerDeliveryTripGroup(
          kind: kind,
          tripId: kind == CustomerDeliveryGroupKind.trip
              ? items.first.tripId
              : null,
          deliveries: List<CustomerDeliverySummary>.unmodifiable(items),
        );
      })
      .toList(growable: false);
}

class DocLineItem {
  const DocLineItem({
    required this.medicineName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    required this.lineItemPrice,
  });

  factory DocLineItem.fromJson(JsonMap json) {
    return DocLineItem(
      medicineName: json['medicineName']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      qty: asInt(json['qty']) ?? 0,
      unitPrice: _readPrice(json['unitPrice']),
      lineItemPrice: _readPrice(json['lineItemPrice']),
    );
  }

  final String medicineName;
  final String unit;
  final int qty;
  final double unitPrice;
  final double lineItemPrice;

  static double _readPrice(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class DocLineItemsResponse {
  const DocLineItemsResponse({
    required this.docId,
    required this.lineItems,
    required this.invoiceTotal,
  });

  factory DocLineItemsResponse.fromJson(JsonMap json) {
    final items = <DocLineItem>[];
    final rawItems = json['lineItems'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is JsonMap) {
          items.add(DocLineItem.fromJson(item));
        }
      }
    }
    return DocLineItemsResponse(
      docId: json['docId']?.toString() ?? '',
      lineItems: List<DocLineItem>.unmodifiable(items),
      invoiceTotal: DocLineItem._readPrice(json['invoiceTotal']),
    );
  }

  final String docId;
  final List<DocLineItem> lineItems;
  final double invoiceTotal;
}

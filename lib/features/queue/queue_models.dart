import '../../utils/api_message.dart';

typedef JsonMap = Map<String, dynamic>;

class DispatchQueueResponse {
  const DispatchQueueResponse({
    required this.success,
    required this.message,
    required this.totalDocs,
    required this.routes,
  });

  factory DispatchQueueResponse.fromJson(JsonMap json) {
    final list = json['dispatchQueueList'];
    final routeMaps = list is JsonMap
        ? (list['routeSummaryList'] as List?) ?? const []
        : const [];
    return DispatchQueueResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      totalDocs: _asInt(json['totalDocs']) ?? 0,
      routes: routeMaps
          .whereType<JsonMap>()
          .map(RouteSummary.fromJson)
          .toList(),
    );
  }

  final bool success;
  final String message;
  final int totalDocs;
  final List<RouteSummary> routes;
}

class RouteSummary {
  const RouteSummary({
    required this.route,
    required this.batches,
  });

  factory RouteSummary.fromJson(JsonMap json) {
    final users = (json['userSummaryList'] as List?) ?? const [];
    return RouteSummary(
      route: json['route']?.toString() ?? '',
      batches: users.whereType<JsonMap>().map(QueueBatch.fromJson).toList(),
    );
  }

  final String route;
  final List<QueueBatch> batches;

  /// Route-name search shows all batches; doc-id search shows only matching
  /// scan sets within the route.
  QueueRouteSearchResult? filterForSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return QueueRouteSearchResult(route: this, visibleBatches: batches);
    }

    if (route.toLowerCase().contains(normalized)) {
      return QueueRouteSearchResult(route: this, visibleBatches: batches);
    }

    final matchingBatches = batches
        .where((batch) => batch.matchesDocSearch(normalized))
        .toList();
    if (matchingBatches.isEmpty) return null;

    return QueueRouteSearchResult(
      route: this,
      visibleBatches: matchingBatches,
    );
  }
}

class QueueRouteSearchResult {
  const QueueRouteSearchResult({
    required this.route,
    required this.visibleBatches,
  });

  final RouteSummary route;
  final List<QueueBatch> visibleBatches;
}

/// One scanner batch under a route (selection unit for scheduling).
class QueueBatch {
  QueueBatch({
    required this.scannedByUserId,
    required this.scannedByName,
    required this.scannedFromLocation,
    required this.count,
    required this.docIdList,
    this.isChecked = false,
  });

  factory QueueBatch.fromJson(JsonMap json) {
    final docs = (json['docIdList'] as List?) ?? const [];
    return QueueBatch(
      scannedByUserId: json['scannedByUserId']?.toString() ?? '',
      scannedByName: json['scannedByName']?.toString() ?? '',
      scannedFromLocation: json['scannedFromLocation']?.toString() ?? '',
      count: _asInt(json['count']) ?? docs.length,
      docIdList: docs.map((e) => e.toString()).toList(),
    );
  }

  final String scannedByUserId;
  final String scannedByName;
  final String scannedFromLocation;
  final int count;
  final List<String> docIdList;
  bool isChecked;

  bool matchesDocSearch(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    return docIdList.any(
      (docId) => docId.toLowerCase().contains(normalizedQuery),
    );
  }

  /// Payload for Schedule New Trip (no docIdList).
  ScheduleBatchSelection toSelection() {
    return ScheduleBatchSelection(
      scannedByUserId: scannedByUserId,
      scannedByName: scannedByName,
      scannedFromLocation: scannedFromLocation,
      count: count,
    );
  }
}

class ScheduleBatchSelection {
  const ScheduleBatchSelection({
    required this.scannedByUserId,
    required this.scannedByName,
    required this.scannedFromLocation,
    required this.count,
  });

  final String scannedByUserId;
  final String scannedByName;
  final String scannedFromLocation;
  final int count;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

import '../../../utils/api_message.dart';

typedef JsonMap = Map<String, dynamic>;

class DeliveryReportRow {
  const DeliveryReportRow({
    required this.docId,
    required this.status,
    required this.originWarehouse,
    required this.docDate,
    required this.tripId,
    required this.comment,
    required this.customerId,
    required this.lastUpdatedAt,
    required this.firmName,
    required this.address,
    required this.city,
    required this.pincode,
    required this.createdBy,
    required this.createdByPersonName,
    required this.createdByLocation,
    required this.drivenBy,
    required this.driverName,
    required this.vehicleNbr,
    required this.route,
    required this.tripStatus,
  });

  factory DeliveryReportRow.fromJson(JsonMap json) {
    return DeliveryReportRow(
      docId: _string(json['docId']),
      status: _string(json['status']),
      originWarehouse: _string(json['originWarehouse']),
      docDate: DateTime.tryParse(_string(json['docDate'])),
      tripId: _int(json['tripId']),
      comment: _string(json['comment']),
      customerId: _string(json['customerId']),
      lastUpdatedAt: DateTime.tryParse(_string(json['lastUpdatedAt'])),
      firmName: _string(json['firmName']),
      address: _string(json['address']),
      city: _string(json['city']),
      pincode: _string(json['pincode']),
      createdBy: _string(json['createdBy']),
      createdByPersonName: _string(json['createdByPersonName']),
      createdByLocation: _string(json['createdByLocation']),
      drivenBy: _string(json['drivenBy']),
      driverName: _string(json['driverName']),
      vehicleNbr: _string(json['vehicleNbr']),
      route: _string(json['route']),
      tripStatus: _string(json['tripStatus']),
    );
  }

  final String docId;
  final String status;
  final String originWarehouse;
  final DateTime? docDate;
  final int? tripId;
  final String comment;
  final String customerId;
  final DateTime? lastUpdatedAt;
  final String firmName;
  final String address;
  final String city;
  final String pincode;
  final String createdBy;
  final String createdByPersonName;
  final String createdByLocation;
  final String drivenBy;
  final String driverName;
  final String vehicleNbr;
  final String route;
  final String tripStatus;

  bool get isDelivered => status.toUpperCase() == 'DELIVERED';
  bool get isUndelivered => status.toUpperCase() == 'UNDELIVERED';

  String get tripCreatorLabel {
    final parts = [
      createdByPersonName.trim(),
      createdBy.trim(),
      createdByLocation.trim(),
    ].where((part) => part.isNotEmpty);
    return parts.join(' / ');
  }

  String get driverLabel {
    final name = driverName.trim();
    final id = drivenBy.trim();
    if (name.isEmpty) return id;
    if (id.isEmpty) return name;
    return '$name / $id';
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class DeliveryReportDataResponse {
  const DeliveryReportDataResponse({
    required this.success,
    required this.message,
    required this.rows,
    required this.totalRecords,
    required this.statusCode,
  });

  factory DeliveryReportDataResponse.fromJson(JsonMap json) {
    final rawRows = json['data'];
    return DeliveryReportDataResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      rows: rawRows is List
          ? rawRows
                .whereType<JsonMap>()
                .map(DeliveryReportRow.fromJson)
                .toList(growable: false)
          : const [],
      totalRecords: _int(json['totalRecords']) ?? 0,
      statusCode: _int(json['statusCode']) ?? 200,
    );
  }

  final bool success;
  final String message;
  final List<DeliveryReportRow> rows;
  final int totalRecords;
  final int statusCode;

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class DeliveryReportCountResponse {
  const DeliveryReportCountResponse({
    required this.success,
    required this.message,
    required this.totalRecords,
    required this.statusCode,
  });

  factory DeliveryReportCountResponse.fromJson(JsonMap json) {
    return DeliveryReportCountResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      totalRecords: _int(json['totalRecords']) ?? 0,
      statusCode: _int(json['statusCode']) ?? 200,
    );
  }

  final bool success;
  final String message;
  final int totalRecords;
  final int statusCode;

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class DeliveryReportExcelDownload {
  const DeliveryReportExcelDownload({
    required this.bytes,
    required this.fileName,
  });

  final List<int> bytes;
  final String fileName;
}

class DocSignatureResult {
  const DocSignatureResult({
    required this.found,
    required this.signature,
    required this.lastUpdatedAt,
    required this.message,
  });

  factory DocSignatureResult.found({
    required String signature,
    required DateTime? lastUpdatedAt,
  }) {
    return DocSignatureResult(
      found: true,
      signature: signature,
      lastUpdatedAt: lastUpdatedAt,
      message: '',
    );
  }

  factory DocSignatureResult.notFound([String message = '']) {
    return DocSignatureResult(
      found: false,
      signature: '',
      lastUpdatedAt: null,
      message: message,
    );
  }

  final bool found;
  final String signature;
  final DateTime? lastUpdatedAt;
  final String message;
}

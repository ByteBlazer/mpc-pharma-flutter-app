import '../../utils/api_message.dart';
import '../../utils/build_timestamp.dart';

typedef JsonMap = Map<String, dynamic>;

class ScheduledTripsResponse {
  const ScheduledTripsResponse({
    required this.success,
    required this.message,
    required this.trips,
    required this.totalTrips,
  });

  factory ScheduledTripsResponse.fromJson(JsonMap json) {
    final list = (json['trips'] as List?) ?? const [];
    return ScheduledTripsResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      trips: list.whereType<JsonMap>().map(ScheduledTrip.fromJson).toList(),
      totalTrips: _asInt(json['totalTrips']) ?? 0,
    );
  }

  final bool success;
  final String message;
  final List<ScheduledTrip> trips;
  final int totalTrips;
}

class ScheduledTrip {
  const ScheduledTrip({
    required this.tripId,
    required this.createdBy,
    required this.driverName,
    required this.vehicleNumber,
    required this.status,
    required this.route,
    required this.createdAt,
    required this.deliveryCountStatusMsg,
    required this.dropOffCountStatusMsg,
  });

  factory ScheduledTrip.fromJson(JsonMap json) {
    return ScheduledTrip(
      tripId: _asInt(json['tripId']) ?? 0,
      createdBy: json['createdBy']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt']),
      deliveryCountStatusMsg:
          json['deliveryCountStatusMsg']?.toString() ?? '',
      dropOffCountStatusMsg: json['dropOffCountStatusMsg']?.toString() ?? '',
    );
  }

  final int tripId;
  final String createdBy;
  final String driverName;
  final String vehicleNumber;
  final String status;
  final String route;
  final DateTime? createdAt;
  final String deliveryCountStatusMsg;
  final String dropOffCountStatusMsg;

  String get createdAtFormatted {
    final at = createdAt;
    if (at == null) return '';
    return formatBuildTimestampIst(at);
  }
}

class CancelTripResult {
  const CancelTripResult({
    required this.statusCode,
    required this.success,
    required this.message,
  });

  factory CancelTripResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    final ok = statusCode >= 200 && statusCode < 300;
    return CancelTripResult(
      statusCode: statusCode,
      success: ok && json['success'] != false,
      message: formatApiMessage(
        json['message'] ?? json['error'],
        fallback: '',
      ),
    );
  }

  factory CancelTripResult.unreachable() {
    return const CancelTripResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;

  String get displayMessage => message.isEmpty
      ? 'Something went wrong. Please try again.'
      : message;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

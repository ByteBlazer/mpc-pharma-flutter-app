import '../../utils/api_message.dart';

typedef JsonMap = Map<String, dynamic>;

class DriverListResponse {
  const DriverListResponse({
    required this.success,
    required this.message,
    required this.drivers,
  });

  factory DriverListResponse.fromJson(JsonMap json) {
    final list = (json['drivers'] as List?) ?? const [];
    return DriverListResponse(
      success: json['success'] == true,
      message: formatApiMessage(json['message'], fallback: ''),
      drivers: list.whereType<JsonMap>().map(TripDriver.fromJson).toList(),
    );
  }

  final bool success;
  final String message;
  final List<TripDriver> drivers;
}

class TripDriver {
  const TripDriver({
    required this.userId,
    required this.driverName,
    required this.vehicleNumber,
    required this.baseLocationName,
    required this.sameLocation,
    required this.self,
  });

  factory TripDriver.fromJson(JsonMap json) {
    return TripDriver(
      userId: json['userId']?.toString() ?? '',
      driverName: json['driverName']?.toString() ?? '',
      vehicleNumber: json['vehicleNumber']?.toString() ?? '',
      baseLocationName: json['baseLocationName']?.toString() ?? '',
      sameLocation: json['sameLocation'] == true,
      self: json['self'] == true,
    );
  }

  final String userId;
  final String driverName;
  final String vehicleNumber;
  final String baseLocationName;
  final bool sameLocation;
  final bool self;
}

class ScheduleNewTripResult {
  const ScheduleNewTripResult({
    required this.statusCode,
    required this.success,
    required this.message,
    this.tripId,
    this.documentsLoaded,
  });

  factory ScheduleNewTripResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    return ScheduleNewTripResult(
      statusCode: statusCode,
      success: statusCode == 201,
      message: formatApiMessage(
        json['message'] ?? json['error'],
        fallback: '',
      ),
      tripId: _asInt(json['tripId']),
      documentsLoaded: _asInt(json['documentsLoaded']),
    );
  }

  factory ScheduleNewTripResult.unreachable() {
    return const ScheduleNewTripResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;
  final int? tripId;
  final int? documentsLoaded;

  String get displayMessage => message.isEmpty
      ? 'Something went wrong. Please try again.'
      : message;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

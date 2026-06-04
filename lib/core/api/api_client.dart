import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import '../models/models.dart';
import '../storage/prefs_service.dart';
import '../utils/jwt_utils.dart';
import 'auth_interceptor.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient(this._prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _dio.interceptors.add(AuthInterceptor(_prefs));
  }

  late final Dio _dio;
  final PrefsService _prefs;

  String get _authHeader {
    final token = _prefs.accessToken ?? '';
    return JwtUtils.bearerToken(token);
  }

  Future<void> generateOtp({
    required String mobile,
    required String appCode,
  }) async {
    await _dio.post<void>(
      'auth/generate-otp',
      queryParameters: {'appCode': appCode},
      data: LoginRequest(mobile: mobile).toJson(),
    );
  }

  Future<OtpVerificationResponse> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'auth/validate-otp',
      data: OtpRequestBody(mobile: mobile, otp: otp).toJson(),
    );
    return OtpVerificationResponse.fromJson(response.data ?? {});
  }

  Future<void> sendLocation(LocationData location) async {
    await _dio.post<void>(
      'location/register',
      data: location.toJson(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<DispatchQueueResponse> getDispatchQueue() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'doc/dispatch-queue',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return DispatchQueueResponse.fromJson(response.data ?? {});
  }

  Future<ScanDocSuccessResponse> scanDoc({
    required String barcode,
    required bool unscan,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'doc/scan-and-add/$barcode',
      queryParameters: {'unscan': unscan},
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ScanDocSuccessResponse.fromJson(response.data ?? {});
  }

  Future<DriverListResponse> getDriverList() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/available-drivers',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return DriverListResponse.fromJson(response.data ?? {});
  }

  Future<ScheduleNewTripResponse> scheduleNewTrip(
    ScheduleNewTripRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trip',
      data: request.toJson(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ScheduleNewTripResponse.fromJson(response.data ?? {});
  }

  Future<ScheduledTripsResponse> getScheduledTrips() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/scheduled-trips-same-location',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ScheduledTripsResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> cancelScheduledTrip(String tripId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trip/cancel/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<ScheduledTripsResponse> getMyTrips() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/my-trips',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ScheduledTripsResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> startTrip(String tripId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trip/start/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<SingleTripDetailsResponse> getSingleTripDetails(String tripId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return SingleTripDetailsResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> dropOff({
    required String tripId,
    required String heading,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trip/drop-off-lot/$tripId/$heading',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> endTrip(String tripId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'trip/end/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> markAsDelivered({
    required String docId,
    required MarkAsDeliveredRequest body,
    required bool updateCustomerLocation,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      'doc/mark-delivery/$docId',
      queryParameters: {'updateCustomerLocation': updateCustomerLocation},
      data: body.toJson(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<ApiResponse> markAsUndelivered({
    required String docId,
    required MarkAsUnDeliveredRequest body,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      'doc/mark-delivery-failed/$docId',
      data: body.toJson(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return ApiResponse.fromJson(response.data ?? {});
  }

  Future<RecentSignatureResponse> getRecentSignature({
    required String tripId,
    required String docId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'doc/recent-signature/$tripId/$docId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return RecentSignatureResponse.fromJson(response.data ?? {});
  }

  static String parseError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          AppConstants.networkLossMessage;
    }
    return error.message ?? AppConstants.networkLossMessage;
  }
}

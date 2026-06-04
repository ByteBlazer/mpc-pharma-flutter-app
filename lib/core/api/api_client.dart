import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import '../models/models.dart';
import '../models/web_portal_models.dart';
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

  // --- Web portal ---

  Future<List<WebPortalUser>> getPortalUsers() async {
    final response = await _dio.get<List<dynamic>>(
      'auth/users',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? [])
        .map((e) => WebPortalUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WebPortalUserRole>> getPortalUserRoles() async {
    final response = await _dio.get<List<dynamic>>(
      'auth/user-roles',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? [])
        .map((e) => WebPortalUserRole.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WebPortalBaseLocation>> getPortalBaseLocations() async {
    final response = await _dio.get<List<dynamic>>(
      'auth/base-locations',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? [])
        .map((e) => WebPortalBaseLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createPortalUser(WebPortalUserFormData data) async {
    await _dio.post<void>(
      'auth/users',
      data: data.toJson(includeIsActive: false),
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<void> updatePortalUser(
    String userId,
    WebPortalUserFormData data,
  ) async {
    await _dio.put<void>(
      'auth/users/$userId',
      data: data.toJson(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<void> createPortalBaseLocation({required String name}) async {
    await _dio.post<void>(
      'auth/base-locations',
      data: {'name': name},
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<void> updatePortalBaseLocation(
    String locationId, {
    required String name,
  }) async {
    await _dio.put<void>(
      'auth/base-locations/$locationId',
      data: {'name': name},
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<WebPortalSetting> getPortalSetting(String settingName) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'setting/$settingName',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalSetting.fromJson(response.data ?? {});
  }

  Future<void> updatePortalSetting({
    required String settingName,
    required String settingValue,
  }) async {
    await _dio.put<void>(
      'setting',
      data: {'settingName': settingName, 'settingValue': settingValue},
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<WebPortalAllTripsResponse> getAllTrips() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/all-trips',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalAllTripsResponse.fromJson(response.data ?? {});
  }

  Future<WebPortalTrip> getPortalTripDetail(int tripId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalTrip.fromJson(response.data ?? {});
  }

  Future<void> forceEndTrip(int tripId) async {
    await _dio.post<void>(
      'trip/force-end/$tripId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  Future<WebPortalDocSearchResponse> searchDoc(String docId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'trip/doc-search/$docId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalDocSearchResponse.fromJson(response.data ?? {});
  }

  Future<WebPortalDeliveryStatusResponse> getDocDeliveryStatus(
    String docId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'doc/delivery-status/$docId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalDeliveryStatusResponse.fromJson(response.data ?? {});
  }

  Future<WebPortalBackupListResponse> listBackups() async {
    final response = await _dio.get<Map<String, dynamic>>(
      'setting/backups',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalBackupListResponse.fromJson(response.data ?? {});
  }

  Future<WebPortalCreateBackupResponse> createBackup() async {
    final response = await _dio.post<Map<String, dynamic>>(
      'setting/backup',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalCreateBackupResponse.fromJson(response.data ?? {});
  }

  Future<void> restoreBackup({
    required String filename,
    required String passkey,
  }) async {
    await _dio.post<void>(
      'setting/restore',
      data: {'filename': filename, 'passkey': passkey},
      options: Options(headers: {'Authorization': _authHeader}),
    );
  }

  String backupDownloadUrl(String filename) =>
      '${AppConfig.baseUrl}setting/backup/download/$filename';

  Future<List<WebPortalLightweightCustomer>>
      getLightweightCustomers() async {
    final response = await _dio.get<List<dynamic>>(
      'customers',
      queryParameters: {'lightweight': 'true'},
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? [])
        .map(
          (e) => WebPortalLightweightCustomer.fromJson(
            e as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<List<String>> getRoutes() async {
    final response = await _dio.get<List<dynamic>>(
      'routes',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? []).map((e) => e.toString()).toList();
  }

  Future<List<String>> getOriginWarehouses() async {
    final response = await _dio.get<List<dynamic>>(
      'origin-warehouses',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return (response.data ?? []).map((e) => e.toString()).toList();
  }

  Future<WebPortalDeliveryReportResponse> getDeliveryReport(
    WebPortalDeliveryReportFilters filters,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'report/delivery-report-data',
      queryParameters: filters.toQueryParams(),
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalDeliveryReportResponse.fromJson(response.data ?? {});
  }

  Future<WebPortalSignatureResponse> getDocSignature(String docId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      'doc/signature/$docId',
      options: Options(headers: {'Authorization': _authHeader}),
    );
    return WebPortalSignatureResponse.fromJson(response.data ?? {});
  }

  Future<List<int>> downloadBackupBytes(String filename) async {
    final response = await _dio.get<List<int>>(
      'setting/backup/download/$filename',
      options: Options(
        headers: {'Authorization': _authHeader},
        responseType: ResponseType.bytes,
      ),
    );
    return response.data ?? [];
  }

  static String parseError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          AppConstants.networkLossMessage;
    }

    if (kIsWeb &&
        (error.type == DioExceptionType.connectionError ||
            error.type == DioExceptionType.unknown)) {
      return 'Cannot reach the API from the browser (CORS). '
          'Run on Android/iOS, use a local API with '
          '--dart-define=API_BASE_URL=http://localhost:3000/api/, '
          'or run ./scripts/run_web_dev.sh for local Chrome testing.';
    }

    return error.message ?? AppConstants.networkLossMessage;
  }
}

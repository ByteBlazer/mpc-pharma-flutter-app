import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_environment.dart';
import 'auth_models.dart';
import 'auth_token_store.dart';
import '../features/customers/customer_models.dart' hide JsonMap;
import '../features/departments/department_models.dart' hide JsonMap;
import '../features/my_trips/my_trips_models.dart' hide JsonMap;
import '../features/notifications/notification_models.dart' hide JsonMap;
import '../features/queue/queue_models.dart' hide JsonMap;
import '../features/queue/schedule_models.dart' hide JsonMap;
import '../features/scan/scan_models.dart' hide JsonMap;
import '../features/settings/backup_models.dart' hide JsonMap;
import '../features/settings/setting_models.dart' hide JsonMap;
import '../features/tickets/ticket_models.dart' hide JsonMap;
import '../features/trip_dashboard/trip_dashboard_models.dart';
import '../features/trips/trips_models.dart' hide JsonMap;
import '../features/users/user_models.dart' hide JsonMap;
import '../utils/api_message.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    http.Client? httpClient,
    AuthTokenStore? tokenStore,
    String? baseUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _tokenStore = tokenStore ?? AuthTokenStore(),
       _baseUrl = baseUrl ?? AppEnvironment.apiBaseUrl;

  final http.Client _httpClient;
  final AuthTokenStore _tokenStore;
  final String _baseUrl;

  void close() => _httpClient.close();

  Future<void> generateOtp({
    required String mobile,
    required String appCode,
  }) async {
    await _post(
      'auth/generate-otp',
      queryParameters: {'appCode': appCode},
      body: LoginRequest(mobile: mobile).toJson(),
    );
  }

  Future<OtpVerificationResponse> verifyOtp({
    required String mobile,
    required String otp,
  }) async {
    final response = await _post(
      'auth/validate-otp',
      body: OtpRequestBody(mobile: mobile, otp: otp).toJson(),
    );
    final otpResponse = OtpVerificationResponse.fromJson(
      _decodeJsonObject(response.body),
    );
    final accessToken = otpResponse.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokenStore.clearToken();
      await _tokenStore.saveToken(accessToken);
    }
    return otpResponse;
  }

  /// Unauthenticated. Returns epoch seconds from `{ "buildTimestampEpoch": … }`.
  Future<int> getBuildTimestampEpoch() async {
    final response = await _get('build-timestamp', requiresAuth: false);
    final value = _decodeJsonObject(response.body)['buildTimestampEpoch'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    throw FormatException(
      'Expected buildTimestampEpoch in response',
      response.body,
    );
  }

  Future<OtpVerificationResponse> impersonate({
    String? token,
    String? employeeId,
    String? customerId,
  }) async {
    final trimmedEmployeeId = employeeId?.trim() ?? '';
    final trimmedCustomerId = customerId?.trim() ?? '';
    final hasEmployeeId = trimmedEmployeeId.isNotEmpty;
    final hasCustomerId = trimmedCustomerId.isNotEmpty;
    if (hasEmployeeId == hasCustomerId) {
      throw ArgumentError(
        'Provide exactly one of employeeId or customerId for impersonation.',
      );
    }

    final body = <String, String>{
      if (hasEmployeeId) 'employeeId': trimmedEmployeeId,
      if (hasCustomerId) 'customerId': trimmedCustomerId,
    };

    final response = await _post(
      'auth/impersonate',
      token: token,
      requiresAuth: true,
      body: body,
    );
    final impersonationResponse = OtpVerificationResponse.fromJson(
      _decodeJsonObject(response.body),
    );
    final accessToken = impersonationResponse.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      await _tokenStore.beginImpersonation(accessToken);
    }
    return impersonationResponse;
  }

  Future<void> sendLocation({
    String? token,
    required String latitude,
    required String longitude,
  }) async {
    await _post(
      'location/register',
      token: token,
      requiresAuth: true,
      body: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
  }

  Future<TripActionResult> registerLocation({
    String? token,
    required String latitude,
    required String longitude,
  }) async {
    try {
      final response = await _post(
        'location/register',
        token: token,
        requiresAuth: true,
        body: {
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      return TripActionResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return TripActionResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return TripActionResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return TripActionResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return TripActionResult.unreachable();
    }
  }

  Future<DispatchQueueResponse> getDispatchQueueList({String? token}) async {
    final response = await _get(
      'doc/dispatch-queue',
      token: token,
      requiresAuth: true,
    );
    return DispatchQueueResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<ScanDocResult> scanDoc({
    String? token,
    required String barcode,
    required bool unscan,
  }) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return const ScanDocResult(
        statusCode: 400,
        success: false,
        message: 'Barcode is required.',
      );
    }

    try {
      final response = await _post(
        'doc/scan-and-add/${Uri.encodeComponent(trimmed)}',
        token: token,
        requiresAuth: true,
        queryParameters: {'unscan': unscan.toString()},
      ).timeout(const Duration(seconds: 25));
      return ScanDocResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return ScanDocResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      try {
        return ScanDocResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return ScanDocResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return ScanDocResult.unreachable();
    }
  }

  Future<DriverListResponse> getDriverList({String? token}) async {
    final response = await _get(
      'trip/available-drivers',
      token: token,
      requiresAuth: true,
    );
    return DriverListResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<ScheduleNewTripResult> scheduleNewTrip({
    String? token,
    required String route,
    required List<String> userIds,
    required String driverId,
    required String vehicleNbr,
  }) async {
    try {
      final response = await _post(
        'trip',
        token: token,
        requiresAuth: true,
        body: {
          'route': route,
          'userIds': userIds,
          'driverId': driverId,
          'vehicleNbr': vehicleNbr,
        },
      );
      return ScheduleNewTripResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return ScheduleNewTripResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      try {
        return ScheduleNewTripResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return ScheduleNewTripResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return ScheduleNewTripResult.unreachable();
    }
  }

  Future<ScheduledTripsResponse> getScheduledList({String? token}) async {
    final response = await _get(
      'trip/scheduled-trips-same-location',
      token: token,
      requiresAuth: true,
    );
    return ScheduledTripsResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<CancelTripResult> cancelScheduledTrip({
    String? token,
    required int tripId,
  }) async {
    try {
      final response = await _post(
        'trip/cancel/${Uri.encodeComponent(tripId.toString())}',
        token: token,
        requiresAuth: true,
      );
      return CancelTripResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return CancelTripResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      try {
        return CancelTripResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return CancelTripResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return CancelTripResult.unreachable();
    }
  }

  Future<MyTripsListResponse> getMyTripsList({String? token}) async {
    final response = await _get(
      'trip/my-trips',
      token: token,
      requiresAuth: true,
    );
    return MyTripsListResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<TripActionResult> startTrip({
    String? token,
    required int tripId,
  }) async {
    try {
      final response = await _post(
        'trip/start/${Uri.encodeComponent(tripId.toString())}',
        token: token,
        requiresAuth: true,
      );
      return TripActionResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return TripActionResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return TripActionResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return TripActionResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return TripActionResult.unreachable();
    }
  }

  Future<SingleTripDetails> getSingleTripDetails({
    String? token,
    required int tripId,
  }) async {
    final response = await _get(
      'trip/${Uri.encodeComponent(tripId.toString())}',
      token: token,
      requiresAuth: true,
    );
    return SingleTripDetails.fromJson(_decodeJsonObject(response.body));
  }

  Future<AllTripsResponse> getAllTrips({String? token}) async {
    final response = await _get(
      'trip/all-trips',
      token: token,
      requiresAuth: true,
    );
    return AllTripsResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<DocSearchResult> searchTripByDocId({
    String? token,
    required String docId,
  }) async {
    final response = await _get(
      'trip/doc-search/${Uri.encodeComponent(docId.trim())}',
      token: token,
      requiresAuth: true,
    );
    return DocSearchResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<DeliveryStatusDetails> getDocDeliveryStatus({
    String? token,
    required String docId,
  }) async {
    final response = await _get(
      'doc/delivery-status/${Uri.encodeComponent(docId.trim())}',
      token: token,
      requiresAuth: true,
    );
    return DeliveryStatusDetails.fromJson(_decodeJsonObject(response.body));
  }

  Future<ForceEndTripResult> forceEndTrip({
    String? token,
    required int tripId,
  }) async {
    try {
      final response = await _post(
        'trip/force-end/${Uri.encodeComponent(tripId.toString())}',
        token: token,
        requiresAuth: true,
        body: const <String, dynamic>{},
      );
      return ForceEndTripResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return ForceEndTripResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return ForceEndTripResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return ForceEndTripResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return ForceEndTripResult.unreachable();
    }
  }

  Future<TripActionResult> dropOffLot({
    String? token,
    required int tripId,
    required String heading,
  }) async {
    try {
      final response = await _post(
        'trip/drop-off-lot/${Uri.encodeComponent(tripId.toString())}/${Uri.encodeComponent(heading)}',
        token: token,
        requiresAuth: true,
      );
      return TripActionResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return TripActionResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return TripActionResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return TripActionResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return TripActionResult.unreachable();
    }
  }

  Future<TripActionResult> endTrip({
    String? token,
    required int tripId,
  }) async {
    try {
      final response = await _post(
        'trip/end/${Uri.encodeComponent(tripId.toString())}',
        token: token,
        requiresAuth: true,
      );
      return TripActionResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return TripActionResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return TripActionResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return TripActionResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return TripActionResult.unreachable();
    }
  }

  Future<MarkDeliveriesBatchResult> markDeliveriesBatch({
    String? token,
    required int tripId,
    required List<String> docIds,
    required String signature,
    required bool updateCustomerLocation,
    String deliveryComment = '',
    double? deliveryLatitude,
    double? deliveryLongitude,
  }) async {
    try {
      final body = <String, dynamic>{
        'tripId': tripId,
        'docIds': docIds,
        'signature': signature,
        'deliveryComment': deliveryComment,
        'updateCustomerLocation': updateCustomerLocation,
        'deliveryLatitude': deliveryLatitude,
        'deliveryLongitude': deliveryLongitude,
      };
      final response = await _put(
        'doc/mark-deliveries-batch',
        token: token,
        requiresAuth: true,
        body: body,
      );
      return MarkDeliveriesBatchResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return MarkDeliveriesBatchResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return MarkDeliveriesBatchResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return MarkDeliveriesBatchResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return MarkDeliveriesBatchResult.unreachable();
    }
  }

  Future<TripActionResult> markAsUnDelivered({
    String? token,
    required String docId,
    required String failureComment,
  }) async {
    try {
      final response = await _put(
        'doc/mark-delivery-failed/${Uri.encodeComponent(docId)}',
        token: token,
        requiresAuth: true,
        body: {'failureComment': failureComment},
      );
      return TripActionResult.fromHttp(
        statusCode: response.statusCode,
        json: _decodeJsonObject(response.body),
      );
    } on TimeoutException {
      return TripActionResult.unreachable();
    } on MissingAuthTokenException {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      try {
        return TripActionResult.fromHttp(
          statusCode: error.statusCode,
          json: _decodeJsonObject(error.responseBody),
        );
      } catch (_) {
        return TripActionResult(
          statusCode: error.statusCode,
          success: false,
          message: error.toString(),
        );
      }
    } catch (_) {
      return TripActionResult.unreachable();
    }
  }

  Future<RecentSignatureResult> getRecentSignature({
    String? token,
    required int tripId,
    required String docId,
  }) async {
    try {
      final response = await _get(
        'doc/recent-signature/${Uri.encodeComponent(tripId.toString())}/${Uri.encodeComponent(docId)}',
        token: token,
        requiresAuth: true,
      );
      final json = _decodeJsonObject(response.body);
      final signature = json['signature']?.toString() ?? '';
      if (signature.isEmpty) return RecentSignatureResult.none();
      return RecentSignatureResult.found(signature);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) rethrow;
      // 400 "no recent signature" is a normal empty case.
      return RecentSignatureResult.none(error.toString());
    } on MissingAuthTokenException {
      rethrow;
    } catch (_) {
      return RecentSignatureResult.none();
    }
  }

  Future<List<UserAccount>> getUsers({String? token}) async {
    final response = await _get('auth/users', token: token, requiresAuth: true);
    return _decodeJsonList(response.body).map(UserAccount.fromJson).toList();
  }

  Future<UserAccount> getUser({String? token, required String userId}) async {
    final response = await _get(
      'auth/users/${Uri.encodeComponent(userId)}',
      token: token,
      requiresAuth: true,
    );
    return UserAccount.fromJson(_decodeJsonObject(response.body));
  }

  Future<void> createUser({
    String? token,
    required UserAccountSaveRequest request,
  }) async {
    await _post(
      'auth/users',
      token: token,
      requiresAuth: true,
      body: request.toJson(),
    );
  }

  Future<void> updateUser({
    String? token,
    required String userId,
    required UserAccountSaveRequest request,
  }) async {
    await _put(
      'auth/users/${Uri.encodeComponent(userId)}',
      token: token,
      requiresAuth: true,
      body: request.toJson(includeIsActive: true),
    );
  }

  Future<List<UserRoleOption>> getUserRoles({String? token}) async {
    final response = await _get(
      'auth/user-roles',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body)
        .map(UserRoleOption.fromJson)
        .where((option) => option.role != null)
        .toList();
  }

  Future<List<BaseLocation>> getBaseLocations({String? token}) async {
    final response = await _get(
      'auth/base-locations',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body).map(BaseLocation.fromJson).toList();
  }

  Future<void> createBaseLocation({
    String? token,
    required BaseLocationSaveRequest request,
  }) async {
    await _post(
      'auth/base-locations',
      token: token,
      requiresAuth: true,
      body: request.toJson(),
    );
  }

  Future<void> updateBaseLocation({
    String? token,
    required String id,
    required BaseLocationSaveRequest request,
  }) async {
    await _put(
      'auth/base-locations/${Uri.encodeComponent(id)}',
      token: token,
      requiresAuth: true,
      body: request.toJson(),
    );
  }

  Future<List<Department>> getDepartments({String? token}) async {
    final response = await _get(
      'auth/departments',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body).map(Department.fromJson).toList();
  }

  Future<Department> createDepartment({
    String? token,
    required DepartmentSaveRequest request,
  }) async {
    final response = await _post(
      'auth/departments',
      token: token,
      requiresAuth: true,
      body: request.toJson(),
    );
    return Department.fromJson(_decodeJsonObject(response.body));
  }

  Future<Department> updateDepartment({
    String? token,
    required String id,
    required DepartmentSaveRequest request,
  }) async {
    final response = await _put(
      'auth/departments/${Uri.encodeComponent(id)}',
      token: token,
      requiresAuth: true,
      body: request.toJson(),
    );
    return Department.fromJson(_decodeJsonObject(response.body));
  }

  Future<Department> setDepartmentLead({
    String? token,
    required String departmentId,
    required String userId,
    required bool isDepartmentLead,
  }) async {
    final response = await _put(
      'auth/departments/${Uri.encodeComponent(departmentId)}/users/${Uri.encodeComponent(userId)}/lead',
      token: token,
      requiresAuth: true,
      body: {'isDepartmentLead': isDepartmentLead},
    );
    return Department.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<CustomerSummary>> getCustomersLightweight({String? token}) async {
    final response = await _get(
      'customers',
      token: token,
      requiresAuth: true,
      queryParameters: {'lightweight': 'true'},
    );
    return _decodeJsonList(response.body).map(CustomerSummary.fromJson).toList();
  }

  Future<List<Customer>> getCustomersFull({String? token}) async {
    final response = await _get(
      'customers',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body).map(Customer.fromJson).toList();
  }

  Future<Customer> getCustomer({
    String? token,
    required String id,
  }) async {
    final response = await _get(
      'customers/${Uri.encodeComponent(id)}',
      token: token,
      requiresAuth: true,
    );
    return Customer.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<ComplaintCategory>> getComplaintCategories({String? token}) async {
    final response = await _get(
      'ticket/complaint-category',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body)
        .map(ComplaintCategory.fromJson)
        .toList();
  }

  Future<ComplaintCategory> createComplaintCategory({
    String? token,
    required String name,
    required String assignedDepartmentId,
    required int slaHours,
    bool isActive = true,
  }) async {
    final response = await _post(
      'ticket/complaint-category',
      token: token,
      requiresAuth: true,
      body: {
        'name': name,
        'assignedDepartmentId': assignedDepartmentId,
        'slaHours': slaHours,
        'isActive': isActive,
      },
    );
    return ComplaintCategory.fromJson(_decodeJsonObject(response.body));
  }

  Future<ComplaintCategory> updateComplaintCategory({
    String? token,
    required String categoryId,
    required String name,
    required String assignedDepartmentId,
    required int slaHours,
    required bool isActive,
  }) async {
    final response = await _put(
      'ticket/complaint-category/${Uri.encodeComponent(categoryId)}',
      token: token,
      requiresAuth: true,
      body: {
        'name': name,
        'assignedDepartmentId': assignedDepartmentId,
        'slaHours': slaHours,
        'isActive': isActive,
      },
    );
    return ComplaintCategory.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<InternalCategory>> getInternalCategories({String? token}) async {
    final response = await _get(
      'ticket/internal-category',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body)
        .map(InternalCategory.fromJson)
        .toList();
  }

  Future<InternalCategory> createInternalCategory({
    String? token,
    required String name,
    required int slaHours,
    bool isActive = true,
  }) async {
    final response = await _post(
      'ticket/internal-category',
      token: token,
      requiresAuth: true,
      body: {
        'name': name,
        'slaHours': slaHours,
        'isActive': isActive,
      },
    );
    return InternalCategory.fromJson(_decodeJsonObject(response.body));
  }

  Future<InternalCategory> updateInternalCategory({
    String? token,
    required String categoryId,
    required String name,
    required int slaHours,
    required bool isActive,
  }) async {
    final response = await _put(
      'ticket/internal-category/${Uri.encodeComponent(categoryId)}',
      token: token,
      requiresAuth: true,
      body: {
        'name': name,
        'slaHours': slaHours,
        'isActive': isActive,
      },
    );
    return InternalCategory.fromJson(_decodeJsonObject(response.body));
  }

  Future<TicketAttachmentInitResponse> initiateTicketAttachmentUpload({
    String? token,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    final response = await _post(
      'ticket/attachment',
      token: token,
      requiresAuth: true,
      body: {
        'fileName': fileName,
        'mimeType': mimeType,
        'fileSize': fileSize,
      },
    );
    return TicketAttachmentInitResponse.fromJson(_decodeJsonObject(response.body));
  }

  Future<void> markTicketAttachmentUploaded({
    String? token,
    required String attachmentId,
  }) async {
    await _put(
      'ticket/attachment/uploaded/${Uri.encodeComponent(attachmentId)}',
      token: token,
      requiresAuth: true,
    );
  }

  Future<TicketAttachmentDownload> getTicketAttachmentDownload({
    String? token,
    required String attachmentId,
  }) async {
    final response = await _get(
      'ticket/attachment/${Uri.encodeComponent(attachmentId)}',
      token: token,
      requiresAuth: true,
    );
    return TicketAttachmentDownload.fromJson(_decodeJsonObject(response.body));
  }

  Future<void> deleteUnlinkedTicketAttachment({
    String? token,
    required String attachmentId,
  }) async {
    await _delete(
      'ticket/attachment/${Uri.encodeComponent(attachmentId)}',
      token: token,
      requiresAuth: true,
    );
  }

  Future<void> uploadBytesToPresignedUrl({
    required String uploadUrl,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final response = await _httpClient.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': mimeType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to upload attachment to storage.');
    }
  }

  Future<List<TicketSummary>> getTickets({String? token}) async {
    final response = await _get('ticket', token: token, requiresAuth: true);
    return _decodeJsonList(response.body).map(TicketSummary.fromJson).toList();
  }

  Future<List<AppNotification>> getNotifications({String? token}) async {
    final response = await _get(
      'notification',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonList(response.body).map(AppNotification.fromJson).toList();
  }

  Future<void> markNotificationRead({
    String? token,
    required String notificationId,
  }) async {
    await _put(
      'notification/${Uri.encodeComponent(notificationId)}/read',
      token: token,
      requiresAuth: true,
    );
  }

  Future<void> markAllNotificationsRead({String? token}) async {
    await _put('notification/read-all', token: token, requiresAuth: true);
  }

  Future<TicketDetail> getTicket({
    String? token,
    required String ticketId,
    required bool isEmployeeView,
  }) async {
    final response = await _get(
      'ticket/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: isEmployeeView,
    );
  }

  Future<TicketDetail> createTicket({
    String? token,
    required JsonMap body,
    required bool isEmployeeView,
  }) async {
    final response = await _post(
      'ticket',
      token: token,
      requiresAuth: true,
      body: body,
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: isEmployeeView,
    );
  }

  Future<TicketDetail> updateTicket({
    String? token,
    required String ticketId,
    required JsonMap body,
    required bool isEmployeeView,
  }) async {
    final response = await _put(
      'ticket/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
      body: body,
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: isEmployeeView,
    );
  }

  Future<void> linkTicketAttachments({
    String? token,
    required String ticketId,
    required List<String> attachmentIds,
  }) async {
    await _post(
      'ticket/${Uri.encodeComponent(ticketId)}/attachments',
      token: token,
      requiresAuth: true,
      body: {'attachmentIds': attachmentIds},
    );
  }

  Future<TicketDetail> startTicketWork({
    String? token,
    required String ticketId,
  }) async {
    final response = await _put(
      'ticket/start/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> assignTicket({
    String? token,
    required String ticketId,
    required String assignedDepartmentId,
    String? assigneeAppUserId,
  }) async {
    final trimmedAssignee = assigneeAppUserId?.trim() ?? '';
    final response = await _put(
      'ticket/assign/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
      body: {
        'assignedDepartmentId': assignedDepartmentId,
        if (trimmedAssignee.isNotEmpty) 'assigneeAppUserId': trimmedAssignee,
      },
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> resolveTicket({
    String? token,
    required String ticketId,
    required String resolutionSummary,
  }) async {
    final response = await _put(
      'ticket/resolve/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
      body: {'resolutionSummary': resolutionSummary},
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> invalidateTicket({
    String? token,
    required String ticketId,
    required String reason,
  }) async {
    final response = await _put(
      'ticket/invalidate/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
      body: {'reason': reason},
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> closeTicket({
    String? token,
    required String ticketId,
  }) async {
    final response = await _put(
      'ticket/close/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> addTicketComment({
    String? token,
    required String ticketId,
    required String comment,
    List<String> attachmentIds = const [],
  }) async {
    final response = await _post(
      'ticket/comment/${Uri.encodeComponent(ticketId)}',
      token: token,
      requiresAuth: true,
      body: {
        'comment': comment,
        'attachmentIds': attachmentIds,
      },
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<TicketDetail> updateTicketComment({
    String? token,
    required String commentId,
    required String comment,
    List<String> attachmentIds = const [],
  }) async {
    final response = await _put(
      'ticket/comment/${Uri.encodeComponent(commentId)}',
      token: token,
      requiresAuth: true,
      body: {
        'comment': comment,
        'attachmentIds': attachmentIds,
      },
    );
    return TicketDetail.fromJson(
      _decodeJsonObject(response.body),
      isEmployeeView: true,
    );
  }

  Future<Department> setDepartmentTicketTriager({
    String? token,
    required String departmentId,
    required String userId,
  }) async {
    final response = await _put(
      'auth/departments/${Uri.encodeComponent(departmentId)}/users/${Uri.encodeComponent(userId)}/triager',
      token: token,
      requiresAuth: true,
    );
    return Department.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<BackupFile>> listDatabaseBackups({String? token}) async {
    final response = await _get(
      'setting/backups',
      token: token,
      requiresAuth: true,
    );
    final json = _decodeJsonObject(response.body);
    final raw = json['backups'];
    if (raw is! List) return const [];
    return raw
        .whereType<JsonMap>()
        .map(BackupFile.fromJson)
        .toList(growable: false);
  }

  Future<CreateBackupResult> createDatabaseBackup({String? token}) async {
    final response = await _post(
      'setting/backup',
      token: token,
      requiresAuth: true,
      body: const <String, dynamic>{},
    );
    return CreateBackupResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<List<int>> downloadDatabaseBackup({
    String? token,
    required String filename,
  }) async {
    final response = await _get(
      'setting/backup/download/${Uri.encodeComponent(filename)}',
      token: token,
      requiresAuth: true,
    );
    return response.bodyBytes;
  }

  Future<RestoreBackupResult> restoreDatabaseBackup({
    String? token,
    required String filename,
    required String passkey,
  }) async {
    final response = await _post(
      'setting/restore',
      token: token,
      requiresAuth: true,
      body: {
        'filename': filename,
        'passkey': passkey,
      },
    );
    return RestoreBackupResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<AppSetting> getAppSetting({
    String? token,
    required String settingName,
  }) async {
    final response = await _get(
      'setting/${Uri.encodeComponent(settingName)}',
      token: token,
      requiresAuth: true,
    );
    return AppSetting.fromJson(_decodeJsonObject(response.body));
  }

  Future<UpdateAppSettingResult> updateAppSetting({
    String? token,
    required String settingName,
    required String settingValue,
  }) async {
    final response = await _put(
      'setting',
      token: token,
      requiresAuth: true,
      body: {
        'settingName': settingName,
        'settingValue': settingValue,
      },
    );
    return UpdateAppSettingResult.fromJson(_decodeJsonObject(response.body));
  }

  Future<http.Response> _get(
    String endpoint, {
    String? token,
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'GET',
      endpoint: endpoint,
      token: token,
      requiresAuth: requiresAuth,
      queryParameters: queryParameters,
    );
  }

  Future<http.Response> _post(
    String endpoint, {
    String? token,
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
    JsonMap? body,
  }) {
    return _send(
      method: 'POST',
      endpoint: endpoint,
      token: token,
      requiresAuth: requiresAuth,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<http.Response> _put(
    String endpoint, {
    String? token,
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
    JsonMap? body,
  }) {
    return _send(
      method: 'PUT',
      endpoint: endpoint,
      token: token,
      requiresAuth: requiresAuth,
      queryParameters: queryParameters,
      body: body,
    );
  }

  Future<http.Response> _delete(
    String endpoint, {
    String? token,
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
  }) {
    return _send(
      method: 'DELETE',
      endpoint: endpoint,
      token: token,
      requiresAuth: requiresAuth,
      queryParameters: queryParameters,
    );
  }

  Future<http.Response> _send({
    required String method,
    required String endpoint,
    String? token,
    bool requiresAuth = false,
    Map<String, String>? queryParameters,
    JsonMap? body,
  }) async {
    final uri = _uri(endpoint, queryParameters: queryParameters);
    final authToken = await _resolveToken(token, requiresAuth: requiresAuth);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': _authorizationValue(authToken),
    };

    final encodedBody = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: encodedBody,
      ),
      'PUT' => await _httpClient.put(uri, headers: headers, body: encodedBody),
      'DELETE' => await _httpClient.delete(uri, headers: headers),
      _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    return response;
  }

  Future<String?> _resolveToken(
    String? token, {
    required bool requiresAuth,
  }) async {
    if (token != null && token.trim().isNotEmpty) return token;
    if (!requiresAuth) return null;
    final savedToken = await _tokenStore.readToken();
    if (savedToken == null) {
      throw const MissingAuthTokenException();
    }
    return savedToken;
  }

  Uri _uri(String endpoint, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(_baseUrl);
    final basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final endpointPath = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    return base.replace(
      path: '$basePath/$endpointPath',
      queryParameters: queryParameters,
    );
  }

  static String _authorizationValue(String token) {
    if (token.toLowerCase().startsWith('bearer ')) return token;
    return 'Bearer $token';
  }

  static JsonMap _decodeJsonObject(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    if (decoded is JsonMap) return decoded;
    throw FormatException('Expected JSON object response', body);
  }

  static List<JsonMap> _decodeJsonList(String body) {
    if (body.trim().isEmpty) return const [];
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded.whereType<JsonMap>().toList();
    }
    throw FormatException('Expected JSON array response', body);
  }
}

class MissingAuthTokenException implements Exception {
  const MissingAuthTokenException();

  @override
  String toString() => 'No saved auth token is available.';
}

class ApiException implements Exception {
  ApiException({
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.responseBody,
  });

  final String method;
  final Uri uri;
  final int statusCode;
  final String responseBody;

  @override
  String toString() {
    final message = _extractErrorMessage(responseBody);
    if (message != null && message.isNotEmpty) return message;
    return '$method $uri failed with status $statusCode';
  }

  static String? _extractErrorMessage(String body) {
    if (body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is JsonMap) {
        final message = decoded['message'] ?? decoded['error'];
        if (message == null) return null;
        return formatApiMessage(message, fallback: '');
      }
    } on FormatException {
      return body;
    }
    return null;
  }
}

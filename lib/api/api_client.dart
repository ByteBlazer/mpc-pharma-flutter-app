import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_environment.dart';
import 'auth_models.dart';
import 'auth_token_store.dart';
import '../features/customers/customer_models.dart' hide JsonMap;
import '../features/departments/department_models.dart' hide JsonMap;
import '../features/users/user_models.dart' hide JsonMap;

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
      await _tokenStore.saveToken(accessToken);
    }
    return otpResponse;
  }

  Future<void> sendLocation({
    String? token,
    required JsonMap locationData,
  }) async {
    await _post(
      'location/register',
      token: token,
      requiresAuth: true,
      body: locationData,
    );
  }

  Future<JsonMap> getDispatchQueueList({String? token}) async {
    final response = await _get(
      'doc/dispatch-queue',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> scanDoc({
    String? token,
    required String barcode,
    required bool unscan,
  }) async {
    final response = await _post(
      'doc/scan-and-add/${Uri.encodeComponent(barcode)}',
      token: token,
      requiresAuth: true,
      queryParameters: {'unscan': unscan.toString()},
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> getDriverList({String? token}) async {
    final response = await _get(
      'trip/available-drivers',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> scheduleNewTrip({
    String? token,
    required JsonMap scheduleNewTripRequest,
  }) async {
    final response = await _post(
      'trip',
      token: token,
      requiresAuth: true,
      body: scheduleNewTripRequest,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> getScheduledList({String? token}) async {
    final response = await _get(
      'trip/scheduled-trips-same-location',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> cancelScheduledTrip({
    String? token,
    required String tripId,
  }) async {
    final response = await _post(
      'trip/cancel/${Uri.encodeComponent(tripId)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> getMyTripsList({String? token}) async {
    final response = await _get(
      'trip/my-trips',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> startTrip({String? token, required String tripId}) async {
    final response = await _post(
      'trip/start/${Uri.encodeComponent(tripId)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> getSingleTripDetails({
    String? token,
    required String tripId,
  }) async {
    final response = await _get(
      'trip/${Uri.encodeComponent(tripId)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> dropOff({
    String? token,
    required String tripId,
    required String heading,
  }) async {
    final response = await _post(
      'trip/drop-off-lot/${Uri.encodeComponent(tripId)}/${Uri.encodeComponent(heading)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> endTrip({String? token, required String tripId}) async {
    final response = await _post(
      'trip/end/${Uri.encodeComponent(tripId)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> markAsDelivered({
    String? token,
    required String docId,
    required JsonMap body,
    required bool updateCustomerLocation,
  }) async {
    final response = await _put(
      'doc/mark-delivery/${Uri.encodeComponent(docId)}',
      token: token,
      requiresAuth: true,
      queryParameters: {
        'updateCustomerLocation': updateCustomerLocation.toString(),
      },
      body: body,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> markAsUnDelivered({
    String? token,
    required String docId,
    required JsonMap body,
  }) async {
    final response = await _put(
      'doc/mark-delivery-failed/${Uri.encodeComponent(docId)}',
      token: token,
      requiresAuth: true,
      body: body,
    );
    return _decodeJsonObject(response.body);
  }

  Future<JsonMap> getRecentSignature({
    String? token,
    required String tripId,
    required String docId,
  }) async {
    final response = await _get(
      'doc/recent-signature/${Uri.encodeComponent(tripId)}/${Uri.encodeComponent(docId)}',
      token: token,
      requiresAuth: true,
    );
    return _decodeJsonObject(response.body);
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
        return message?.toString();
      }
    } on FormatException {
      return body;
    }
    return null;
  }
}

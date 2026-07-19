import 'dart:convert';

import '../api/auth_token_store.dart';
import 'app_role.dart';

enum PrincipalType {
  employee('EMPLOYEE'),
  customer('CUSTOMER');

  const PrincipalType(this.tokenValue);

  final String tokenValue;

  static PrincipalType? fromTokenValue(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final type in values) {
      if (type.tokenValue == normalized) return type;
    }
    return null;
  }
}

abstract final class JwtPayload {
  static Map<String, dynamic>? decode(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(payload);
      if (json is Map<String, dynamic>) return json;
    } on FormatException {
      return null;
    }
    return null;
  }

  static Future<bool> currentUserIsAppAdmin({
    AuthTokenStore? tokenStore,
  }) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return false;
    return isAppAdmin(token);
  }

  static bool isImpersonation(String token) {
    final json = decode(token);
    if (json == null) return false;
    return json['impersonation'] == true;
  }

  static Future<bool> currentIsImpersonation({
    AuthTokenStore? tokenStore,
  }) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return false;
    return isImpersonation(token);
  }

  static Future<bool> canStartImpersonation({
    AuthTokenStore? tokenStore,
  }) async {
    if (await currentIsImpersonation(tokenStore: tokenStore)) return false;
    return currentUserIsAppAdmin(tokenStore: tokenStore);
  }

  static bool isAppAdmin(String token) {
    final json = decode(token);
    if (json == null) return false;
    if (principalTypeFromToken(token) != PrincipalType.employee) return false;

    final roles =
        json['roles']?.toString().split(',').toAppRoles() ?? const <AppRole>[];
    return roles.contains(AppRole.appAdmin);
  }

  static bool hasWebAccess(String token) {
    return rolesFromToken(token).hasRole(AppRole.webAccess);
  }

  static Future<bool> currentUserHasWebAccess({
    AuthTokenStore? tokenStore,
  }) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return false;
    return hasWebAccess(token);
  }

  static PrincipalType? principalTypeFromToken(String token) {
    final json = decode(token);
    if (json == null) return null;
    return PrincipalType.fromTokenValue(json['principalType']?.toString()) ??
        PrincipalType.employee;
  }

  static Future<PrincipalType?> currentPrincipalType({
    AuthTokenStore? tokenStore,
  }) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return null;
    return principalTypeFromToken(token);
  }

  static Future<bool> currentUserIsEmployee({
    AuthTokenStore? tokenStore,
  }) async {
    final principalType = await currentPrincipalType(tokenStore: tokenStore);
    return principalType == PrincipalType.employee;
  }

  static Future<bool> currentUserIsCustomer({
    AuthTokenStore? tokenStore,
  }) async {
    final principalType = await currentPrincipalType(tokenStore: tokenStore);
    return principalType == PrincipalType.customer;
  }

  static Future<String?> currentUserId({AuthTokenStore? tokenStore}) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return null;
    return decode(token)?['id']?.toString();
  }

  static List<AppRole> rolesFromToken(String token) {
    final json = decode(token);
    if (json == null) return const [];
    return json['roles']?.toString().split(',').toAppRoles() ?? const [];
  }

  static Future<List<AppRole>> currentRoles({
    AuthTokenStore? tokenStore,
  }) async {
    final token = await (tokenStore ?? AuthTokenStore()).readToken();
    if (token == null) return const [];
    return rolesFromToken(token);
  }

  static Future<bool> currentUserCanAccessScan({
    AuthTokenStore? tokenStore,
  }) async {
    final roles = await currentRoles(tokenStore: tokenStore);
    return roles.hasRole(AppRole.appScanner) ||
        roles.hasRole(AppRole.appTripCreator) ||
        roles.hasRole(AppRole.appAdmin);
  }
}

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

  static bool isAppAdmin(String token) {
    final json = decode(token);
    if (json == null) return false;
    if (principalTypeFromToken(token) != PrincipalType.employee) return false;

    final roles =
        json['roles']?.toString().split(',').toAppRoles() ?? const <AppRole>[];
    return roles.hasRole(AppRole.appAdmin);
  }

  static PrincipalType? principalTypeFromToken(String token) {
    final json = decode(token);
    if (json == null) return null;
    return PrincipalType.fromTokenValue(json['principalType']?.toString());
  }
}

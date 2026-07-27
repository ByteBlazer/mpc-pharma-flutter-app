import 'package:shared_preferences/shared_preferences.dart';

import '../auth/jwt_payload.dart';

class AuthTokenStore {
  static const _tokenKey = 'user_access_token';
  static const _adminTokenKey = 'admin_access_token';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  Future<String?> readAdminToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_adminTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  Future<void> saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<void> beginImpersonation(String impersonationToken) async {
    final currentToken = await readToken();
    if (currentToken != null && !JwtPayload.isImpersonation(currentToken)) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_adminTokenKey, currentToken);
    }
    await saveToken(impersonationToken);
  }

  Future<bool> exitImpersonation() async {
    final adminToken = await readAdminToken();
    if (adminToken == null) return false;
    await saveToken(adminToken);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_adminTokenKey);
    return true;
  }

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_adminTokenKey);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenStore {
  static const _tokenKey = 'user_access_token';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  Future<void> saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}

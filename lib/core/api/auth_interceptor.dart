import 'package:dio/dio.dart';

import '../auth/auth_manager.dart';
import '../storage/prefs_service.dart';
import '../utils/jwt_utils.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._prefs);

  final PrefsService _prefs;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final code = response.statusCode ?? 0;
    if (code == 401 || code == 403) {
      final token = _prefs.accessToken;
      if (!JwtUtils.isValidToken(token)) {
        AuthManager.instance.notifySessionExpired();
      }
    }
    handler.next(response);
  }
}

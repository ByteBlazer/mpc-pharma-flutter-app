import '../models/models.dart';
import '../storage/prefs_service.dart';
import '../utils/jwt_utils.dart';

class SessionService {
  SessionService(this._prefs);

  final PrefsService _prefs;

  Future<void> saveLoginSession(OtpVerificationResponse response) async {
    final token = response.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('No access token received');
    }

    final payload = JwtPayload.decode(token);
    await _prefs.saveAccessToken(token);
    await _prefs.saveUserId(payload?.id ?? '');
    await _prefs.saveUserName(payload?.username ?? '');
    await _prefs.savePhoneNumber(payload?.mobile ?? '');
    await _prefs.saveRoles(payload?.roles ?? '');
    if (payload?.locationHeartBeatFrequencyInSeconds != null) {
      await _prefs.saveLocationHeartbeatSeconds(
        payload!.locationHeartBeatFrequencyInSeconds!,
      );
    }
  }

  Future<void> clearSession() async {
    await _prefs.clearSession();
  }

  bool get isLoggedIn => JwtUtils.isValidToken(_prefs.accessToken);
}

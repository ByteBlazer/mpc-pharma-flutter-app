import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import 'prefs_keys.dart';

class PrefsService {
  PrefsService(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PrefsService(prefs);
  }

  String? get accessToken => _prefs.getString(PrefsKeys.userAccessToken);
  String? get userId => _prefs.getString(PrefsKeys.userId);
  String? get userName => _prefs.getString(PrefsKeys.userName);
  String? get phoneNumber => _prefs.getString(PrefsKeys.phoneNumber);
  String? get roles => _prefs.getString(PrefsKeys.roles);
  String? get currentTripId => _prefs.getString(PrefsKeys.currentTripId);

  int get locationHeartbeatSeconds =>
      _prefs.getInt(PrefsKeys.locationHeartbeatSeconds) ??
      AppConfig.defaultLocationHeartbeatSeconds;

  int get lastLocationUpdateTimeMs =>
      _prefs.getInt(PrefsKeys.lastLocationUpdateTimeMs) ?? 0;

  Future<void> saveAccessToken(String token) =>
      _prefs.setString(PrefsKeys.userAccessToken, token);

  Future<void> saveUserId(String value) =>
      _prefs.setString(PrefsKeys.userId, value);

  Future<void> saveUserName(String value) =>
      _prefs.setString(PrefsKeys.userName, value);

  Future<void> savePhoneNumber(String value) =>
      _prefs.setString(PrefsKeys.phoneNumber, value);

  Future<void> saveRoles(String value) =>
      _prefs.setString(PrefsKeys.roles, value);

  Future<void> saveLocationHeartbeatSeconds(int value) =>
      _prefs.setInt(PrefsKeys.locationHeartbeatSeconds, value);

  Future<void> saveCurrentTripId(String? value) {
    if (value == null || value.isEmpty) {
      return _prefs.remove(PrefsKeys.currentTripId);
    }
    return _prefs.setString(PrefsKeys.currentTripId, value);
  }

  Future<void> saveLastLocationUpdateTimeMs(int value) =>
      _prefs.setInt(PrefsKeys.lastLocationUpdateTimeMs, value);

  Future<void> clearSession() async {
    await _prefs.remove(PrefsKeys.userAccessToken);
    await _prefs.remove(PrefsKeys.currentTripId);
  }

  bool get tripDashboardGuidanceSeen =>
      _prefs.getBool(PrefsKeys.tripDashboardGuidanceSeen) ?? false;

  Future<void> setTripDashboardGuidanceSeen(bool value) =>
      _prefs.setBool(PrefsKeys.tripDashboardGuidanceSeen, value);

  Set<UserType> get userTypes {
    final raw = roles;
    if (raw == null || raw.isEmpty) return {};
    return raw
        .split(',')
        .map((r) => UserType.fromApiValue(r.trim()))
        .whereType<UserType>()
        .toSet();
  }
}

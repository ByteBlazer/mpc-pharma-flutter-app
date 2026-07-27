import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_token_store.dart';
import '../app_environment.dart';
import '../auth/jwt_payload.dart';
import '../utils/platform_device.dart';

const _prefsHeartbeatIntervalKey = 'trip_heartbeat_interval_seconds';
const _prefsHeartbeatBaseUrlKey = 'trip_heartbeat_api_base_url';
const _prefsHeartbeatActiveKey = 'trip_heartbeat_active';

/// Posts driver location while a trip is STARTED (never during impersonation).
class TripHeartbeatService {
  TripHeartbeatService._();
  static final TripHeartbeatService instance = TripHeartbeatService._();

  Timer? _timer;
  bool _fgStarted = false;
  bool get isRunning => _timer != null || _fgStarted;

  static void initForegroundTask() {
    if (kIsWeb || !isMobileNativePlatform) return;
    FlutterForegroundTask.initCommunicationPort();
  }

  Future<void> start({required int intervalSeconds}) async {
    if (!isMobileNativePlatform) return;
    if (await JwtPayload.currentIsImpersonation()) return;

    final seconds = intervalSeconds > 0 ? intervalSeconds : 60;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsHeartbeatIntervalKey, seconds);
    await prefs.setString(_prefsHeartbeatBaseUrlKey, AppEnvironment.apiBaseUrl);
    await prefs.setBool(_prefsHeartbeatActiveKey, true);

    await stop(clearPrefs: false);

    await _ensureForegroundService(seconds);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: seconds), (_) {
      unawaited(pingOnce());
    });
    await pingOnce();
  }

  Future<void> stop({bool clearPrefs = true}) async {
    _timer?.cancel();
    _timer = null;
    if (_fgStarted) {
      try {
        await FlutterForegroundTask.stopService();
      } catch (_) {}
      _fgStarted = false;
    }
    if (clearPrefs) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsHeartbeatActiveKey, false);
    }
  }

  /// One-shot register. Skipped in simulation / non-mobile.
  Future<bool> pingOnce() async {
    if (!isMobileNativePlatform) return false;
    if (await JwtPayload.currentIsImpersonation()) return false;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return _postLocation(
        latitude: position.latitude.toString(),
        longitude: position.longitude.toString(),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _postLocation({
    required String latitude,
    required String longitude,
  }) async {
    try {
      final token = await AuthTokenStore().readToken();
      if (token == null || token.isEmpty) return false;
      if (JwtPayload.isImpersonation(token)) return false;

      final uri = locationRegisterUri(AppEnvironment.apiBaseUrl);
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': token.toLowerCase().startsWith('bearer ')
                  ? token
                  : 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': latitude,
              'longitude': longitude,
            }),
          )
          .timeout(const Duration(seconds: 25));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<void> _ensureForegroundService(int intervalSeconds) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'mpc_pharma_trip_tracking',
        channelName: 'MPC Pharma live trip tracking',
        channelDescription:
            'Shows while MPC Pharma shares your location during an active trip.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          intervalSeconds * 1000,
        ),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    final running = await FlutterForegroundTask.isRunningService;
    if (running) {
      await FlutterForegroundTask.restartService();
    } else {
      await FlutterForegroundTask.startService(
        serviceId: 1101,
        serviceTypes: const [ForegroundServiceTypes.location],
        notificationTitle: 'MPC Pharma live tracking',
        notificationText:
            'Sharing your location with dispatch while your trip is active.',
        callback: startTripHeartbeatCallback,
      );
    }
    _fgStarted = true;
  }

  /// After login: if permissions already OK and a STARTED trip exists, start.
  Future<void> reattachIfNeeded({
    required Future<bool> Function() hasStartedTrip,
  }) async {
    if (!isMobileNativePlatform) return;
    if (await JwtPayload.currentIsImpersonation()) {
      await stop();
      return;
    }

    final hasStarted = await hasStartedTrip();
    if (!hasStarted) {
      await stop();
      return;
    }
    final interval =
        await JwtPayload.currentLocationHeartbeatFrequencySeconds();
    await start(intervalSeconds: interval);
  }
}

@pragma('vm:entry-point')
void startTripHeartbeatCallback() {
  FlutterForegroundTask.setTaskHandler(_TripHeartbeatTaskHandler());
}

class _TripHeartbeatTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_pingFromIsolate());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _pingFromIsolate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsHeartbeatActiveKey) != true) return;

      final token = prefs.getString('user_access_token');
      if (token == null || token.isEmpty) return;
      try {
        final parts = token.split('.');
        if (parts.length >= 2) {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final json = jsonDecode(payload);
          if (json is Map && json['impersonation'] == true) return;
        }
      } catch (_) {}

      final baseUrl = prefs.getString(_prefsHeartbeatBaseUrlKey) ?? '';
      if (baseUrl.isEmpty) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final uri = locationRegisterUri(baseUrl);
      await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': token.toLowerCase().startsWith('bearer ')
                  ? token
                  : 'Bearer $token',
            },
            body: jsonEncode({
              'latitude': position.latitude.toString(),
              'longitude': position.longitude.toString(),
            }),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {}
  }
}

Uri locationRegisterUri(String baseUrl) {
  final base = Uri.parse(baseUrl);
  final basePath = base.path.endsWith('/')
      ? base.path.substring(0, base.path.length - 1)
      : base.path;
  return base.replace(path: '$basePath/location/register');
}

import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../../config/app_config.dart';
import '../../config/app_constants.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../storage/prefs_service.dart';
import '../utils/jwt_utils.dart';
import '../utils/platform_utils.dart';
import 'location_tracking_background.dart';

class LocationTrackingService {
  LocationTrackingService(this._prefs, this._api);

  final PrefsService _prefs;
  final ApiClient _api;

  static const notificationChannelId = 'location_ping_channel';

  static Future<void> initialize() async {
    if (!supportsNativeLocationService) return;

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: locationTrackingOnStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Active Trip: Sharing Location',
        initialNotificationContent:
            'Your location is being sent to the server for order tracking.',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: locationTrackingOnStart,
        onBackground: locationTrackingIosBackground,
      ),
    );
  }

  static Future<bool> _hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (!supportsNativeLocationService) return;
    if (!await _hasLocationPermission()) return;

    final service = FlutterBackgroundService();
    final isRunning = await service.isRunning();
    if (!isRunning) {
      await service.startService();
    }
  }

  Future<void> stop() async {
    if (!supportsNativeLocationService) return;

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  Future<bool> isRunning() async {
    if (!supportsNativeLocationService) return false;
    return FlutterBackgroundService().isRunning();
  }

  Future<void> sendLocationIfNeeded() async {
    final token = _prefs.accessToken;
    if (!JwtUtils.isValidToken(token)) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _prefs.lastLocationUpdateTimeMs;
    if (now - last < AppConfig.locationThrottleMs) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _api.sendLocation(
        LocationData(
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
        ),
      );
      await _prefs.saveLastLocationUpdateTimeMs(now);
    } catch (_) {}
  }

  Future<void> syncWithTrips(List<ScheduledTrip>? trips) async {
    final hasActiveTrip = trips?.any(
          (t) => t.status == AppConstants.tripStatusStarted,
        ) ??
        false;
    if (hasActiveTrip && await _hasLocationPermission()) {
      await start();
    } else {
      await stop();
    }
  }
}

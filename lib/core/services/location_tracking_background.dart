import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../storage/prefs_service.dart';
import '../utils/jwt_utils.dart';

/// Top-level entry points for [flutter_background_service] (required for AOT).

@pragma('vm:entry-point')
Future<bool> locationTrackingIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void locationTrackingOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  Timer? timer;
  final prefs = await PrefsService.create();
  final api = ApiClient(prefs);

  Future<void> ping() async {
    final token = prefs.accessToken;
    if (!JwtUtils.isValidToken(token)) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await api.sendLocation(
        LocationData(
          latitude: position.latitude.toString(),
          longitude: position.longitude.toString(),
        ),
      );
      await prefs.saveLastLocationUpdateTimeMs(
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  service.on('stopService').listen((_) {
    timer?.cancel();
    service.stopSelf();
  });

  final intervalSeconds = prefs.locationHeartbeatSeconds;
  timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) => ping());
  await ping();
}

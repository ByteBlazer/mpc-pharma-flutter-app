import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of the Start/Resume hard permission gate.
class TripLocationGateResult {
  const TripLocationGateResult._({
    required this.ok,
    this.message = '',
    this.openSettings = false,
  });

  const TripLocationGateResult.success() : this._(ok: true);

  const TripLocationGateResult.blocked({
    required String message,
    bool openSettings = false,
  }) : this._(ok: false, message: message, openSettings: openSettings);

  final bool ok;
  final String message;
  final bool openSettings;
}

/// GPS on + foreground location + always location + notifications (Android 13+).
class TripLocationGate {
  static Future<TripLocationGateResult> ensureReady({
    required Future<bool?> Function(String title, String message) confirmSettings,
  }) async {
    if (kIsWeb) {
      return const TripLocationGateResult.blocked(
        message: 'Start and Resume are only available on a mobile device.',
      );
    }

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      final open = await confirmSettings(
        'Location is turned off',
        'MPC Pharma needs device location turned on to start or resume a trip '
            'so your position can be shared with dispatch.',
      );
      if (open == true) await Geolocator.openLocationSettings();
      return const TripLocationGateResult.blocked(
        message: 'Turn on location/GPS to start or resume the trip.',
      );
    }

    var whenInUse = await Permission.locationWhenInUse.status;
    if (!whenInUse.isGranted) {
      whenInUse = await Permission.locationWhenInUse.request();
    }
    if (!whenInUse.isGranted) {
      final permanent = whenInUse.isPermanentlyDenied;
      if (permanent) {
        final open = await confirmSettings(
          'Location permission needed',
          'MPC Pharma needs your location while you use the app during an '
              'active delivery trip so your position can be shared with dispatch. '
              'Open app settings to allow location.',
        );
        if (open == true) await openAppSettings();
      }
      return TripLocationGateResult.blocked(
        message:
            'MPC Pharma needs your location while you use the app during an '
            'active delivery trip so your position can be shared with dispatch.',
        openSettings: permanent,
      );
    }

    var always = await Permission.locationAlways.status;
    if (!always.isGranted) {
      always = await Permission.locationAlways.request();
    }
    if (!always.isGranted) {
      final permanent = always.isPermanentlyDenied;
      if (permanent) {
        final open = await confirmSettings(
          'Allow location all the time',
          'To keep sharing your location when the app is closed or not in use, '
              'allow location all the time in app settings.',
        );
        if (open == true) await openAppSettings();
      }
      return const TripLocationGateResult.blocked(
        message:
            'To keep sharing your location when the app is closed or not in use, '
            'allow location all the time.',
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      var notification = await Permission.notification.status;
      if (!notification.isGranted) {
        notification = await Permission.notification.request();
      }
      if (!notification.isGranted) {
        final permanent = notification.isPermanentlyDenied;
        if (permanent) {
          final open = await confirmSettings(
            'Notification permission needed',
            'MPC Pharma needs notification access to show that live trip '
                'tracking is running while you are on a trip. Open app settings '
                'to allow notifications.',
          );
          if (open == true) await openAppSettings();
        }
        return const TripLocationGateResult.blocked(
          message:
              'MPC Pharma needs notification access to show that live trip '
              'tracking is running while you are on a trip.',
        );
      }
    }

    return const TripLocationGateResult.success();
  }

  /// True when all gate permissions are already granted (no prompts).
  static Future<bool> areAllGranted() async {
    if (kIsWeb) return false;
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    if (!await Permission.locationWhenInUse.isGranted) return false;
    if (!await Permission.locationAlways.isGranted) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      if (!await Permission.notification.isGranted) return false;
    }
    return true;
  }
}

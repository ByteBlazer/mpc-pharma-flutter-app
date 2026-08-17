import 'package:flutter/services.dart';

/// Scan feedback via Flutter haptics (`HapticFeedback.vibrate`).
///
/// Motorola / Android 15 does not fire the `vibration` plugin motor, but
/// does play this haptic. Repeated pulses make a single feeble tick feel
/// closer to the old app's 100ms / 500ms buzz.
abstract final class AppVibrator {
  static Future<void> vibrate({int durationMs = 100}) async {
    if (durationMs <= 100) {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
      return;
    }

    final end = DateTime.now().add(Duration(milliseconds: durationMs));
    while (true) {
      await HapticFeedback.vibrate();
      await HapticFeedback.heavyImpact();
      if (DateTime.now().isAfter(end)) return;
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }
}

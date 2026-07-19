import 'package:flutter/foundation.dart';

/// True for Android/iOS app builds (not web/desktop).
bool get isMobileNativePlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

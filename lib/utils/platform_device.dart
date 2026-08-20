import 'package:flutter/foundation.dart';

import 'platform_device_mobile_detect_stub.dart'
    if (dart.library.html) 'platform_device_mobile_detect_web.dart';

/// True for Android/iOS app builds (not web/desktop).
bool get isMobileNativePlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

/// True for native Android/iOS apps and mobile browsers on those platforms.
bool get isMobileDevice =>
    isMobileNativePlatform || (kIsWeb && isMobileWebBrowser);

/// Help / support entry points: iOS app and web only (not Android app).
bool get showHelpSupportOnPlatform {
  if (kIsWeb) return true;
  return defaultTargetPlatform == TargetPlatform.iOS;
}

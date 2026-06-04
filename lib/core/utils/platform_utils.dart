import 'package:flutter/foundation.dart';

/// Whether native mobile-only features (background location service, etc.) apply.
bool get supportsNativeLocationService =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

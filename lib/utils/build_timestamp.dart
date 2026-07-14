import 'package:flutter/services.dart';

/// Asset path for the root [BUILD_TIMESTAMP] file (declared in pubspec.yaml).
const buildTimestampAssetPath = 'BUILD_TIMESTAMP';

/// Reads the build timestamp written at project root / during CI.
Future<String> loadBuildTimestamp() async {
  try {
    final raw = await rootBundle.loadString(buildTimestampAssetPath);
    final value = raw.trim();
    if (value.isEmpty) return 'unknown';
    return value;
  } catch (_) {
    return 'unknown';
  }
}

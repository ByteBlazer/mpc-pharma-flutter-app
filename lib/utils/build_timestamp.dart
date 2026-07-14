import 'package:flutter/services.dart';

import '../api/api_client.dart';

/// Asset path for the root [BUILD_TIMESTAMP] file (declared in pubspec.yaml).
const buildTimestampAssetPath = 'BUILD_TIMESTAMP';

const _istOffset = Duration(hours: 5, minutes: 30);

/// Reads the UI build timestamp written at project root / during CI.
Future<String> loadUiBuildTimestamp() async {
  try {
    final raw = await rootBundle.loadString(buildTimestampAssetPath);
    final value = raw.trim();
    if (value.isEmpty) return 'unknown';
    return value;
  } catch (_) {
    return 'unknown';
  }
}

/// Resolves the stamp to show on Home: later of UI file vs API epoch, formatted
/// in IST. If the API call fails or returns nothing, the UI stamp is used.
Future<String> loadBuildTimestamp({ApiClient? apiClient}) async {
  final uiStamp = await loadUiBuildTimestamp();
  final uiTime = parseBuildTimestamp(uiStamp);

  DateTime? apiTime;
  if (apiClient != null) {
    try {
      final epochSeconds = await apiClient.getBuildTimestampEpoch();
      apiTime = DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      );
    } catch (_) {
      // API unavailable — UI stamp wins.
    }
  }

  if (apiTime == null) return uiStamp;
  if (uiTime == null || apiTime.isAfter(uiTime)) {
    return formatBuildTimestampIst(apiTime);
  }
  return uiStamp;
}

/// Parses UI stamp strings such as `14-07-2026 12:15 PM IST` or `01-01-2026`.
DateTime? parseBuildTimestamp(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.toLowerCase() == 'unknown') return null;

  final withTime = RegExp(
    r'^(\d{2})-(\d{2})-(\d{4})\s+(\d{1,2}):(\d{2})\s+(AM|PM)\s+IST$',
    caseSensitive: false,
  ).firstMatch(value);
  if (withTime != null) {
    final day = int.parse(withTime.group(1)!);
    final month = int.parse(withTime.group(2)!);
    final year = int.parse(withTime.group(3)!);
    var hour = int.parse(withTime.group(4)!);
    final minute = int.parse(withTime.group(5)!);
    final isPm = withTime.group(6)!.toUpperCase() == 'PM';
    if (isPm) {
      if (hour != 12) hour += 12;
    } else if (hour == 12) {
      hour = 0;
    }
    return DateTime.utc(year, month, day, hour, minute).subtract(_istOffset);
  }

  final dateOnly = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(value);
  if (dateOnly != null) {
    final day = int.parse(dateOnly.group(1)!);
    final month = int.parse(dateOnly.group(2)!);
    final year = int.parse(dateOnly.group(3)!);
    return DateTime.utc(year, month, day).subtract(_istOffset);
  }

  return null;
}

/// Formats like CI: `14-07-2026 12:15 PM IST` (Asia/Kolkata).
String formatBuildTimestampIst(DateTime instant) {
  final ist = instant.toUtc().add(_istOffset);
  final day = ist.day.toString().padLeft(2, '0');
  final month = ist.month.toString().padLeft(2, '0');
  final year = ist.year.toString();
  final minute = ist.minute.toString().padLeft(2, '0');
  final period = ist.hour >= 12 ? 'PM' : 'AM';
  var hour12 = ist.hour % 12;
  if (hour12 == 0) hour12 = 12;
  final hour = hour12.toString().padLeft(2, '0');
  return '$day-$month-$year $hour:$minute $period IST';
}

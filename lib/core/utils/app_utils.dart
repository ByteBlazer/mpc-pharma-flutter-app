import 'dart:math';

import 'package:intl/intl.dart';

class AppUtils {
  AppUtils._();

  static String convertIso8601ToIst(String iso8601) {
    try {
      final utc = DateTime.parse(iso8601).toUtc();
      final ist = utc.add(const Duration(hours: 5, minutes: 30));
      return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
    } catch (_) {
      return iso8601;
    }
  }

  static double haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}

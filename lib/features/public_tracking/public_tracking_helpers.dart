import 'package:flutter/material.dart';

import '../trip_dashboard/trip_dashboard_helpers.dart';

class PublicTrackingStatusDisplay {
  const PublicTrackingStatusDisplay({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

PublicTrackingStatusDisplay publicTrackingStatusDisplay(String? status) {
  switch (status?.toUpperCase()) {
    case 'DELIVERED':
      return const PublicTrackingStatusDisplay(
        label: 'Delivered',
        color: Color(0xFF4CAF50),
        icon: Icons.check_circle,
      );
    case 'UNDELIVERED':
      return const PublicTrackingStatusDisplay(
        label: 'DELIVERY FAILED',
        color: Color(0xFFF44336),
        icon: Icons.cancel,
      );
    case 'ON_TRIP':
      return PublicTrackingStatusDisplay(
        label: 'On Trip',
        color: ThemeData.light().colorScheme.primary,
        icon: Icons.local_shipping,
      );
    case 'AT_TRANSIT_HUB':
      return const PublicTrackingStatusDisplay(
        label: 'At Transit Hub',
        color: Color(0xFFFF9800),
        icon: Icons.local_shipping,
      );
    case 'TRIP_SCHEDULED':
      return const PublicTrackingStatusDisplay(
        label: 'Trip Scheduled',
        color: Color(0xFF2196F3),
        icon: Icons.schedule,
      );
    case 'READY_FOR_DISPATCH':
      return const PublicTrackingStatusDisplay(
        label: 'Ready for Dispatch',
        color: Color(0xFF666666),
        icon: Icons.schedule,
      );
    default:
      return PublicTrackingStatusDisplay(
        label: status?.trim().isNotEmpty == true ? status!.trim() : 'Unknown',
        color: const Color(0xFF666666),
        icon: Icons.schedule,
      );
  }
}

String formatPublicTrackingEta(int etaMinutes, String status) {
  if (etaMinutes == -1) {
    return status.toUpperCase() == 'ON_TRIP' ? 'Updating Soon' : 'Unavailable';
  }
  if (etaMinutes < 1) return 'Less than a minute';
  if (etaMinutes < 60) {
    return etaMinutes.round() == 1
        ? '1 minute'
        : '${etaMinutes.round()} minutes';
  }
  final hours = etaMinutes ~/ 60;
  final minutes = etaMinutes.round() % 60;
  return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
}

String formatPublicTrackingInstant(DateTime? instant) {
  if (instant == null) return '';
  final formatted = formatSmartTimestamp(instant);
  if (formatted.startsWith('Today ')) {
    return 'Today ${formatted.substring(6)}';
  }
  return formatted;
}

String formatPublicTrackingDriverUpdate(DateTime? instant) {
  if (instant == null) return '';
  return formatSmartTimestamp(instant);
}

String publicTrackingMapMessage({
  required String status,
  required bool hasMap,
}) {
  if (hasMap) return '';
  switch (status.toUpperCase()) {
    case 'DELIVERED':
      return 'Delivery has been completed. Location tracking is no longer available.';
    case 'UNDELIVERED':
      return 'Delivery could not be completed. Location tracking is no longer available.';
    default:
      return 'Location tracking is not available for this delivery at the moment.';
  }
}

String formatPublicTrackingAmount(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return formatInrAmount(trimmed);
}

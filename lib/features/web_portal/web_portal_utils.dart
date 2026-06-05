import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WebPortalUtils {
  WebPortalUtils._();

  /// React Delivery Report `formatDateTime` (en-IN, date + time, lowercase am/pm).
  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final local = dt.toLocal();
    final date = DateFormat('d MMM yyyy').format(local);
    final time = DateFormat('h:mm a').format(local).toLowerCase();
    return '$date, $time';
  }

  /// React `new Date(createdAt).toLocaleString()` (en-US).
  static String formatUserCreatedAt(DateTime dt) =>
      DateFormat.yMd('en_US').add_jms().format(dt.toLocal());

  static String formatDateString(String? value) {
    if (value == null || value.isEmpty) return '-';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    return DateFormat('dd MMM yyyy').format(dt.toLocal());
  }

  static String formatTripTimestamp(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final time = DateFormat('hh:mm a').format(local);

    if (date == today) return 'Today $time';
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == yesterday) return 'Yesterday $time';
    return '${DateFormat('MMM d').format(local)} $time';
  }

  static String formatFileSize(int bytes) =>
      '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';

  static ({String environment, String type}) parseBackupFilename(
    String filename,
  ) {
    try {
      final parts = filename.split('-on-');
      final prefix = parts.first.replaceFirst('pharmatracker-', '');
      final prefixParts = prefix.split('-');
      return (
        environment: prefixParts.isNotEmpty ? prefixParts.first : 'unknown',
        type: prefixParts.length > 1 ? prefixParts[1] : 'Unknown',
      );
    } catch (_) {
      return (environment: 'unknown', type: 'Unknown');
    }
  }

  static String docStatusLabel(String status) {
    if (status == 'UNDELIVERED') return 'DELIVERY FAILED';
    return status;
  }

  /// React TripDashboard `formatStatusWithTimestamp` (en-IN, lowercase am/pm).
  static String formatDeliveryStatusTimestamp(
    String status,
    DateTime? deliveredAt,
  ) {
    if (deliveredAt == null) {
      return docStatusLabel(status);
    }

    final local = deliveredAt.toLocal();
    final now = DateTime.now();
    final timeStr =
        DateFormat('h:mm a', 'en_IN').format(local).toLowerCase();
    final label = status == 'UNDELIVERED'
        ? 'DELIVERY FAILED'
        : status == 'DELIVERED'
            ? 'DELIVERED'
            : docStatusLabel(status);

    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (isToday) {
      return '$label at $timeStr today';
    }

    final dateStr = DateFormat('d MMM', 'en_IN').format(local);
    return '$label at $timeStr on $dateStr';
  }

  static Color docStatusColor(String status) {
    return switch (status) {
      'DELIVERED' => const Color(0xFF4CAF50),
      'UNDELIVERED' => const Color(0xFFF44336),
      'ON_TRIP' => const Color(0xFF2196F3),
      'AT_TRANSIT_HUB' => const Color(0xFFFF9800),
      _ => const Color(0xFF666666),
    };
  }
}

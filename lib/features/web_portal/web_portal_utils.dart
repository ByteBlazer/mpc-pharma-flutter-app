import 'package:intl/intl.dart';

class WebPortalUtils {
  WebPortalUtils._();

  static final _ist = DateFormat('dd MMM yyyy, hh:mm a');

  static String formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return _ist.format(dt.toLocal());
  }

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
}

typedef JsonMap = Map<String, dynamic>;

class BackupFile {
  const BackupFile({
    required this.filename,
    required this.lastModified,
    required this.size,
  });

  factory BackupFile.fromJson(JsonMap json) {
    return BackupFile(
      filename: _string(json['filename']),
      lastModified: DateTime.tryParse(_string(json['lastModified'])),
      size: _int(json['size']),
    );
  }

  final String filename;
  final DateTime? lastModified;
  final int size;

  /// Parsed from filename: staging / production / unknown.
  String get environment {
    final parts = _prefixParts;
    if (parts.length >= 2) return parts[0];
    return 'unknown';
  }

  /// Parsed from filename: Auto / Manual / Unknown.
  String get backupType {
    final parts = _prefixParts;
    if (parts.length >= 2) return parts[1];
    return 'Unknown';
  }

  bool get isProduction =>
      environment.toLowerCase() == 'production' ||
      environment.toLowerCase() == 'prod';

  String get sizeLabel {
    if (size <= 0) return '0 MB';
    final mb = size / (1024 * 1024);
    if (mb < 0.1) {
      final kb = size / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Prefix before `-on-`, after product name (pharmatracker / mpc-pharma).
  List<String> get _prefixParts {
    final name = filename.trim();
    if (name.isEmpty) return const [];
    final withoutExt = name.toLowerCase().endsWith('.dump')
        ? name.substring(0, name.length - 5)
        : name;
    final onIndex = withoutExt.indexOf('-on-');
    final prefix = onIndex >= 0
        ? withoutExt.substring(0, onIndex)
        : withoutExt;
    final segments = prefix.split('-');
    // pharmatracker-{env}-{type} or mpc-pharma-{env}-{type}
    if (segments.length >= 4 &&
        segments[0].toLowerCase() == 'mpc' &&
        segments[1].toLowerCase() == 'pharma') {
      return [segments[2], segments[3]];
    }
    if (segments.length >= 3) {
      return [segments[1], segments[2]];
    }
    return const [];
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CreateBackupResult {
  const CreateBackupResult({
    required this.success,
    required this.message,
    required this.filename,
  });

  factory CreateBackupResult.fromJson(JsonMap json) {
    return CreateBackupResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
    );
  }

  final bool success;
  final String message;
  final String filename;
}

class RestoreBackupResult {
  const RestoreBackupResult({
    required this.success,
    required this.message,
  });

  factory RestoreBackupResult.fromJson(JsonMap json) {
    return RestoreBackupResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
    );
  }

  final bool success;
  final String message;
}

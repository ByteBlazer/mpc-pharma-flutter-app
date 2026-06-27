import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class AppEnvironment {
  static const local = 'local';
  static const staging = 'staging';
  static const production = 'production';
  static const selected = String.fromEnvironment(
    'APP_ENV',
    defaultValue: local,
  );

  static String? _loadedName;
  static String? _loadedApiBaseUrl;
  static String? _loadedAppCode;

  static Future<void> load() async {
    await dotenv.load(fileName: _fileNameForSelectedEnvironment());
    _loadedName = dotenv.env['APP_ENV'];
    _loadedApiBaseUrl = dotenv.env['API_BASE_URL'];
    _loadedAppCode = dotenv.env['APP_CODE'];
  }

  static String get name => _loadedName ?? _selectedOrLocal();

  static String get apiBaseUrl =>
      _loadedApiBaseUrl ?? 'REST API URL not configured yet';

  static String get appCode => _loadedAppCode ?? '';

  static String _fileNameForSelectedEnvironment() {
    switch (_selectedOrLocal()) {
      case staging:
        return 'env/staging.env';
      case production:
        return 'env/production.env';
      case local:
      default:
        return 'env/local.env';
    }
  }

  static String _selectedOrLocal() {
    switch (selected) {
      case staging:
      case production:
      case local:
        return selected;
      default:
        return local;
    }
  }
}

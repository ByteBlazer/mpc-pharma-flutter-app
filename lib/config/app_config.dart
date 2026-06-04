import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String stagingBaseUrl = 'https://staging.pharmatracker.in/api/';
  static const String productionBaseUrl = 'https://pharmatracker.in/api/';

  /// Hostnames for the deployed Flutter web app (API stays on pharmatracker.in).
  static const Set<String> productionWebHosts = {
    'mpcpharma.in',
    'www.mpcpharma.in',
  };

  /// Override with: `--dart-define=API_ENV=production`
  static const String apiEnv = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'staging',
  );

  /// Full API base URL override, e.g. local backend:
  /// `--dart-define=API_BASE_URL=http://localhost:3000/api/`
  static const String apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (apiBaseUrlOverride.isNotEmpty) {
      return apiBaseUrlOverride.endsWith('/')
          ? apiBaseUrlOverride
          : '$apiBaseUrlOverride/';
    }

    if (kIsWeb && productionWebHosts.contains(Uri.base.host)) {
      return productionBaseUrl;
    }

    return apiEnv == 'production' ? productionBaseUrl : stagingBaseUrl;
  }

  static const int defaultLocationHeartbeatSeconds = 30;
  static const int locationThrottleMs = 30000;
  static const int requiredConsecutiveScans = 3;
}

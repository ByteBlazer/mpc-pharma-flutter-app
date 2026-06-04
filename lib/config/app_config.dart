class AppConfig {
  AppConfig._();

  static const String stagingBaseUrl = 'https://staging.pharmatracker.in/api/';
  static const String productionBaseUrl = 'https://pharmatracker.in/api/';

  /// Override with: `--dart-define=API_ENV=production`
  static const String apiEnv = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'staging',
  );

  static String get baseUrl =>
      apiEnv == 'production' ? productionBaseUrl : stagingBaseUrl;

  static const int defaultLocationHeartbeatSeconds = 30;
  static const int locationThrottleMs = 30000;
  static const int requiredConsecutiveScans = 3;
}

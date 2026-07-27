typedef JsonMap = Map<String, dynamic>;

/// Public app configuration from the backend.
///
/// **Backend contract** — `GET /api/app-config` (no auth required)
///
/// ```json
/// {
///   "minVersionAndroid": "1.2.0",
///   "minVersionIos": "1.2.0",
///   "updateMessage": "Please update to continue using MPC Pharma.",
///   "androidStoreUrl": "https://play.google.com/store/apps/details?id=com.mpc.pharma.mpc_pharma",
///   "iosStoreUrl": "https://apps.apple.com/app/idXXXXXXXXX"
/// }
/// ```
///
/// Set [minVersionAndroid] / [minVersionIos] only **after** the matching build
/// is available in Play Store / App Store. Empty or omitted minimums disable
/// forced update for that platform.
class AppConfig {
  const AppConfig({
    this.minVersionAndroid,
    this.minVersionIos,
    this.updateMessage,
    this.androidStoreUrl,
    this.iosStoreUrl,
  });

  factory AppConfig.fromJson(JsonMap json) {
    return AppConfig(
      minVersionAndroid: _optionalString(json['minVersionAndroid']),
      minVersionIos: _optionalString(json['minVersionIos']),
      updateMessage: _optionalString(json['updateMessage']),
      androidStoreUrl: _optionalString(json['androidStoreUrl']),
      iosStoreUrl: _optionalString(json['iosStoreUrl']),
    );
  }

  final String? minVersionAndroid;
  final String? minVersionIos;
  final String? updateMessage;
  final String? androidStoreUrl;
  final String? iosStoreUrl;

  String? minimumVersionFor({required bool isAndroid}) {
    return isAndroid ? minVersionAndroid : minVersionIos;
  }

  String? storeUrlFor({required bool isAndroid}) {
    return isAndroid ? androidStoreUrl : iosStoreUrl;
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

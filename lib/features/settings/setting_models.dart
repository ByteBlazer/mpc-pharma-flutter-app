typedef JsonMap = Map<String, dynamic>;

class AppSetting {
  const AppSetting({
    required this.settingName,
    required this.settingValue,
  });

  factory AppSetting.fromJson(JsonMap json) {
    return AppSetting(
      settingName: json['settingName']?.toString() ?? '',
      settingValue: json['settingValue']?.toString() ?? '',
    );
  }

  final String settingName;
  final String settingValue;
}

class UpdateAppSettingResult {
  const UpdateAppSettingResult({
    required this.success,
    required this.message,
    required this.settingName,
    required this.oldValue,
    required this.newValue,
  });

  factory UpdateAppSettingResult.fromJson(JsonMap json) {
    return UpdateAppSettingResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      settingName: json['settingName']?.toString() ?? '',
      oldValue: json['oldValue']?.toString() ?? '',
      newValue: json['newValue']?.toString() ?? '',
    );
  }

  final bool success;
  final String message;
  final String settingName;
  final String oldValue;
  final String newValue;
}

enum MiscSettingInputType {
  boolean,
  intSelect,
  textRequired,
  textOptional,
  semverOptional,
  urlOptional,
}

/// Named app settings exposed in Settings → Miscellaneous.
enum MiscSettingKey {
  locationHeartbeat(
    apiName: 'MINS_BETWEEN_LOCATION_HEARTBEATS',
    title: 'Location Heartbeat',
    helpText:
        'How often drivers send location updates while logged in.',
    fieldLabel: 'Interval',
    inputType: MiscSettingInputType.intSelect,
  ),
  routeScanCoolOff(
    apiName: 'COOL_OFF_SECONDS_BTWN_DIFF_ROUTE_SCANS',
    title: 'Route Scan Cool Off',
    helpText:
        'Minimum wait after scanning one route before scanning another route.',
    fieldLabel: 'Cool off',
    inputType: MiscSettingInputType.intSelect,
  ),
  updateDocStatusToErp(
    apiName: 'UPDATE_DOC_STATUS_TO_ERP',
    title: 'Update Doc Status to ERP',
    helpText:
        'When enabled, document status changes are sent to ERP. Disable for staging or outages.',
    fieldLabel: 'ERP sync',
    inputType: MiscSettingInputType.boolean,
  ),
  sendTrackingSms(
    apiName: 'SEND_TRACKING_SMS',
    title: 'Send Tracking SMS',
    helpText:
        'Send tracking link SMS to customers when a trip starts.',
    fieldLabel: 'Tracking SMS',
    inputType: MiscSettingInputType.boolean,
  ),
  defaultGreeting(
    apiName: 'DEFAULT_GREETING',
    title: 'Default Greeting',
    helpText:
        'Message shown on the public greeting API (informational).',
    fieldLabel: 'Greeting message',
    inputType: MiscSettingInputType.textRequired,
    minLength: 5,
    maxLength: 100,
    placeholder: 'Hello From MPC Pharma',
  ),
  minVersionAndroid(
    apiName: 'MIN_VERSION_ANDROID',
    title: 'Minimum Android Version',
    helpText:
        'Minimum Android app version required. Leave empty to disable forced update.',
    fieldLabel: 'Min version',
    inputType: MiscSettingInputType.semverOptional,
    placeholder: '1.2.0',
  ),
  minVersionIos(
    apiName: 'MIN_VERSION_IOS',
    title: 'Minimum iOS Version',
    helpText:
        'Minimum iOS app version required. Leave empty to disable.',
    fieldLabel: 'Min version',
    inputType: MiscSettingInputType.semverOptional,
    placeholder: '1.2.0',
  ),
  appUpdateMessage(
    apiName: 'APP_UPDATE_MESSAGE',
    title: 'Forced Update Message',
    helpText:
        'Custom message on the forced update screen. Leave empty for app default.',
    fieldLabel: 'Update message',
    inputType: MiscSettingInputType.textOptional,
    maxLength: 100,
  ),
  androidStoreUrl(
    apiName: 'ANDROID_STORE_URL',
    title: 'Android Store URL',
    helpText: 'Play Store link for the MPC Pharma Android app.',
    fieldLabel: 'Play Store URL',
    inputType: MiscSettingInputType.urlOptional,
    placeholder: 'https://play.google.com/store/apps/details?id=...',
  ),
  iosStoreUrl(
    apiName: 'IOS_STORE_URL',
    title: 'iOS Store URL',
    helpText:
        'App Store link (https://apps.apple.com/app/id...). Required when forcing iOS updates.',
    fieldLabel: 'App Store URL',
    inputType: MiscSettingInputType.urlOptional,
    placeholder: 'https://apps.apple.com/app/id...',
  ),
  deliveryCustomerCooldown(
    apiName: 'MIN_MINUTES_BETWEEN_DIFF_CUSTOMER_DELIVERIES',
    title: 'Delivery Customer Cooldown',
    helpText:
        'Minutes drivers must wait before marking a different customer delivered on the same trip. Use 0 to disable.',
    fieldLabel: 'Cooldown',
    inputType: MiscSettingInputType.intSelect,
  );

  const MiscSettingKey({
    required this.apiName,
    required this.title,
    required this.helpText,
    required this.fieldLabel,
    required this.inputType,
    this.minLength,
    this.maxLength,
    this.placeholder,
  });

  final String apiName;
  final String title;
  final String helpText;
  final String fieldLabel;
  final MiscSettingInputType inputType;
  final int? minLength;
  final int? maxLength;
  final String? placeholder;

  bool get isBoolean => inputType == MiscSettingInputType.boolean;

  bool get usesTextField =>
      inputType == MiscSettingInputType.textRequired ||
      inputType == MiscSettingInputType.textOptional ||
      inputType == MiscSettingInputType.semverOptional ||
      inputType == MiscSettingInputType.urlOptional;

  static final _semverPattern = RegExp(r'^\d+\.\d+\.\d+$');

  String? validateValue(String raw) {
    final value = raw.trim();
    switch (inputType) {
      case MiscSettingInputType.boolean:
      case MiscSettingInputType.intSelect:
        return null;
      case MiscSettingInputType.textRequired:
        if (value.length < (minLength ?? 1)) {
          return 'Enter at least ${minLength ?? 1} characters.';
        }
        if (maxLength != null && value.length > maxLength!) {
          return 'Maximum $maxLength characters.';
        }
        return null;
      case MiscSettingInputType.textOptional:
        if (maxLength != null && value.length > maxLength!) {
          return 'Maximum $maxLength characters.';
        }
        return null;
      case MiscSettingInputType.semverOptional:
        if (value.isEmpty) return null;
        if (!_semverPattern.hasMatch(value)) {
          return 'Use format major.minor.patch (e.g. 1.2.0) or leave empty.';
        }
        return null;
      case MiscSettingInputType.urlOptional:
        if (value.isEmpty) return null;
        final uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasScheme ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          return 'Enter a valid http:// or https:// URL, or leave empty.';
        }
        return null;
    }
  }
}

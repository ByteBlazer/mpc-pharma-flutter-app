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

/// Named app settings exposed in Miscellaneous (excludes DEFAULT_GREETING).
enum MiscSettingKey {
  locationHeartbeat(
    apiName: 'MINS_BETWEEN_LOCATION_HEARTBEATS',
    title: 'Location Heartbeat',
    helpText:
        'The frequency at which location updates are sent to the server, from the mobile app.',
    fieldLabel: 'Heartbeat Interval',
  ),
  routeScanCoolOff(
    apiName: 'COOL_OFF_SECONDS_BTWN_DIFF_ROUTE_SCANS',
    title: 'Route Scan Cool Off',
    helpText:
        'The time interval after which scans from a different route is permitted, in the mobile app.',
    fieldLabel: 'Cool Off Period',
  ),
  updateDocStatusToErp(
    apiName: 'UPDATE_DOC_STATUS_TO_ERP',
    title: 'Update Doc Status to ERP',
    helpText:
        'Controls whether document status updates are sent to the ERP system from the mobile app.',
    fieldLabel: 'Enable ERP Updates',
  ),
  sendTrackingSms(
    apiName: 'SEND_TRACKING_SMS',
    title: 'Send Tracking SMS',
    helpText:
        'Controls whether tracking SMS alerts are sent to customers when a document is on trip.',
    fieldLabel: 'Enable SMS Alerts',
  );

  const MiscSettingKey({
    required this.apiName,
    required this.title,
    required this.helpText,
    required this.fieldLabel,
  });

  final String apiName;
  final String title;
  final String helpText;
  final String fieldLabel;

  bool get isBoolean =>
      this == MiscSettingKey.updateDocStatusToErp ||
      this == MiscSettingKey.sendTrackingSms;
}

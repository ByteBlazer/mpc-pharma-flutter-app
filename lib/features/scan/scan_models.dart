import '../../utils/api_message.dart';

typedef JsonMap = Map<String, dynamic>;

class ScanDocResult {
  const ScanDocResult({
    required this.statusCode,
    required this.success,
    required this.message,
    this.docId = '',
  });

  factory ScanDocResult.fromHttp({
    required int statusCode,
    required JsonMap json,
  }) {
    return ScanDocResult(
      statusCode: statusCode,
      success: json['success'] == true,
      message: formatApiMessage(json['message'] ?? json['error'], fallback: ''),
      docId: json['docId']?.toString() ?? '',
    );
  }

  factory ScanDocResult.unreachable() {
    return const ScanDocResult(
      statusCode: 0,
      success: false,
      message: 'Server unreachable. It looks like you are offline',
    );
  }

  final int statusCode;
  final bool success;
  final String message;
  final String docId;

  String get displayMessage =>
      message.isEmpty ? 'Something went wrong. Please try again.' : message;

  /// Green success banner (includes 409 re-scan ack when success is true).
  bool get isUiSuccess => success;

  /// Red error banner.
  bool get isUiHardError =>
      !success && (statusCode == 400 || statusCode == 500);

  /// Yellow warning / soft failure / network.
  bool get isUiSoftError => !success && !isUiHardError;
}

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

  /// Re-scan acknowledgement (409 with success).
  bool get isRescanAck => success && statusCode == 409;

  /// Green success banner (new scan only; re-scan ack uses yellow).
  bool get isUiSuccess => success && !isRescanAck;

  /// Red error banner — all failures (network, validation, conflicts, etc.).
  bool get isUiHardError => !success;

  /// Yellow banner — re-scan acknowledgement only.
  bool get isUiWarning => isRescanAck;
}

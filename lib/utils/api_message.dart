/// Normalizes Nest-style `message` fields (string or string[]) for UI copy.
String formatApiMessage(
  Object? message, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (message == null) return fallback;
  if (message is List) {
    final parts = message
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return fallback;
    return parts.join('\n');
  }
  final text = message.toString().trim();
  return text.isEmpty ? fallback : text;
}

import 'dart:convert';
import 'dart:typed_data';

/// Decodes API signature field (raw base64, optional data-URI prefix).
Uint8List? decodeSignatureBase64(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;

  const dataPrefix = 'data:image/png;base64,';
  if (value.startsWith(dataPrefix)) {
    value = value.substring(dataPrefix.length);
  }

  value = value.replaceAll(RegExp(r'\s'), '');
  if (value.isEmpty) return null;

  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}

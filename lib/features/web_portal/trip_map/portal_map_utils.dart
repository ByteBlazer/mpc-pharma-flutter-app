import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Normalizes API base64 (raw, data-URL, whitespace) for decoding/display.
String? normalizePortalBase64Image(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  var data = value.trim();
  if (data.contains(',')) {
    data = data.split(',').last;
  }
  data = data.replaceAll(RegExp(r'\s'), '');
  return data.isEmpty ? null : data;
}

/// Decodes a base64 image payload from the API (raw base64 or data-URL).
Uint8List? decodePortalBase64Image(String? value) {
  final data = normalizePortalBase64Image(value);
  if (data == null) return null;

  try {
    return base64Decode(data);
  } catch (_) {
    return null;
  }
}

String? portalSignatureDataUri(String? value) {
  final data = normalizePortalBase64Image(value);
  if (data == null) return null;
  return 'data:image/png;base64,$data';
}

bool portalSignatureHasDisplayableImage(String? value) {
  final bytes = decodePortalBase64Image(value);
  return bytes != null && bytes.length > 16;
}

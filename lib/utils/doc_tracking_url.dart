import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../app_environment.dart';

/// Origin for customer `/track` links.
///
/// **Web (deployed):** [Uri.base.origin] — same as legacy `window.location.origin`.
/// App and `/track` share one host (e.g. `https://mpcpharma.in`).
///
/// **Native / mobile:** No browser host — derive from [AppEnvironment.apiBaseUrl]
/// by stripping `/api` (staging API → staging web, prod → prod), matching API guidance
/// without a separate `PUBLIC_WEB_BASE_URL` env var.
String publicWebOrigin() {
  if (kIsWeb) {
    return Uri.base.origin;
  }
  return _originFromApiBaseUrl() ?? Uri.base.origin;
}

String? _originFromApiBaseUrl() {
  final api = Uri.tryParse(AppEnvironment.apiBaseUrl.trim());
  if (api == null || !api.hasScheme) return null;

  var path = api.path;
  if (path.endsWith('/api/')) {
    path = path.substring(0, path.length - 5);
  } else if (path.endsWith('/api')) {
    path = path.substring(0, path.length - 4);
  }

  return api.replace(path: path, query: '', fragment: '').origin;
}

String encodeDocTrackingToken(String docId) {
  return base64Encode(utf8.encode(docId.trim()));
}

String buildDocTrackingUrl(String docId) {
  final token = encodeDocTrackingToken(docId);
  return '${publicWebOrigin()}/track?t=${Uri.encodeComponent(token)}';
}

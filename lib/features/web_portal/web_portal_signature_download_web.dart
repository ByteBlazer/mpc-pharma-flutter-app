import 'package:web/web.dart' as web;

import 'trip_map/portal_map_utils.dart';

/// Triggers a browser download of the signature PNG (React parity).
void downloadSignaturePng(String docId, String base64Signature) {
  final dataUri = portalSignatureDataUri(base64Signature);
  if (dataUri == null) return;

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = dataUri;
  anchor.download =
      'signature_${docId}_${DateTime.now().millisecondsSinceEpoch}.png';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

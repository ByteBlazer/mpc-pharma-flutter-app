import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrlInNewTab(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  if (kIsWeb) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
    return;
  }

  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens coordinates in a maps app on Android/iOS when possible; otherwise
/// falls back to Google Maps in the browser (desktop / when no app handles it).
Future<void> openCoordinatesInMaps({
  required double latitude,
  required double longitude,
}) async {
  final query = '$latitude,$longitude';
  final webUri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  });

  final preferNativeApp =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (preferNativeApp) {
    final nativeUris = <Uri>[
      if (defaultTargetPlatform == TargetPlatform.android) ...[
        Uri.parse('geo:$latitude,$longitude?q=$query'),
        Uri.parse('google.navigation:q=$query'),
      ],
      if (defaultTargetPlatform == TargetPlatform.iOS) ...[
        Uri.parse('comgooglemaps://?q=$query'),
        Uri.parse('maps://?q=$query'),
        Uri.parse('https://maps.apple.com/?ll=$query&q=$query'),
      ],
    ];

    for (final uri in nativeUris) {
      try {
        if (await canLaunchUrl(uri)) {
          final launched = await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (launched) return;
        }
      } catch (_) {
        // Try the next scheme / fall back to web.
      }
    }
  }

  final launched = await launchUrl(
    webUri,
    mode: LaunchMode.externalApplication,
  );
  if (!launched) {
    throw Exception('Could not open maps.');
  }
}

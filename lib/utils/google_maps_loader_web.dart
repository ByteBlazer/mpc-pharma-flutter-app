// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

Completer<void>? _googleMapsScriptCompleter;

Future<void> ensureGoogleMapsLoadedImpl(String apiKey) async {
  final trimmedKey = apiKey.trim();
  if (trimmedKey.isEmpty) {
    throw StateError('Google Maps API key is not configured.');
  }

  if (_googleMapsScriptCompleter != null) {
    return _googleMapsScriptCompleter!.future;
  }

  final existingScript = html.document.querySelector(
    'script[data-mpc-google-maps="true"]',
  );
  if (existingScript != null) {
    return;
  }

  _googleMapsScriptCompleter = Completer<void>();
  final script = html.ScriptElement()
    ..src = 'https://maps.googleapis.com/maps/api/js?key=$trimmedKey'
    ..async = true
    ..defer = true
    ..dataset['mpcGoogleMaps'] = 'true'
    ..onLoad.listen((_) {
      if (!(_googleMapsScriptCompleter?.isCompleted ?? true)) {
        _googleMapsScriptCompleter!.complete();
      }
    })
    ..onError.listen((_) {
      if (!(_googleMapsScriptCompleter?.isCompleted ?? true)) {
        _googleMapsScriptCompleter!.completeError(
          StateError('Failed to load Google Maps.'),
        );
      }
    });

  html.document.head!.append(script);
  return _googleMapsScriptCompleter!.future;
}

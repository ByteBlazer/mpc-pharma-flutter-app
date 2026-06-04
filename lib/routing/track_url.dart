import 'app_routes.dart';

/// Parses public tracking links (`/track?t=...`) from the browser URL.
///
/// Flutter web often passes `/track?t=token` as a single route name, which
/// go_router cannot match. The main app bypasses the router for these URLs.
class TrackUrl {
  TrackUrl._();

  static bool isTrackLaunch(Uri uri) {
    if (uri.path == AppRoutes.track || uri.path.startsWith('${AppRoutes.track}?')) {
      return true;
    }
    if (uri.fragment.startsWith('/track') || uri.fragment.startsWith('track')) {
      return true;
    }
    return false;
  }

  static String? parseToken(Uri uri) {
    if (uri.path == AppRoutes.track || uri.path.startsWith('${AppRoutes.track}?')) {
      return _fromTrackPath(uri.path) ?? uri.queryParameters['t'];
    }

    if (uri.hasQuery && uri.path == AppRoutes.track) {
      return uri.queryParameters['t'];
    }

    if (uri.fragment.isNotEmpty) {
      final fragment = uri.fragment.startsWith('/')
          ? uri.fragment
          : '/${uri.fragment}';
      if (fragment.startsWith(AppRoutes.track)) {
        final parsed = Uri.parse('http://local$fragment');
        return parsed.queryParameters['t'] ?? _fromTrackPath(parsed.path);
      }
    }

    return null;
  }

  static String? _fromTrackPath(String path) {
    const prefix = '${AppRoutes.track}?';
    if (!path.startsWith(prefix)) return null;
    final token = path.substring(prefix.length);
    return token.isEmpty ? null : token;
  }
}

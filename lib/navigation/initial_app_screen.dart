import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/help/help_support_screen.dart';
import '../features/public_tracking/public_tracking_screen.dart';

String _normalizedWebPath() {
  var path = Uri.base.path;
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return path;
}

bool get isPublicTrackingLaunch {
  if (!kIsWeb) return false;
  final path = _normalizedWebPath();
  return path == '/track' || path.endsWith('/track');
}

/// Public Help / Contact us page (`/help` or `/contact`) — web only, no auth.
bool get isPublicHelpLaunch {
  if (!kIsWeb) return false;
  final path = _normalizedWebPath();
  return path == '/help' ||
      path.endsWith('/help') ||
      path == '/contact' ||
      path.endsWith('/contact');
}

String? get publicTrackingToken {
  final token = Uri.base.queryParameters['t'];
  if (token == null || token.trim().isEmpty) return null;
  return token;
}

Widget buildInitialAppScreen() {
  if (isPublicTrackingLaunch) {
    return PublicTrackingScreen(token: publicTrackingToken);
  }
  if (isPublicHelpLaunch) {
    return const _PublicHelpLaunchScreen();
  }
  return const LoginScreen();
}

/// Root host for `/help` so AppBar back can replace into [LoginScreen].
class _PublicHelpLaunchScreen extends StatelessWidget {
  const _PublicHelpLaunchScreen();

  @override
  Widget build(BuildContext context) {
    return HelpSupportScreen(
      onLeaveWhenRoot: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        );
      },
    );
  }
}

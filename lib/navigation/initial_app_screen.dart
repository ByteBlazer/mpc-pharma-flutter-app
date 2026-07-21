import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/public_tracking/public_tracking_screen.dart';

bool get isPublicTrackingLaunch {
  if (!kIsWeb) return false;
  var path = Uri.base.path;
  if (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  return path == '/track' || path.endsWith('/track');
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
  return const LoginScreen();
}

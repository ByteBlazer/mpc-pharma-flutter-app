import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'features/web_portal/web_portal_theme.dart';
import 'features/public_tracking/public_tracking_screen.dart';

/// Lightweight app shell for `/track?t=...` — no go_router, no auth splash.
class TrackApp extends ConsumerWidget {
  const TrackApp({super.key, required this.token});

  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);

    return MaterialApp(
      title: 'Delivery Tracking',
      debugShowCheckedModeBanner: false,
      theme: WebPortalTheme.light(),
      home: prefsAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          body: Center(child: Text('Failed to start: $e')),
        ),
        data: (_) => PublicTrackingScreen(token: token),
      ),
    );
  }
}

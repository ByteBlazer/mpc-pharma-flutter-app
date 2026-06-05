import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/providers.dart';
import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

class MpcPharmaApp extends ConsumerWidget {
  const MpcPharmaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final router = ref.watch(routerProvider);

    // Always use MaterialApp.router so the browser URL is handled by GoRouter
    // from the first frame (avoids "Could not navigate to initial route" on
    // hot restart when the hash is e.g. /workflow/web/base-locations).
    return AppRouterListener(
      child: MaterialApp.router(
        title: 'MPC Pharma',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) {
          if (prefs.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (prefs.hasError) {
            return Scaffold(
              body: Center(child: Text('Failed to init: ${prefs.error}')),
            );
          }
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}

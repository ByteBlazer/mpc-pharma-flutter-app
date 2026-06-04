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

    if (prefs.isLoading) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (prefs.hasError) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(child: Text('Failed to init: ${prefs.error}')),
        ),
      );
    }

    final router = ref.watch(routerProvider);

    return AppRouterListener(
      child: MaterialApp.router(
        title: 'MPC Pharma',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        routerConfig: router,
      ),
    );
  }
}

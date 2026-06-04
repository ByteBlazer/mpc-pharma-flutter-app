import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/services/session_service.dart';
import '../../core/storage/prefs_service.dart';
import '../../core/utils/jwt_utils.dart';
import '../../routing/app_routes.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final prefs = await ref.read(prefsProvider.future);
    final session = SessionService(prefs);
    if (session.isLoggedIn) {
      _storePayload(prefs);
      ref.read(lastLoginTimeProvider.notifier).state = DateTime.now();
      if (mounted) context.go(AppRoutes.home);
    } else {
      ref.read(lastLoginTimeProvider.notifier).state = null;
      final phone = prefs.phoneNumber;
      if (mounted) {
        context.go(
          '${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}',
        );
      }
    }
  }

  void _storePayload(PrefsService prefs) {
    final token = prefs.accessToken;
    if (token == null) return;
    final payload = JwtPayload.decode(token);
    if (payload == null) return;
    prefs.saveUserId(payload.id ?? '');
    prefs.saveUserName(payload.username ?? '');
    prefs.savePhoneNumber(payload.mobile ?? '');
    prefs.saveRoles(payload.roles ?? '');
    if (payload.locationHeartBeatFrequencyInSeconds != null) {
      prefs.saveLocationHeartbeatSeconds(
        payload.locationHeartBeatFrequencyInSeconds!,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final width = MediaQuery.sizeOf(context).width;
          final offset = -width * 0.25 + (_controller.value * width * 1.5);
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              Transform.translate(
                offset: Offset(offset, 0),
                child: Icon(
                  Icons.local_shipping,
                  size: width * 0.35,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

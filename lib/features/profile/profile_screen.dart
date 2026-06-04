import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(prefsProvider);

    return prefsAsync.when(
      loading: () => const Scaffold(body: LoadingOverlay()),
      error: (e, _) => Scaffold(body: ErrorView(message: e.toString())),
      data: (prefs) {
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final hash = await SmsAutoFill().getAppSignature;
                      await Clipboard.setData(ClipboardData(text: hash));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('App signature copied')),
                        );
                      }
                    } catch (_) {}
                  },
                  child: Icon(
                    Icons.local_shipping,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _InfoTile(label: 'User ID', value: prefs.userId ?? ''),
              _InfoTile(label: 'Name', value: prefs.userName ?? ''),
              _InfoTile(label: 'Phone', value: prefs.phoneNumber ?? ''),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _logout(context, ref),
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'LOGOUT',
    );
    if (confirmed != true) return;

    final prefs = await ref.read(prefsProvider.future);
    final locationService = LocationTrackingService(
      prefs,
      ref.read(apiClientProvider),
    );
    await locationService.stop();
    await SessionService(prefs).clearSession();
    ref.read(lastLoginTimeProvider.notifier).state = null;

    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value),
    );
  }
}

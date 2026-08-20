import 'package:flutter/material.dart';

import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_surface.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key, this.onLeaveWhenRoot});

  /// Used when this screen is the app root (e.g. public `/help` URL).
  final VoidCallback? onLeaveWhenRoot;

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    onLeaveWhenRoot?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showBack =
        Navigator.of(context).canPop() || onLeaveWhenRoot != null;

    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Help'),
        automaticallyImplyLeading: false,
        leading: showBack
            ? BackButton(onPressed: () => _handleBack(context))
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AppSurface(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'For assistance, please call our support number:',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '(+91)6282727002',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Working hours',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '9AM to 6PM on all working days.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

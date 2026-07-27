import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../services/force_update_service.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({
    super.key,
    required this.evaluation,
    required this.onUpdate,
    this.onRetry,
    this.isUpdating = false,
    this.isRetrying = false,
  });

  final ForceUpdateEvaluation evaluation;
  final VoidCallback onUpdate;
  final VoidCallback? onRetry;
  final bool isUpdating;
  final bool isRetrying;

  bool get _showUpdateButton =>
      evaluation.result == ForceUpdateCheckResult.updateRequired;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update_alt, size: 56, color: primary),
                  const SizedBox(height: 20),
                  Text(
                    _showUpdateButton ? 'Update required' : 'Connection required',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    evaluation.displayMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_showUpdateButton &&
                      evaluation.currentVersion != null &&
                      evaluation.minimumVersion != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Installed: ${evaluation.currentVersion} · Required: ${evaluation.minimumVersion}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_showUpdateButton)
                    FilledButton(
                      onPressed: isUpdating ? null : onUpdate,
                      style: AppTheme.compactFilledButton(),
                      child: isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Update'),
                    ),
                  if (onRetry != null) ...[
                    if (_showUpdateButton) const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: isRetrying ? null : onRetry,
                      style: AppTheme.compactOutlinedButton(),
                      child: isRetrying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForceUpdateCheckingScreen extends StatelessWidget {
  const ForceUpdateCheckingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

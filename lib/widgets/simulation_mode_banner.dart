import 'package:flutter/material.dart';

class SimulationModeBanner extends StatelessWidget {
  const SimulationModeBanner({
    super.key,
    required this.isVisible,
    required this.onExitSimulation,
  });

  final bool isVisible;
  final Future<void> Function() onExitSimulation;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.primary),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.manage_accounts_outlined,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'You are in simulation mode.',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => onExitSimulation(),
                child: const Text('Exit Simulation Mode'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SimulationModeAppBarAction extends StatelessWidget {
  const SimulationModeAppBarAction({
    super.key,
    required this.isVisible,
    required this.onExitSimulation,
  });

  final bool isVisible;
  final Future<void> Function() onExitSimulation;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return IconButton(
      tooltip: 'Exit simulation mode',
      onPressed: () => onExitSimulation(),
      icon: const Icon(Icons.exit_to_app),
    );
  }
}

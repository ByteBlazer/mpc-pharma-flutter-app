import 'package:flutter/material.dart';

/// Asks the user to confirm leaving a screen with unsaved work.
/// Returns `true` if they choose to discard and leave.
Future<bool> confirmDiscardUnsavedChanges(
  BuildContext context, {
  String title = 'Discard changes?',
  String message =
      'You have unsaved changes. If you leave now, they will be lost.',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Discard'),
          ),
        ],
      );
    },
  );
  return result == true;
}

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_snack_bar.dart';

Future<bool> showReportIssueDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String docId,
  required Future<void> Function() onLoginAgain,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (context) {
      return _ReportIssueDialog(
        onSubmit: (comment) async {
          final result = await apiClient.markAsUnDelivered(
            docId: docId,
            failureComment: comment,
          );
          if (!context.mounted) return false;
          if (result.statusCode == 401 || result.statusCode == 403) {
            showAppSnackBar(
              context,
              message: result.displayMessage,
              type: AppSnackBarType.error,
            );
            await onLoginAgain();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
            return false;
          }
          showAppSnackBar(
            context,
            message: result.displayMessage,
            type: result.success
                ? AppSnackBarType.success
                : AppSnackBarType.error,
          );
          return result.success;
        },
      );
    },
  );
  return submitted == true;
}

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog({
    required this.onSubmit,
  });

  final Future<bool> Function(String comment) onSubmit;

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  late final TextEditingController _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final comment = _controller.text.trim();
        return AlertDialog(
          title: const Text('Report Issue'),
          content: TextField(
            controller: _controller,
            enabled: !_submitting,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Describe issue',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _submitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _submitting || comment.isEmpty
                  ? null
                  : () async {
                      setState(() => _submitting = true);
                      final ok = await widget.onSubmit(comment);
                      if (!context.mounted) return;
                      Navigator.of(context).pop(ok);
                    },
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
}

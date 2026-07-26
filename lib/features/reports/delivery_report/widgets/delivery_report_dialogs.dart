import 'package:flutter/material.dart';

import '../../../../utils/download_file.dart';
import '../../../../utils/signature_image.dart';
import '../delivery_report_helpers.dart';

Future<void> showDeliveryReportCommentDialog({
  required BuildContext context,
  required String docId,
  required String comment,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Comment - $docId'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Text(
            comment.trim(),
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showDeliveryReportSignatureDialog({
  required BuildContext context,
  required String docId,
  required String signatureBase64,
  required DateTime? lastUpdatedAt,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final timestamp = formatDeliveryReportTimestamp(lastUpdatedAt);
      return AlertDialog(
        title: Text('Signature - $docId'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SignatureImagePreview(
                signatureBase64: signatureBase64,
                height: 220,
              ),
              if (timestamp.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Signature Timestamp: $timestamp',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final bytes = decodeSignatureBase64(signatureBase64);
              if (bytes == null || bytes.isEmpty) return;
              await downloadFile(
                fileName: 'signature-$docId.png',
                bytes: bytes,
                mimeType: 'image/png',
              );
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
        ],
      );
    },
  );
}

Future<void> showNoSignatureAvailableDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Signature unavailable'),
      content: const Text('No signature available for this document.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

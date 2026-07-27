import 'package:flutter/material.dart';

import '../../app_theme.dart';
import 'public_tracking_helpers.dart';
import 'public_tracking_models.dart';

class PublicTrackingTripDocuments extends StatelessWidget {
  const PublicTrackingTripDocuments({super.key, required this.documents});

  final List<TripTrackingDocument> documents;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    const textStyle = TextStyle(
      color: Colors.black87,
      fontSize: 14,
      height: 1.4,
    );

    return DefaultTextStyle(
      style: textStyle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.gradientPageSurface(primary, borderRadius: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invoices on this trip (${documents.length}):',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < documents.length; index++) ...[
              if (index > 0) const SizedBox(height: 6),
              _InvoiceLine(
                serialNumber: index + 1,
                document: documents[index],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InvoiceLine extends StatelessWidget {
  const _InvoiceLine({
    required this.serialNumber,
    required this.document,
  });

  final int serialNumber;
  final TripTrackingDocument document;

  @override
  Widget build(BuildContext context) {
    final amount = formatPublicTrackingAmount(document.docAmountRaw);

    return Text.rich(
      TextSpan(
        style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
        children: [
          TextSpan(
            text: '$serialNumber. ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: document.docId,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (amount.isNotEmpty) ...[
            const TextSpan(text: ' — '),
            TextSpan(
              text: amount,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }
}

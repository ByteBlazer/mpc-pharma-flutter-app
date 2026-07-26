import 'package:flutter/material.dart';

import 'public_tracking_helpers.dart';
import 'public_tracking_models.dart';

class PublicTrackingTripDocuments extends StatelessWidget {
  const PublicTrackingTripDocuments({
    super.key,
    required this.documents,
    required this.primaryDocId,
  });

  final List<TripTrackingDocument> documents;
  final String primaryDocId;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    final primaryId = primaryDocId.trim();
    final showHeading = documents.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading) ...[
          Text(
            'Documents on this trip (${documents.length})',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
        ],
        ...documents.map(
          (doc) => _TripDocumentTile(
            document: doc,
            isPrimary: doc.docId.trim() == primaryId,
            showPrimaryBadge: showHeading,
          ),
        ),
      ],
    );
  }
}

class _TripDocumentTile extends StatelessWidget {
  const _TripDocumentTile({
    required this.document,
    required this.isPrimary,
    required this.showPrimaryBadge,
  });

  final TripTrackingDocument document;
  final bool isPrimary;
  final bool showPrimaryBadge;

  @override
  Widget build(BuildContext context) {
    final status = publicTrackingStatusDisplay(document.status);
    final amount = formatPublicTrackingAmount(document.docAmountRaw);
    final comment = document.comment.trim();
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isPrimary && showPrimaryBadge
              ? primary.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary && showPrimaryBadge
                ? primary.withValues(alpha: 0.25)
                : Colors.black12,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    document.docId,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (amount.isNotEmpty)
                    Text(
                      amount,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  _TripDocumentStatusChip(status: status),
                  if (isPrimary && showPrimaryBadge)
                    Text(
                      'This link',
                      style: TextStyle(
                        color: primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (comment.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  comment,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TripDocumentStatusChip extends StatelessWidget {
  const _TripDocumentStatusChip({required this.status});

  final PublicTrackingStatusDisplay status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: status.color.withValues(alpha: 0.45)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

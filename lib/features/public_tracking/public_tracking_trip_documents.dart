import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../widgets/app_brand_panel.dart';
import '../reports/delivery_report/widgets/delivery_report_dialogs.dart';
import 'public_tracking_helpers.dart';
import 'public_tracking_models.dart';

class PublicTrackingTripDocuments extends StatefulWidget {
  const PublicTrackingTripDocuments({super.key, required this.documents});

  final List<TripTrackingDocument> documents;

  @override
  State<PublicTrackingTripDocuments> createState() =>
      _PublicTrackingTripDocumentsState();
}

class _PublicTrackingTripDocumentsState
    extends State<PublicTrackingTripDocuments> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final documents = widget.documents;
    if (documents.isEmpty) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    final title = documents.length == 1
        ? 'Invoice'
        : 'Invoices on this trip (${documents.length})';
    final titleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.black54,
      fontWeight: FontWeight.bold,
    );

    final toggleLabel = _expanded ? 'Hide' : 'Show';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primary.withValues(alpha: 0.45)),
                color: primary.withValues(alpha: 0.06),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      color: primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: titleStyle?.copyWith(color: Colors.black87),
                      ),
                    ),
                    Text(
                      toggleLabel,
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: primary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              for (var index = 0; index < documents.length; index++) ...[
                if (index > 0) const SizedBox(height: 10),
                _DocumentCard(
                  serialNumber: documents.length == 1 ? null : index + 1,
                  document: documents[index],
                  surfaceColor: primary,
                ),
              ],
            ],
          ),
          sizeCurve: Curves.easeInOut,
        ),
      ],
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.serialNumber,
    required this.document,
    required this.surfaceColor,
  });

  final int? serialNumber;
  final TripTrackingDocument document;
  final Color surfaceColor;

  Future<void> _viewSignature(BuildContext context) async {
    if (!document.hasSignature) {
      await showNoSignatureAvailableDialog(context);
      return;
    }
    await showDeliveryReportSignatureDialog(
      context: context,
      docId: document.docId,
      signatureBase64: document.signature,
      lastUpdatedAt: document.deliveredAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = formatPublicTrackingAmount(document.docAmountRaw);
    final status = publicTrackingStatusDisplay(document.status);
    final comment = document.comment.trim();
    final bodyMedium = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Colors.black54,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.gradientPageSurface(surfaceColor, borderRadius: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                height: 1.4,
              ),
              children: [
                if (serialNumber != null)
                  TextSpan(
                    text: '$serialNumber. ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const TextSpan(
                  text: 'Invoice: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(status.icon, size: 16, color: status.color),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (document.isDelivered) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => _viewSignature(context),
                  icon: const Icon(Icons.draw_outlined, size: 16),
                  label: const Text('View signature'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
          if (document.isUndelivered && document.deliveredAt != null) ...[
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: bodyMedium,
                children: [
                  const TextSpan(
                    text: 'Delivery failed at: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: formatPublicTrackingInstant(document.deliveredAt!),
                  ),
                ],
              ),
            ),
          ],
          if (document.isTerminal && comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Delivery comment:',
              style: bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            AppBrandPanel(child: Text(comment)),
          ],
        ],
      ),
    );
  }
}

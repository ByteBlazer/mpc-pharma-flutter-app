import 'package:flutter/material.dart';

import '../../../core/models/web_portal_models.dart';
import '../web_portal_styles.dart';

/// Non-web fallback — simple scrollable list (portal targets web).
class DeliveryReportTableView extends StatelessWidget {
  const DeliveryReportTableView({
    super.key,
    required this.tableHtml,
    required this.rows,
    required this.onViewSignature,
    required this.onViewComment,
  });

  final String tableHtml;
  final List<WebPortalDeliveryReportItem> rows;
  final void Function(String docId) onViewSignature;
  final void Function(String docId) onViewComment;

  @override
  Widget build(BuildContext context) {
    return WebPortalPaper(
      padding: const EdgeInsets.all(12),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              dense: true,
              title: Text('${row.docId} — ${row.firmName ?? '-'}'),
              subtitle: Text('${row.status} · Trip ${row.tripId}'),
              onTap: () {},
            );
          },
        ),
      ),
    );
  }
}

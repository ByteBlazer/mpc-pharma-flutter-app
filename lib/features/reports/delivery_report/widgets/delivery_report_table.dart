import 'package:flutter/material.dart';

import '../../../../api/api_client.dart';
import '../delivery_report_helpers.dart';
import '../delivery_report_models.dart';
import 'delivery_report_dialogs.dart';

class DeliveryReportTable extends StatefulWidget {
  const DeliveryReportTable({
    super.key,
    required this.rows,
    required this.apiClient,
  });

  final List<DeliveryReportRow> rows;
  final ApiClient apiClient;

  @override
  State<DeliveryReportTable> createState() => _DeliveryReportTableState();
}

class _DeliveryReportTableState extends State<DeliveryReportTable> {
  final _headerScrollController = ScrollController();
  final _bodyHorizontalScrollController = ScrollController();
  final _bodyVerticalScrollController = ScrollController();
  bool _syncingScroll = false;

  static const _columns = <_DeliveryReportColumn>[
    _DeliveryReportColumn('Doc ID', 160),
    _DeliveryReportColumn('Doc Date', 110),
    _DeliveryReportColumn('Customer', 260),
    _DeliveryReportColumn('City', 120),
    _DeliveryReportColumn('Status', 150),
    _DeliveryReportColumn('Comment', 180),
    _DeliveryReportColumn('Trip ID', 90),
    _DeliveryReportColumn('Route', 150),
    _DeliveryReportColumn('Trip Creator', 220),
    _DeliveryReportColumn('Driver', 180),
    _DeliveryReportColumn('Vehicle', 90),
    _DeliveryReportColumn('Origin Warehouse', 150),
  ];

  @override
  void initState() {
    super.initState();
    _headerScrollController.addListener(_syncHeaderToBody);
    _bodyHorizontalScrollController.addListener(_syncBodyToHeader);
  }

  @override
  void dispose() {
    _headerScrollController.removeListener(_syncHeaderToBody);
    _bodyHorizontalScrollController.removeListener(_syncBodyToHeader);
    _headerScrollController.dispose();
    _bodyHorizontalScrollController.dispose();
    _bodyVerticalScrollController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() {
    if (_syncingScroll) return;
    _syncingScroll = true;
    _bodyHorizontalScrollController.jumpTo(_headerScrollController.offset);
    _syncingScroll = false;
  }

  void _syncBodyToHeader() {
    if (_syncingScroll) return;
    _syncingScroll = true;
    _headerScrollController.jumpTo(_bodyHorizontalScrollController.offset);
    _syncingScroll = false;
  }

  double get _tableWidth =>
      _columns.fold<double>(0, (sum, column) => sum + column.width);

  Future<void> _viewSignature(DeliveryReportRow row) async {
    try {
      final result = await widget.apiClient.getDocSignature(docId: row.docId);
      if (!mounted) return;
      if (!result.found || result.signature.trim().isEmpty) {
        await showNoSignatureAvailableDialog(context);
        return;
      }
      await showDeliveryReportSignatureDialog(
        context: context,
        docId: row.docId,
        signatureBase64: result.signature,
        lastUpdatedAt: result.lastUpdatedAt,
      );
    } catch (error) {
      if (!mounted) return;
      await showNoSignatureAvailableDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Material(
              color: const Color(0xFFF5F5F5),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _headerScrollController,
                child: SizedBox(
                  width: _tableWidth,
                  child: Row(
                    children: [
                      for (final column in _columns)
                        _HeaderCell(label: column.label, width: column.width),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _bodyVerticalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _bodyVerticalScrollController,
                  child: Scrollbar(
                    controller: _bodyHorizontalScrollController,
                    thumbVisibility: true,
                    notificationPredicate: (_) => true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _bodyHorizontalScrollController,
                      child: SizedBox(
                        width: _tableWidth,
                        child: Column(
                          children: [
                            for (var index = 0; index < widget.rows.length; index++)
                              _DeliveryReportDataRow(
                                row: widget.rows[index],
                                columns: _columns,
                                shaded: index.isOdd,
                                onViewSignature: _viewSignature,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryReportColumn {
  const _DeliveryReportColumn(this.label, this.width);

  final String label;
  final double width;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _DeliveryReportDataRow extends StatelessWidget {
  const _DeliveryReportDataRow({
    required this.row,
    required this.columns,
    required this.shaded,
    required this.onViewSignature,
  });

  final DeliveryReportRow row;
  final List<_DeliveryReportColumn> columns;
  final bool shaded;
  final Future<void> Function(DeliveryReportRow row) onViewSignature;

  @override
  Widget build(BuildContext context) {
    final comment = row.comment.trim();
    final commentPreview = comment.isEmpty ? '—' : comment;
    final commentStyle = TextStyle(
      fontSize: 13,
      color: comment.isEmpty ? Colors.black38 : Colors.black87,
    );
    final commentColumnWidth = columns[5].width - 24;
    final commentPainter = TextPainter(
      text: TextSpan(text: commentPreview, style: commentStyle),
      maxLines: deliveryReportCommentPreviewMaxLines,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: commentColumnWidth);
    final commentTruncated = commentPainter.didExceedMaxLines;
    final showCommentLink = shouldShowDeliveryReportCommentLink(
      row: row,
      isTruncated: commentTruncated,
    );

    return Material(
      color: shaded ? const Color(0xFFFAFAFA) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyCell(
            width: columns[0].width,
            child: SelectableText(row.docId, style: _cellTextStyle()),
          ),
          _BodyCell(
            width: columns[1].width,
            child: Text(
              formatDeliveryReportDocDate(row.docDate),
              style: _cellTextStyle(),
            ),
          ),
          _BodyCell(
            width: columns[2].width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.firmName.trim().isEmpty ? '—' : row.firmName.trim(),
                  style: _cellTextStyle(bold: true),
                ),
                if (row.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    row.address.trim(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _BodyCell(
            width: columns[3].width,
            child: Text(
              row.city.trim().isEmpty ? '—' : row.city.trim(),
              style: _cellTextStyle(),
            ),
          ),
          _BodyCell(
            width: columns[4].width,
            child: _StatusCell(
              row: row,
              showCommentLink: showCommentLink,
              comment: comment,
              onViewSignature: () => onViewSignature(row),
            ),
          ),
          _BodyCell(
            width: columns[5].width,
            child: Text(
              commentPreview,
              maxLines: deliveryReportCommentPreviewMaxLines,
              overflow: TextOverflow.ellipsis,
              style: commentStyle,
            ),
          ),
          _BodyCell(
            width: columns[6].width,
            child: Text(
              row.tripId?.toString() ?? '—',
              style: _cellTextStyle(bold: true),
            ),
          ),
          _BodyCell(
            width: columns[7].width,
            child: Text(
              row.route.trim().isEmpty ? '—' : row.route.trim(),
              style: _cellTextStyle(bold: true),
            ),
          ),
          _BodyCell(
            width: columns[8].width,
            child: Text(
              row.tripCreatorLabel.isEmpty ? '—' : row.tripCreatorLabel,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          _BodyCell(
            width: columns[9].width,
            child: Text(
              row.driverLabel.isEmpty ? '—' : row.driverLabel,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          _BodyCell(
            width: columns[10].width,
            child: Text(
              row.vehicleNbr.trim().isEmpty ? '—' : row.vehicleNbr.trim(),
              style: _cellTextStyle(),
            ),
          ),
          _BodyCell(
            width: columns[11].width,
            child: Text(
              row.originWarehouse.trim().isEmpty
                  ? '—'
                  : row.originWarehouse.trim(),
              style: _cellTextStyle(),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _cellTextStyle({bool bold = false}) {
    return TextStyle(
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
      color: Colors.black87,
      height: 1.35,
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
  }
}

class _StatusCell extends StatelessWidget {
  const _StatusCell({
    required this.row,
    required this.showCommentLink,
    required this.comment,
    required this.onViewSignature,
  });

  final DeliveryReportRow row;
  final bool showCommentLink;
  final String comment;
  final VoidCallback onViewSignature;

  @override
  Widget build(BuildContext context) {
    final label = deliveryReportStatusLabel(row.status);
    final color = Color(deliveryReportStatusColor(row.status));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        if (row.isDelivered) ...[
          const SizedBox(height: 6),
          _ReportLinkButton(
            label: 'View Signature',
            onPressed: onViewSignature,
          ),
        ],
        if (showCommentLink) ...[
          const SizedBox(height: 6),
          _ReportLinkButton(
            label: 'View Comment',
            onPressed: () => showDeliveryReportCommentDialog(
              context: context,
              docId: row.docId,
              comment: comment,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReportLinkButton extends StatelessWidget {
  const _ReportLinkButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: color,
        ),
      ),
    );
  }
}

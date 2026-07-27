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
  final _headerHorizontalScrollController = ScrollController();
  final _bodyHorizontalScrollController = ScrollController();
  final _bodyVerticalScrollController = ScrollController();
  bool _syncingHorizontalScroll = false;

  static const _scrollBarThickness = 10.0;

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
    _headerHorizontalScrollController.addListener(_syncHeaderScrollToBody);
    _bodyHorizontalScrollController.addListener(_syncBodyScrollToHeader);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _headerHorizontalScrollController.removeListener(_syncHeaderScrollToBody);
    _bodyHorizontalScrollController.removeListener(_syncBodyScrollToHeader);
    _headerHorizontalScrollController.dispose();
    _bodyHorizontalScrollController.dispose();
    _bodyVerticalScrollController.dispose();
    super.dispose();
  }

  void _syncHeaderScrollToBody() {
    if (_syncingHorizontalScroll ||
        !_bodyHorizontalScrollController.hasClients) {
      return;
    }
    _syncingHorizontalScroll = true;
    _bodyHorizontalScrollController.jumpTo(
      _headerHorizontalScrollController.offset,
    );
    _syncingHorizontalScroll = false;
  }

  void _syncBodyScrollToHeader() {
    if (_syncingHorizontalScroll ||
        !_headerHorizontalScrollController.hasClients) {
      return;
    }
    _syncingHorizontalScroll = true;
    _headerHorizontalScrollController.jumpTo(
      _bodyHorizontalScrollController.offset,
    );
    _syncingHorizontalScroll = false;
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
                controller: _headerHorizontalScrollController,
                physics: const NeverScrollableScrollPhysics(),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final listHeight =
                      (constraints.maxHeight - _scrollBarThickness).clamp(
                        0.0,
                        double.infinity,
                      );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _bodyHorizontalScrollController,
                                child: SizedBox(
                                  width: _tableWidth,
                                  height: listHeight,
                                  child: ListView.builder(
                                    controller: _bodyVerticalScrollController,
                                    itemCount: widget.rows.length,
                                    itemBuilder: (context, index) {
                                      return SizedBox(
                                        width: _tableWidth,
                                        child: _DeliveryReportDataRow(
                                          row: widget.rows[index],
                                          columns: _columns,
                                          shaded: index.isOdd,
                                          onViewSignature: _viewSignature,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            _ScrollBarTrack(
                              controller: _bodyHorizontalScrollController,
                              axis: Axis.horizontal,
                              thickness: _scrollBarThickness,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: listHeight,
                        child: _ScrollBarTrack(
                          controller: _bodyVerticalScrollController,
                          axis: Axis.vertical,
                          thickness: _scrollBarThickness,
                        ),
                      ),
                    ],
                  );
                },
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
    final showCommentLink = shouldShowDeliveryReportCommentLink(row: row);

    return Material(
      color: shaded ? const Color(0xFFFAFAFA) : Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BodyCell(
            width: columns[0].width,
            child: Text(row.docId, style: _cellTextStyle()),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
    final color = row.isDelivered
        ? Theme.of(context).colorScheme.primary
        : Color(deliveryReportStatusColor(row.status));

    final pill = Container(
      width: deliveryReportStatusPillWidth,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pill,
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
  const _ReportLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onPressed,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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

class _ScrollBarTrack extends StatelessWidget {
  const _ScrollBarTrack({
    required this.controller,
    required this.axis,
    required this.thickness,
  });

  final ScrollController controller;
  final Axis axis;
  final double thickness;

  static const _trackColor = Color(0xFFE4E7EB);
  static const _thumbColor = Color(0xFF98A2B3);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isHorizontal = axis == Axis.horizontal;

        return SizedBox(
          height: isHorizontal ? thickness : double.infinity,
          width: isHorizontal ? double.infinity : thickness,
          child: _buildTrack(isHorizontal),
        );
      },
    );
  }

  Widget _buildTrack(bool isHorizontal) {
    if (!_isScrollReady) {
      return const ColoredBox(color: _trackColor);
    }

    final position = controller.position;
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return const ColoredBox(color: _trackColor);
    }

    final maxScroll = position.maxScrollExtent;
    final scrollable = maxScroll > 0;
    final contentSize = viewport + maxScroll;
    final thumbMainSize = scrollable
        ? (viewport / contentSize * viewport).clamp(thickness * 2, viewport)
        : 0.0;
    final thumbTravel = viewport - thumbMainSize;
    final thumbOffset = scrollable && thumbTravel > 0
        ? (position.pixels / maxScroll * thumbTravel).clamp(0.0, thumbTravel)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: scrollable
              ? (details) {
                  final delta = isHorizontal
                      ? details.delta.dx
                      : details.delta.dy;
                  controller.jumpTo(
                    (controller.offset + delta * contentSize / viewport).clamp(
                      0.0,
                      maxScroll,
                    ),
                  );
                }
              : null,
          onTapDown: scrollable && thumbTravel > 0
              ? (details) {
                  final local = details.localPosition;
                  final trackMainSize = isHorizontal
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  final availableTrack = trackMainSize - thumbMainSize;
                  if (availableTrack <= 0) return;

                  final targetOffset =
                      (isHorizontal ? local.dx : local.dy) - thumbMainSize / 2;
                  final scrollFraction = (targetOffset / availableTrack).clamp(
                    0.0,
                    1.0,
                  );
                  controller.jumpTo(scrollFraction * maxScroll);
                }
              : null,
          child: Stack(
            children: [
              const ColoredBox(color: _trackColor),
              if (scrollable && thumbMainSize > 0)
                if (isHorizontal)
                  Positioned(
                    left: thumbOffset,
                    top: 1,
                    bottom: 1,
                    width: thumbMainSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _thumbColor,
                        borderRadius: BorderRadius.circular(thickness),
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: thumbOffset,
                    left: 1,
                    right: 1,
                    height: thumbMainSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _thumbColor,
                        borderRadius: BorderRadius.circular(thickness),
                      ),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  bool get _isScrollReady {
    if (!controller.hasClients) return false;

    final position = controller.position;
    return position.hasViewportDimension && position.hasContentDimensions;
  }
}

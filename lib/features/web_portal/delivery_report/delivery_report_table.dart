import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';
import '../web_portal_styles.dart';

/// Delivery report results table — same columns and styling on all platforms.
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

  static const _minTableWidth = 1420.0;

  static const _headers = [
    _TableColumn('Doc ID', 140),
    _TableColumn('Doc Date', 100),
    _TableColumn('Customer', 170),
    _TableColumn('City', 100),
    _TableColumn('Status', 140),
    _TableColumn('Comment', 140),
    _TableColumn('Trip ID', 56),
    _TableColumn('Route', 100),
    _TableColumn('Trip Creator', 155),
    _TableColumn('Driver', 110),
    _TableColumn('Vehicle', 100),
    _TableColumn('Origin Warehouse', 110),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scrollbar(
          thumbVisibility: rows.length > 8,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _minTableWidth,
              height: constraints.maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(columns: _headers),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No records to display',
                                style: TextStyle(
                                  color: WebPortalStyles.textSecondary,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: 1),
                            itemBuilder: (context, index) => _DataRow(
                              row: rows[index],
                              stripe: index.isOdd,
                              columns: _headers,
                              onViewSignature: onViewSignature,
                              onViewComment: onViewComment,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TableColumn {
  const _TableColumn(this.label, this.width);
  final String label;
  final double width;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns});

  final List<_TableColumn> columns;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: WebPortalStyles.usersTableHeaderBg,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (final col in columns)
            SizedBox(
              width: col.width,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  col.label,
                  style: WebPortalStyles.usersTableHeaderStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.row,
    required this.stripe,
    required this.columns,
    required this.onViewSignature,
    required this.onViewComment,
  });

  final WebPortalDeliveryReportItem row;
  final bool stripe;
  final List<_TableColumn> columns;
  final void Function(String docId) onViewSignature;
  final void Function(String docId) onViewComment;

  @override
  Widget build(BuildContext context) {
    final delivered = row.status == AppConstants.docStatusDelivered;
    final failed = row.status == AppConstants.docStatusUndelivered;

    return ColoredBox(
      color: stripe ? const Color(0xFFFAFAFA) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cell(
              columns[0].width,
              Text(row.docId, style: _cellStyle),
            ),
            _cell(
              columns[1].width,
              Text(_formatDate(row.docDate), style: _cellStyle),
            ),
            _cell(
              columns[2].width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.firmName ?? '-',
                    style: _cellStyle.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (row.address != null && row.address!.isNotEmpty)
                    Text(
                      row.address!,
                      style: _subStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _cell(
              columns[3].width,
              Text(row.city ?? '-', style: _cellStyle),
            ),
            _cell(
              columns[4].width,
              Column(
                children: [
                  _StatusChip(
                    label: failed ? 'DELIVERY FAILED' : row.status,
                    delivered: delivered,
                    failed: failed,
                  ),
                  if (delivered)
                    TextButton(
                      onPressed: () => onViewSignature(row.docId),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View Signature', style: _linkStyle),
                    )
                  else if (failed)
                    TextButton(
                      onPressed: () => onViewComment(row.docId),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View Comment', style: _linkStyle),
                    ),
                ],
              ),
            ),
            _cell(
              columns[5].width,
              Text(
                row.comment ?? '',
                style: _cellStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _cell(
              columns[6].width,
              Text('${row.tripId}', style: _cellStyle),
            ),
            _cell(
              columns[7].width,
              Text(row.route ?? '-', style: _cellStyle),
            ),
            _cell(
              columns[8].width,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.createdByPersonName ?? '-', style: _cellStyle),
                  if (row.createdByLocation != null &&
                      row.createdByLocation!.isNotEmpty)
                    Text(
                      row.createdByLocation!,
                      style: _subStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _cell(
              columns[9].width,
              Text(row.driverName ?? '-', style: _cellStyle),
            ),
            _cell(
              columns[10].width,
              Text(row.vehicleNbr ?? '-', style: _cellStyle),
            ),
            _cell(
              columns[11].width,
              Text(row.originWarehouse ?? '-', style: _cellStyle),
            ),
          ],
        ),
      ),
    );
  }

  static const _cellStyle = TextStyle(fontSize: 13, color: Color(0xFF212121));
  static const _subStyle = TextStyle(fontSize: 11, color: WebPortalStyles.textSecondary);
  static const _linkStyle = TextStyle(fontSize: 12, color: Color(0xFF1976D2));

  Widget _cell(double width, Widget child) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: child,
      ),
    );
  }

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.delivered,
    required this.failed,
  });

  final String label;
  final bool delivered;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (delivered) {
      bg = const Color(0xFF2E7D32);
      fg = Colors.white;
    } else if (failed) {
      bg = WebPortalStyles.errorMain;
      fg = Colors.white;
    } else {
      bg = WebPortalStyles.chipDefaultBg;
      fg = WebPortalStyles.chipDefaultFg;
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: delivered || failed ? 140 : 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

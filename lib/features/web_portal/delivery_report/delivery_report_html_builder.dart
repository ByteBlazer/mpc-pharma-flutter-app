import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';

/// Builds an HTML table for the delivery report (runs in a background isolate).
class DeliveryReportHtmlBuilder {
  DeliveryReportHtmlBuilder._();

  static String buildTableHtml(List<WebPortalDeliveryReportItem> rows) {
    final buf = StringBuffer()
      ..writeln('<style>')
      ..writeln(_css)
      ..writeln('</style>')
      ..writeln('<div class="dr-wrap"><table class="dr-table"><thead><tr>')
      ..writeln(_headerCells)
      ..writeln('</tr></thead><tbody>');

    for (var i = 0; i < rows.length; i++) {
      buf.write(_rowHtml(rows[i], i.isOdd));
    }

    buf.writeln('</tbody></table></div>');
    return buf.toString();
  }

  static const _css = '''
.dr-wrap{width:100%;overflow:auto;height:100%;-webkit-overflow-scrolling:touch}
.dr-table{width:100%;min-width:1420px;table-layout:fixed;border-collapse:collapse;font-size:13px;line-height:1.3;color:#212121}
.dr-table th,.dr-table td{border-bottom:1px solid #e0e0e0;padding:8px 12px;text-align:left;vertical-align:middle}
.dr-table th{position:sticky;top:0;background:#f5f5f5;z-index:2;font-weight:700;box-shadow:0 2px 2px -1px rgba(0,0,0,.1)}
.dr-table tr.dr-stripe td{background:#fafafa}
.dr-sub{font-size:11px;color:#757575;display:block;margin-top:2px}
.dr-status{display:flex;flex-direction:column;align-items:center;gap:4px}
.dr-chip-row{display:flex;justify-content:center;width:100%}
.dr-chip{display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;height:24px;line-height:1;padding:0 12px;border-radius:16px;font-size:13px;font-weight:500;font-family:Roboto,Helvetica,Arial,sans-serif;white-space:nowrap;letter-spacing:0.16px;text-align:center}
.dr-chip-ok,.dr-chip-fail{width:140px;max-width:100%}
.dr-chip-ok{background:#2e7d32;color:#fff}
.dr-chip-fail{background:#d32f2f;color:#fff}
.dr-chip-default{display:inline-block;line-height:24px;padding:0 10px}
.dr-chip-default{background:#e0e0e0;color:#424242}
.dr-link{background:none;border:none;padding:0;margin:0;font-size:12px;color:#1976d2;text-decoration:underline;cursor:pointer;font-family:Roboto,Helvetica,Arial,sans-serif;line-height:1.66;text-align:center}
.dr-comment{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.dr-doc-id{white-space:nowrap}
''';

  /// Column widths as % — table is `width:100%` so columns grow with the panel (React MUI Table).
  static const _headerCells = '''
<th class="dr-doc-id" style="width:10%">Doc ID</th>
<th style="width:7%">Doc Date</th>
<th style="width:12%">Customer</th>
<th style="width:7%">City</th>
<th style="width:10%">Status</th>
<th style="width:10%">Comment</th>
<th style="width:4%">Trip ID</th>
<th style="width:7%">Route</th>
<th style="width:11%">Trip Creator</th>
<th style="width:8%">Driver</th>
<th style="width:7%">Vehicle</th>
<th style="width:7%">Origin Warehouse</th>
''';

  static String _rowHtml(WebPortalDeliveryReportItem row, bool stripe) {
    final delivered = row.status == AppConstants.docStatusDelivered;
    final failed = row.status == AppConstants.docStatusUndelivered;
    final statusLabel = failed ? 'DELIVERY FAILED' : _escape(row.status);
    final chipClass = delivered
        ? 'dr-chip dr-chip-ok'
        : (failed ? 'dr-chip dr-chip-fail' : 'dr-chip dr-chip-default');

    final action = delivered
        ? '<button type="button" class="dr-link" data-dr-action="signature" data-dr-doc-id="${_escapeAttr(row.docId)}">View Signature</button>'
        : (failed
            ? '<button type="button" class="dr-link" data-dr-action="comment" data-dr-doc-id="${_escapeAttr(row.docId)}">View Comment</button>'
            : '');

    final firm = _escape(row.firmName ?? '-');
    final address = row.address != null && row.address!.isNotEmpty
        ? '<span class="dr-sub">${_escape(row.address)}</span>'
        : '';
    final creatorLoc = row.createdByLocation != null && row.createdByLocation!.isNotEmpty
        ? '<span class="dr-sub">${_escape(row.createdByLocation)}</span>'
        : '';

    final trClass = stripe ? ' class="dr-stripe"' : '';
    return '''
<tr$trClass>
<td class="dr-doc-id">${_escape(row.docId)}</td>
<td>${_escape(_formatDate(row.docDate))}</td>
<td><strong>$firm</strong>$address</td>
<td>${_escape(row.city ?? '-')}</td>
<td><div class="dr-status"><div class="dr-chip-row"><span class="$chipClass">$statusLabel</span></div>$action</div></td>
<td class="dr-comment" title="${_escapeAttr(row.comment ?? '')}">${_escape(row.comment ?? '')}</td>
<td>${row.tripId}</td>
<td>${_escape(row.route ?? '-')}</td>
<td>${_escape(row.createdByPersonName ?? '-')}$creatorLoc</td>
<td>${_escape(row.driverName ?? '-')}</td>
<td>${_escape(row.vehicleNbr ?? '-')}</td>
<td>${_escape(row.originWarehouse ?? '-')}</td>
</tr>
''';
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

  static String _escape(String? value) {
    if (value == null || value.isEmpty) return '';
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  static String _escapeAttr(String value) =>
      value.replaceAll('&', '&amp;').replaceAll('"', '&quot;');
}

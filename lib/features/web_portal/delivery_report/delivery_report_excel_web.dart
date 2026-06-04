import 'dart:js_interop';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:web/web.dart' as web;

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';
import '../web_portal_utils.dart';

const _overlayId = 'mpc-delivery-report-excel-loading';
const _spinStyleId = 'mpc-excel-spin-style';

/// React `handleDownloadExcel` — builds XLSX and triggers browser download.
Future<void> downloadDeliveryReportExcel(
  BuildContext context,
  List<WebPortalDeliveryReportItem> rows,
) async {
  if (rows.isEmpty) return;

  // Flutter [showDialog] renders under [HtmlElementView] on web; use a DOM overlay.
  _showExportLoadingOverlay(rows.length);

  try {
    await SchedulerBinding.instance.endOfFrame;
    final bytes = await Future<Uint8List?>(() => _buildXlsxBytes(rows));
    if (bytes == null) return;
    _triggerBrowserDownload(bytes);
  } finally {
    _hideExportLoadingOverlay();
  }
}

void _showExportLoadingOverlay(int recordCount) {
  _hideExportLoadingOverlay();

  if (web.document.getElementById(_spinStyleId) == null) {
    final style = web.document.createElement('style') as web.HTMLStyleElement;
    style.id = _spinStyleId;
    style.textContent =
        '@keyframes mpc-excel-spin { to { transform: rotate(360deg); } }';
    web.document.head?.appendChild(style);
  }

  final overlay = web.document.createElement('div') as web.HTMLDivElement;
  overlay.id = _overlayId;
  overlay.style
    ..setProperty('position', 'fixed')
    ..setProperty('inset', '0')
    ..setProperty('z-index', '2147483647')
    ..setProperty('background-color', 'rgba(0, 0, 0, 0.45)')
    ..setProperty('display', 'flex')
    ..setProperty('align-items', 'center')
    ..setProperty('justify-content', 'center')
    ..setProperty('font-family', 'Roboto, Helvetica, Arial, sans-serif');

  final panel = web.document.createElement('div') as web.HTMLDivElement;
  panel.style
    ..setProperty('background-color', '#ffffff')
    ..setProperty('padding', '32px 40px')
    ..setProperty('border-radius', '4px')
    ..setProperty('box-shadow', '0 11px 15px rgba(0,0,0,0.2)')
    ..setProperty('text-align', 'center')
    ..setProperty('max-width', '400px');

  final spinner = web.document.createElement('div') as web.HTMLDivElement;
  spinner.style
    ..setProperty('width', '40px')
    ..setProperty('height', '40px')
    ..setProperty('margin', '0 auto 16px')
    ..setProperty('border', '3px solid #e0e0e0')
    ..setProperty('border-top-color', '#1976d2')
    ..setProperty('border-radius', '50%')
    ..setProperty('animation', 'mpc-excel-spin 0.8s linear infinite');

  final title = web.document.createElement('div') as web.HTMLDivElement;
  title.textContent = 'Preparing Excel export...';
  title.style
    ..setProperty('font-size', '16px')
    ..setProperty('color', 'rgba(0, 0, 0, 0.87)');

  final subtitle = web.document.createElement('div') as web.HTMLDivElement;
  subtitle.textContent = '$recordCount records';
  subtitle.style
    ..setProperty('font-size', '14px')
    ..setProperty('color', 'rgba(0, 0, 0, 0.6)')
    ..setProperty('margin-top', '8px');

  panel.append(spinner);
  panel.append(title);
  panel.append(subtitle);
  overlay.append(panel);
  web.document.body?.appendChild(overlay);
}

void _hideExportLoadingOverlay() {
  web.document.getElementById(_overlayId)?.remove();
}

void _triggerBrowserDownload(Uint8List bytes) {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(
      type:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = _filename();
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

String _filename() {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  return 'delivery-report-$date.xlsx';
}

/// Matches React `formatSignatureTimestamp` in DeliveryReportDataDisplaySection.
String _signatureTimestamp(WebPortalDeliveryReportItem row) {
  if (row.status != AppConstants.docStatusDelivered) return '';
  final raw = row.lastUpdatedAt;
  if (raw == null || raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return '';
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  final adjusted = date.subtract(
    Duration(milliseconds: istOffsetMs.round()),
  );
  return WebPortalUtils.formatDateTime(adjusted);
}

Uint8List? _buildXlsxBytes(List<WebPortalDeliveryReportItem> items) {
  const sheetName = 'Delivery Report';
  const headers = [
    'Doc ID',
    'Doc Date',
    'Firm Name',
    'Address',
    'City',
    'Status',
    'Signature Timestamp',
    'Comment',
    'Trip ID',
    'Route',
    'Trip Creator Name',
    'Trip Creator Location',
    'Driver',
    'Vehicle',
    'Origin Warehouse',
  ];

  final excel = Excel.createExcel();
  final defaultSheet = excel.getDefaultSheet();
  if (defaultSheet == null) return null;
  excel.rename(defaultSheet, sheetName);

  for (var c = 0; c < headers.length; c++) {
    excel.updateCell(
      sheetName,
      CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
      TextCellValue(headers[c]),
    );
  }

  for (var r = 0; r < items.length; r++) {
    final row = items[r];
    final values = <CellValue>[
      TextCellValue(row.docId),
      TextCellValue(WebPortalUtils.formatDateString(row.docDate)),
      TextCellValue(row.firmName ?? ''),
      TextCellValue(row.address ?? ''),
      TextCellValue(row.city ?? ''),
      TextCellValue(WebPortalUtils.docStatusLabel(row.status)),
      TextCellValue(_signatureTimestamp(row)),
      TextCellValue(row.comment ?? ''),
      IntCellValue(row.tripId),
      TextCellValue(row.route ?? ''),
      TextCellValue(row.createdByPersonName ?? ''),
      TextCellValue(row.createdByLocation ?? ''),
      TextCellValue(row.driverName ?? ''),
      TextCellValue(row.vehicleNbr ?? ''),
      TextCellValue(row.originWarehouse ?? ''),
    ];
    for (var c = 0; c < values.length; c++) {
      excel.updateCell(
        sheetName,
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
        values[c],
      );
    }
  }

  final encoded = excel.encode();
  if (encoded == null) return null;
  return Uint8List.fromList(encoded);
}

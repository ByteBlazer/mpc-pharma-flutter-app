import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/web_portal_models.dart';
import '../../../core/providers/providers.dart';
import 'delivery_report_html_builder.dart';
import 'delivery_report_state.dart';

class _ProcessedReport {
  const _ProcessedReport({required this.report, required this.tableHtml});

  final WebPortalDeliveryReportResponse report;
  final String tableHtml;
}

_ProcessedReport _processReportJson(Map<String, dynamic> json) {
  final report = WebPortalDeliveryReportResponse.fromJson(json);
  final tableHtml = DeliveryReportHtmlBuilder.buildTableHtml(report.data);
  return _ProcessedReport(report: report, tableHtml: tableHtml);
}

final deliveryReportControllerProvider =
    NotifierProvider.autoDispose<DeliveryReportController, DeliveryReportState>(
  DeliveryReportController.new,
);

class DeliveryReportController extends AutoDisposeNotifier<DeliveryReportState> {
  @override
  DeliveryReportState build() => const DeliveryReportState();

  Future<void> search(WebPortalDeliveryReportFilters query) async {
    state = DeliveryReportState(
      phase: DeliveryReportPhase.loading,
      appliedQuery: query,
    );

    try {
      final json =
          await ref.read(apiClientProvider).getDeliveryReportJson(query);
      final processed = await compute(_processReportJson, json);
      state = DeliveryReportState(
        phase: DeliveryReportPhase.ready,
        appliedQuery: query,
        report: processed.report,
        tableHtml: processed.tableHtml,
      );
    } catch (e) {
      state = DeliveryReportState(
        phase: DeliveryReportPhase.error,
        appliedQuery: query,
        errorMessage: e is Exception ? e.toString() : 'Failed to load report',
      );
    }
  }

  void clear() {
    state = const DeliveryReportState();
  }
}

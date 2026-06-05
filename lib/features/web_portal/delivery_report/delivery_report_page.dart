import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/web_portal_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../routing/app_routes.dart';
import '../trip_map/portal_map_utils.dart';
import '../trip_map/portal_signature_image.dart';
import '../web_portal_mui_dialog.dart';
import '../web_portal_signature_download.dart';
import '../web_portal_styles.dart';
import '../web_portal_utils.dart';
import 'delivery_report_controller.dart';
import 'delivery_report_excel.dart';
import 'delivery_report_filters.dart';
import 'delivery_report_state.dart';
import 'delivery_report_table.dart';

/// Delivery Report — React parity with Flutter-optimized rendering:
/// - Loading ends when API + JSON parse finish (not when the table paints).
/// - On web, all rows render in a DOM table (like React MUI TableBody).
class DeliveryReportPage extends ConsumerWidget {
  const DeliveryReportPage({super.key});

  static bool show30DayNote(WebPortalDeliveryReportFilters f) {
    return f.fromDate == null &&
        f.toDate == null &&
        (f.docId == null || f.docId!.length < 3) &&
        f.customerId == null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hPad = MediaQuery.sizeOf(context).width >= 600 ? 24.0 : 12.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(deliveryReportControllerProvider.notifier).clear();
                  context.go(AppRoutes.workflowWebReports);
                },
                style: WebPortalStyles.outlinedPrimaryButton(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Reports'),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Delivery Report',
                  style: WebPortalStyles.reportPageTitle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Scroll when filters stack (narrow) so content does not overflow.
                final resultsHeight = constraints.maxHeight.clamp(240.0, 640.0);
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const DeliveryReportFilters(),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: resultsHeight,
                        child: const _DeliveryReportResults(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryReportResults extends ConsumerWidget {
  const _DeliveryReportResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(deliveryReportControllerProvider);

    if (!state.hasSearched) {
      return const Center(
        child: EmptyState(message: 'Set filters and tap Search to load data.'),
      );
    }

    if (state.isLoading) {
      return const Center(
        child: LoadingOverlay(message: 'Loading report data...'),
      );
    }

    if (state.phase == DeliveryReportPhase.error) {
      return Center(
        child: ErrorView(message: state.errorMessage ?? 'Failed to load report'),
      );
    }

    final report = state.report;
    final query = state.appliedQuery;
    if (report == null || query == null || state.tableHtml == null) {
      return const SizedBox.shrink();
    }

    return _ResultsContent(
      query: query,
      report: report,
      tableHtml: state.tableHtml!,
    );
  }
}

class _ResultsContent extends ConsumerWidget {
  const _ResultsContent({
    required this.query,
    required this.report,
    required this.tableHtml,
  });

  final WebPortalDeliveryReportFilters query;
  final WebPortalDeliveryReportResponse report;
  final String tableHtml;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Results: ${report.totalRecords} records',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (DeliveryReportPage.show30DayNote(query)) ...[
              const SizedBox(width: 8),
              Text(
                '(Note: Data fetched for the last 30 days only)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: WebPortalStyles.textSecondary,
                    ),
              ),
            ],
            const Spacer(),
            if (report.data.isNotEmpty)
              FilledButton.icon(
                onPressed: () =>
                    downloadDeliveryReportExcel(context, report.data),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download Excel'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (report.data.isEmpty)
          const Expanded(
            child: Center(
              child: EmptyState(message: 'No records found for the selected filters.'),
            ),
          )
        else
          Expanded(
            child: WebPortalPaper(
              padding: EdgeInsets.zero,
              child: DeliveryReportTableView(
                tableHtml: tableHtml,
                rows: report.data,
                onViewSignature: (docId) => _showSignature(context, ref, docId),
                onViewComment: (docId) => _showComment(context, report, docId),
              ),
            ),
          ),
      ],
    );
  }

  void _showComment(
    BuildContext context,
    WebPortalDeliveryReportResponse report,
    String docId,
  ) {
    String? comment;
    for (final row in report.data) {
      if (row.docId == docId) {
        comment = row.comment;
        break;
      }
    }
    WebPortalMuiDialog.show<void>(
      context: context,
      title: 'Comment - $docId',
      content: WebPortalMuiDialog.bodyText(
        comment ?? 'No comment available',
      ),
    );
  }

  static Future<void> _showSignature(
    BuildContext context,
    WidgetRef ref,
    String docId,
  ) async {
    try {
      final sig = await ref.read(apiClientProvider).getDocSignature(docId);
      if (!context.mounted) return;
      final hasImage = portalSignatureHasDisplayableImage(sig.signature);
      if (!context.mounted) return;

      await WebPortalMuiDialog.show<void>(
        context: context,
        maxWidth: 900,
        title: 'Signature - $docId',
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const previewHeight = 400.0;
                    final previewWidth = constraints.maxWidth;
                    if (!hasImage) {
                      return const SizedBox(
                        height: previewHeight,
                        child: Center(
                          child: Text(
                            'Signature unavailable',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ),
                      );
                    }
                    return PortalSignatureImage(
                      base64Signature: sig.signature,
                      width: previewWidth,
                      height: previewHeight,
                      maxHeight: previewHeight,
                      fillContainer: true,
                      showLabel: false,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575),
                    height: 1.43,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Signature Timestamp: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: WebPortalUtils.formatDateTime(
                        DateTime.tryParse(sig.lastUpdatedAt),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsBuilder: (dialogContext) => [
          WebPortalMuiDialog.closeButton(dialogContext),
          if (hasImage)
            WebPortalMuiDialog.downloadButton(
              onPressed: () => downloadSignaturePng(docId, sig.signature),
            ),
        ],
      );
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

}

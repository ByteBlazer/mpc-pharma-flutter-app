import '../../../core/models/web_portal_models.dart';

enum DeliveryReportPhase { idle, loading, ready, error }

/// UI state for Delivery Report — loading covers network + parse only, not table paint.
class DeliveryReportState {
  const DeliveryReportState({
    this.phase = DeliveryReportPhase.idle,
    this.appliedQuery,
    this.report,
    this.tableHtml,
    this.errorMessage,
  });

  final DeliveryReportPhase phase;
  final WebPortalDeliveryReportFilters? appliedQuery;
  final WebPortalDeliveryReportResponse? report;
  final String? tableHtml;
  final String? errorMessage;

  bool get isLoading => phase == DeliveryReportPhase.loading;
  bool get hasSearched => appliedQuery != null;

  DeliveryReportState copyWith({
    DeliveryReportPhase? phase,
    WebPortalDeliveryReportFilters? appliedQuery,
    bool clearQuery = false,
    WebPortalDeliveryReportResponse? report,
    bool clearReport = false,
    String? tableHtml,
    bool clearTableHtml = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DeliveryReportState(
      phase: phase ?? this.phase,
      appliedQuery: clearQuery ? null : (appliedQuery ?? this.appliedQuery),
      report: clearReport ? null : (report ?? this.report),
      tableHtml: clearTableHtml ? null : (tableHtml ?? this.tableHtml),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

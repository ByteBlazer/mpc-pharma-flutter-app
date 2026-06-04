import 'package:flutter/material.dart';

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';
import '../web_portal_styles.dart';
import 'portal_map_marker.dart';
import 'trip_summary_package_icon_stub.dart'
    if (dart.library.html) 'trip_summary_package_icon_web.dart';

/// Trip Dashboard map overlay — matches React `Paper` summary (TripDashboard.tsx).
class PortalTripSummaryOverlay extends StatelessWidget {
  const PortalTripSummaryOverlay({
    super.key,
    required this.trip,
    required this.summary,
  });

  /// Fixed width — map [Positioned] overlays have unbounded horizontal constraints.
  static const panelWidth = 280.0;

  final WebPortalTrip trip;
  final PortalTripSummary summary;

  static const _success = Color(0xFF2E7D32);
  static const _error = Color(0xFFD32F2F);
  static const _warning = Color(0xFFED6C02);
  static const _info = Color(0xFF0288D1);

  @override
  Widget build(BuildContext context) {
    final title = switch (trip.status) {
      AppConstants.tripStatusScheduled => 'Trip Yet To Start',
      AppConstants.tripStatusStarted => 'Trip In Progress',
      _ => 'Trip Summary',
    };

    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: panelWidth,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 14,
              height: 1.43,
              color: Colors.black87,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _row(
                  label: 'Total Customers:',
                  value: '${summary.totalDeliveries}',
                  labelColor: WebPortalStyles.textSecondary,
                ),
                _row(
                  label: '✓ Completed:',
                  value: '${summary.completedDeliveries}',
                  labelColor: _success,
                  valueColor: _success,
                ),
                _row(
                  label: '✗ Failed:',
                  value: '${summary.failedDeliveries}',
                  labelColor: _error,
                  valueColor: _error,
                ),
                _row(
                  label: '⏳ Pending:',
                  value: '${summary.pendingDeliveries}',
                  labelColor: _warning,
                  valueColor: _warning,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE0E0E0)),
                ),
                _dropoffsRow(value: '${summary.dropoffsPending}'),
                if (summary.duration != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFE0E0E0)),
                  ),
                  _row(
                    label: summary.durationLabel ?? 'Duration:',
                    value: summary.duration!,
                    labelColor: WebPortalStyles.textSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Brown package + blue label — icon via DOM `<img>` on web (see trip_summary_package_icon_web).
  static Widget _dropoffsRow({required String value}) {
    const bodyStyle = TextStyle(fontSize: 14, height: 1.43, color: _info);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                tripSummaryPackageIcon(16),
                const SizedBox(width: 4),
                const Flexible(
                  child: Text(
                    'Lot Dropoffs Pending:',
                    style: bodyStyle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: bodyStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  static Widget _row({
    required String label,
    required String value,
    required Color labelColor,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: labelColor, fontSize: 14, height: 1.43),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown on the map while trip detail (doc groups) is still loading.
class PortalTripSummaryLoadingOverlay extends StatelessWidget {
  const PortalTripSummaryLoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      elevation: 3,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: PortalTripSummaryOverlay.panelWidth,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading trip summary…'),
            ],
          ),
        ),
      ),
    );
  }
}

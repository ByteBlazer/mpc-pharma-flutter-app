import 'package:flutter/material.dart';

import '../../widgets/app_surface.dart';
import '../my_trips/my_trips_models.dart';
import 'trip_dashboard_helpers.dart';

class TripSummaryPanel extends StatelessWidget {
  const TripSummaryPanel({
    super.key,
    required this.detail,
    required this.summary,
    this.initiallyExpanded = true,
  });

  final SingleTripDetails detail;
  final TripProgressSummary summary;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final status = detail.status.toUpperCase();
    final title = switch (status) {
      'SCHEDULED' => 'Trip yet to start',
      'STARTED' => 'Trip in progress',
      'ENDED' => 'Trip summary',
      _ => 'Trip summary',
    };

    return AppSurface(
      borderRadius: 14,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          children: [
            _MetricRow(label: 'Total customers', value: '${summary.totalCustomers}'),
            _MetricRow(label: 'Completed', value: '${summary.completed}'),
            _MetricRow(label: 'Failed', value: '${summary.failed}'),
            _MetricRow(label: 'Pending', value: '${summary.pending}'),
            _MetricRow(
              label: 'Lot drop-offs pending',
              value: '${summary.lotDropoffsPending}',
            ),
            if (summary.durationLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              _MetricRow(
                label: summary.durationCaption,
                value: summary.durationLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.black87, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

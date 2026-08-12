import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../widgets/app_multi_select_field.dart';
import '../../delivery_tracking/delivery_tracking_models.dart';
import '../../trip_dashboard/trip_dashboard_helpers.dart';

/// Optional related-invoice picker for customer complaint / raise-for-customer.
///
/// Loads flat docs from [GET doc/customer-deliveries] (docDate desc).
/// Pass [customerId] for employee on-behalf; omit for customer JWT.
class TicketRelatedInvoiceField extends StatefulWidget {
  const TicketRelatedInvoiceField({
    super.key,
    required this.apiClient,
    required this.selectedDocId,
    required this.onChanged,
    this.customerId,
    this.requireCustomerId = false,
    this.enabled = true,
  });

  final ApiClient apiClient;
  final String? selectedDocId;
  final ValueChanged<String?> onChanged;

  /// When set (employee raise-for-customer), loads that customer's deliveries.
  final String? customerId;

  /// When true, waits until [customerId] is non-empty before loading.
  final bool requireCustomerId;
  final bool enabled;

  @override
  State<TicketRelatedInvoiceField> createState() =>
      _TicketRelatedInvoiceFieldState();
}

class _TicketRelatedInvoiceFieldState extends State<TicketRelatedInvoiceField> {
  Future<List<CustomerDeliverySummary>>? _deliveriesFuture;
  String? _loadedForCustomerId;

  @override
  void initState() {
    super.initState();
    _reloadIfNeeded();
  }

  @override
  void didUpdateWidget(covariant TicketRelatedInvoiceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerId != widget.customerId ||
        oldWidget.requireCustomerId != widget.requireCustomerId) {
      _reloadIfNeeded(force: true);
    }
  }

  void _reloadIfNeeded({bool force = false}) {
    final customerId = widget.customerId?.trim();
    if (widget.requireCustomerId &&
        (customerId == null || customerId.isEmpty)) {
      _deliveriesFuture = null;
      _loadedForCustomerId = null;
      return;
    }
    final cacheKey = widget.requireCustomerId ? customerId : '';
    if (!force &&
        _deliveriesFuture != null &&
        _loadedForCustomerId == cacheKey) {
      return;
    }
    _loadedForCustomerId = cacheKey;
    _deliveriesFuture = widget.apiClient.getCustomerDeliveries(
      customerId: widget.requireCustomerId ? customerId : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerId = widget.customerId?.trim();
    final waitingForCustomer =
        widget.requireCustomerId &&
        (customerId == null || customerId.isEmpty);

    if (waitingForCustomer) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Related invoice (optional)',
          border: OutlineInputBorder(),
        ),
        child: Text(
          'Select a customer first',
          style: TextStyle(
            color: Colors.black54,
            fontSize: Theme.of(context).textTheme.bodyLarge?.fontSize,
          ),
        ),
      );
    }

    return FutureBuilder<List<CustomerDeliverySummary>>(
      future: _deliveriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const InputDecorator(
            decoration: InputDecoration(
              labelText: 'Related invoice (optional)',
              border: OutlineInputBorder(),
            ),
            child: SizedBox(
              height: 24,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Related invoice (optional)',
              border: OutlineInputBorder(),
              errorText: 'Could not load invoices',
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Failed to load invoices',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
                TextButton(
                  onPressed: widget.enabled
                      ? () => setState(() => _reloadIfNeeded(force: true))
                      : null,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final deliveries = snapshot.data ?? const <CustomerDeliverySummary>[];
        final selected = widget.selectedDocId?.trim();
        final selectedSet = selected == null || selected.isEmpty
            ? <String>{}
            : {selected};

        return AppMultiSelectField<String>(
          fieldLabel: 'Related invoice (optional)',
          dialogTitle: 'Select invoice',
          searchLabel: 'Search invoices',
          searchHint: 'Doc ID…',
          emptySelectionText: 'No invoice selected',
          countLabel: 'invoices',
          singleSelect: true,
          selectedValues: selectedSet,
          enabled: widget.enabled,
          emptyItemsMessage: 'No invoices in the last 90 days.',
          items: deliveries
              .map((delivery) {
                final amount = formatInrAmount(delivery.docAmountRaw);
                final dateLabel = _formatDocDate(delivery.docDate);
                final parts = <String>[
                  delivery.docId,
                  if (amount.isNotEmpty) amount,
                  if (dateLabel.isNotEmpty) dateLabel,
                ];
                final subtitleParts = <String>[
                  if (amount.isNotEmpty) amount,
                  if (dateLabel.isNotEmpty) dateLabel,
                ];
                return AppMultiSelectItem<String>(
                  value: delivery.docId,
                  label: parts.join(' · '),
                  searchText: '${delivery.docId} $amount $dateLabel',
                  subtitle: subtitleParts.isEmpty
                      ? null
                      : subtitleParts.join(' · '),
                );
              })
              .toList(),
          onChanged: (values) {
            widget.onChanged(values.isEmpty ? null : values.first);
          },
        );
      },
    );
  }
}

String _formatDocDate(DateTime? docDate) {
  if (docDate == null) return '';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  // docDate is typically a calendar date; use IST day for year comparison.
  final ist = docDate.toUtc().add(const Duration(hours: 5, minutes: 30));
  final nowIst = DateTime.now().toUtc().add(
    const Duration(hours: 5, minutes: 30),
  );
  final month = months[ist.month - 1];
  if (ist.year == nowIst.year) {
    return '$month ${ist.day}';
  }
  return '$month ${ist.day} ${ist.year}';
}

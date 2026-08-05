import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../utils/doc_tracking_url.dart';
import '../../utils/open_external_url.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../public_tracking/public_tracking_helpers.dart';
import '../reports/delivery_report/widgets/delivery_report_dialogs.dart';
import '../trip_dashboard/trip_dashboard_helpers.dart';
import 'delivery_tracking_models.dart';
import 'doc_line_items_dialog.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  const DeliveryTrackingScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  List<CustomerDeliverySummary>? _deliveries;
  Object? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh(showLoading: true));
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_refresh(showLoading: false));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<CustomerDeliverySummary>> _loadDeliveries() {
    return widget.apiClient.getCustomerDeliveries();
  }

  Future<void> _refresh({required bool showLoading}) async {
    if (showLoading && mounted) {
      setState(() {
        _loading = _deliveries == null;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _refreshing = true);
    }

    try {
      final deliveries = await _loadDeliveries();
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
        _error = null;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (_deliveries == null) {
          _error = error;
        }
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _reload() => _refresh(showLoading: _deliveries == null);

  Future<void> _openTracking(String docId) {
    return openUrlInNewTab(buildDocTrackingUrl(docId));
  }

  Future<void> _openLineItems(String docId) {
    return showDocLineItemsDialog(
      context: context,
      apiClient: widget.apiClient,
      docId: docId,
      onLoginAgain: widget.onLoginAgain,
    );
  }

  Future<void> _viewSignature(String docId) async {
    try {
      final details = await widget.apiClient.getDocDeliveryStatus(docId: docId);
      if (!mounted) return;
      if (details.signature.trim().isEmpty) return;
      await showDeliveryReportSignatureDialog(
        context: context,
        docId: docId,
        signatureBase64: details.signature,
        lastUpdatedAt: details.deliveredAt,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _viewComment(String docId) async {
    try {
      final details = await widget.apiClient.getDocDeliveryStatus(docId: docId);
      if (!mounted) return;
      if (details.comment.trim().isEmpty) return;
      await showDeliveryReportCommentDialog(
        context: context,
        docId: docId,
        comment: details.comment,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Delivery Tracking'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : () => _refresh(showLoading: false),
            icon: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(primary),
    );
  }

  Widget _buildBody(Color primary) {
    if (_loading && _deliveries == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _deliveries == null) {
      return AppLoadErrorState(
        title: 'Could not load deliveries',
        message: _error.toString(),
        onRetry: _reload,
        onLoginAgain: widget.onLoginAgain,
      );
    }

    final deliveries = _deliveries ?? const [];
    if (deliveries.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(showLoading: false),
        child: AppScrollbar(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: AppSurface(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.inventory_2_outlined, size: 40),
                              SizedBox(height: 12),
                              Text(
                                'No deliveries found',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Deliveries from the last 90 days will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final tripGroups = groupCustomerDeliveriesByTrip(deliveries);
    final hasTripGrouping = deliveries.any((delivery) => delivery.tripId != null);

    return RefreshIndicator(
      onRefresh: () => _refresh(showLoading: false),
      child: AppScrollbar(
        controller: _scrollController,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: (hasTripGrouping ? tripGroups.length : deliveries.length) + 1,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'Deliveries from the last 90 days',
                    style: TextStyle(
                      color: AppTheme.primaryAccentText(primary),
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
                if (hasTripGrouping) {
                  final group = tripGroups[index - 1];
                  return _TripDeliveryGroup(
                    group: group,
                    primary: primary,
                    onViewInvoice: _openLineItems,
                    onViewSignature: _viewSignature,
                    onViewComment: _viewComment,
                    onTrack: _openTracking,
                  );
                }
                final delivery = deliveries[index - 1];
                return _DeliveryCard(
                  delivery: delivery,
                  primary: primary,
                  onViewInvoice: () => _openLineItems(delivery.docId),
                  onViewSignature: delivery.isDelivered
                      ? () => _viewSignature(delivery.docId)
                      : null,
                  onViewComment: delivery.isUndelivered
                      ? () => _viewComment(delivery.docId)
                      : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDeliveryGroup extends StatelessWidget {
  const _TripDeliveryGroup({
    required this.group,
    required this.primary,
    required this.onViewInvoice,
    required this.onViewSignature,
    required this.onViewComment,
    required this.onTrack,
  });

  final CustomerDeliveryTripGroup group;
  final Color primary;
  final Future<void> Function(String docId) onViewInvoice;
  final Future<void> Function(String docId) onViewSignature;
  final Future<void> Function(String docId) onViewComment;
  final Future<void> Function(String docId) onTrack;

  String _groupTitle() {
    if (group.hasTripId) {
      final countLabel = group.invoiceCount == 1
          ? '1 invoice'
          : '${group.invoiceCount} invoices';
      return 'Trip #${group.tripId} · $countLabel';
    }
    return 'Invoice';
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_shipping_outlined, color: primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _groupTitle(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => onTrack(group.trackingDocId),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Track delivery'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                minimumSize: const Size(double.infinity, 40),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < group.deliveries.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _DeliveryCard(
                delivery: group.deliveries[index],
                primary: primary,
                nested: group.invoiceCount > 1,
                onViewInvoice: () =>
                    onViewInvoice(group.deliveries[index].docId),
                onViewSignature: group.deliveries[index].isDelivered
                    ? () => onViewSignature(group.deliveries[index].docId)
                    : null,
                onViewComment: group.deliveries[index].isUndelivered
                    ? () => onViewComment(group.deliveries[index].docId)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.delivery,
    required this.primary,
    required this.onViewInvoice,
    this.onViewSignature,
    this.onViewComment,
    this.nested = false,
  });

  final CustomerDeliverySummary delivery;
  final Color primary;
  final VoidCallback onViewInvoice;
  final VoidCallback? onViewSignature;
  final VoidCallback? onViewComment;
  final bool nested;

  static final _actionStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  );

  @override
  Widget build(BuildContext context) {
    final status = publicTrackingStatusDisplay(delivery.status);
    final amount = formatInrAmount(delivery.docAmountRaw);

    final card = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                delivery.docId,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (amount.isNotEmpty)
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              _StatusChip(status: status),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onViewInvoice,
                style: _actionStyle,
                child: Text(
                  'View Invoice',
                  style: TextStyle(color: primary),
                ),
              ),
              if (onViewSignature != null)
                TextButton(
                  onPressed: onViewSignature,
                  style: _actionStyle,
                  child: Text(
                    'View Signature',
                    style: TextStyle(color: primary),
                  ),
                )
              else if (onViewComment != null)
                TextButton(
                  onPressed: onViewComment,
                  style: _actionStyle,
                  child: Text(
                    'View Comment',
                    style: TextStyle(color: primary),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (!nested) {
      return AppSurface(
        borderRadius: 16,
        child: card,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
        color: primary.withValues(alpha: 0.04),
      ),
      child: card,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PublicTrackingStatusDisplay status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 14, color: status.color),
            const SizedBox(width: 4),
            Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

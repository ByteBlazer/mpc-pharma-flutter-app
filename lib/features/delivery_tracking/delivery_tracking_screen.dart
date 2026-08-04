import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../utils/doc_tracking_url.dart';
import '../../utils/open_external_url.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../public_tracking/public_tracking_helpers.dart';
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
  final _loader = AppAsyncListLoader<List<CustomerDeliverySummary>>();

  @override
  void initState() {
    super.initState();
    _loader.initialize(_loadDeliveries);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<CustomerDeliverySummary>> _loadDeliveries() {
    return widget.apiClient.getCustomerDeliveries();
  }

  Future<void> _reload() {
    return _loader.reload(load: _loadDeliveries, setState: setState);
  }

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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppScreenScaffold(
      appBar: AppBar(title: const Text('Delivery Tracking')),
      body: FutureBuilder<List<CustomerDeliverySummary>>(
        future: _loader.future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppLoadErrorState(
              title: 'Could not load deliveries',
              message: snapshot.error.toString(),
              onRetry: _reload,
              onLoginAgain: widget.onLoginAgain,
            );
          }

          final deliveries = snapshot.data ?? const [];
          if (deliveries.isEmpty) {
            return Center(
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
            );
          }

          final tripGroups = groupCustomerDeliveriesByTrip(deliveries);
          final hasTripGrouping = deliveries.any((delivery) => delivery.tripId != null);

          return RefreshIndicator(
            onRefresh: _reload,
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
                          onOpenLineItems: _openLineItems,
                          onTrack: _openTracking,
                        );
                      }
                      final delivery = deliveries[index - 1];
                      return _DeliveryCard(
                        delivery: delivery,
                        primary: primary,
                        onOpenLineItems: () => _openLineItems(delivery.docId),
                        onTrack: () => _openTracking(delivery.docId),
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TripDeliveryGroup extends StatelessWidget {
  const _TripDeliveryGroup({
    required this.group,
    required this.primary,
    required this.onOpenLineItems,
    required this.onTrack,
  });

  final CustomerDeliveryTripGroup group;
  final Color primary;
  final Future<void> Function(String docId) onOpenLineItems;
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
              onPressed: () => onTrack(group.deliveries.first.docId),
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
                onOpenLineItems: () =>
                    onOpenLineItems(group.deliveries[index].docId),
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
    required this.onOpenLineItems,
    this.onTrack,
    this.nested = false,
  });

  final CustomerDeliverySummary delivery;
  final Color primary;
  final VoidCallback onOpenLineItems;
  final VoidCallback? onTrack;
  final bool nested;

  @override
  Widget build(BuildContext context) {
    final status = publicTrackingStatusDisplay(delivery.status);
    final amount = formatInrAmount(delivery.docAmountRaw);

    final card = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  delivery.docId,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.expand_more,
                color: primary.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StatusChip(status: status),
              if (amount.isNotEmpty)
                Text(
                  amount,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          if (onTrack != null) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onTrack,
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
          ] else
            const SizedBox(height: 10),
          const SizedBox(height: 4),
          Text(
            'Tap for line items',
            style: TextStyle(
              color: AppTheme.primaryAccentText(primary),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (!nested) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpenLineItems,
          borderRadius: BorderRadius.circular(16),
          child: AppSurface(
            borderRadius: 16,
            child: card,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenLineItems,
        borderRadius: BorderRadius.circular(12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primary.withValues(alpha: 0.18)),
            color: primary.withValues(alpha: 0.04),
          ),
          child: card,
        ),
      ),
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

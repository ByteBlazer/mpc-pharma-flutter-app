import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';
import '../../../core/providers/providers.dart';
import 'portal_map_marker.dart';

class PortalCustomerInfoPanel extends ConsumerStatefulWidget {
  const PortalCustomerInfoPanel({
    super.key,
    required this.marker,
    required this.onClose,
  });

  final PortalMapMarker marker;
  final VoidCallback onClose;

  @override
  ConsumerState<PortalCustomerInfoPanel> createState() =>
      _PortalCustomerInfoPanelState();
}

class _PortalCustomerInfoPanelState
    extends ConsumerState<PortalCustomerInfoPanel> {
  int _docIndex = 0;
  late Future<List<_DocDetail>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void didUpdateWidget(PortalCustomerInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marker.id != widget.marker.id) {
      _docIndex = 0;
      _loadDetails();
    }
  }

  void _loadDetails() {
    _detailsFuture = _fetchDocDetails();
  }

  Future<List<_DocDetail>> _fetchDocDetails() async {
    final api = ref.read(apiClientProvider);
    final docs = widget.marker.customerDocs;
    if (docs.isEmpty) return [];

    final results = <_DocDetail>[];
    for (final doc in docs) {
      WebPortalDeliveryStatusResponse? delivery;
      if (doc.status == AppConstants.docStatusDelivered ||
          doc.status == AppConstants.docStatusUndelivered) {
        try {
          delivery = await api.getDocDeliveryStatus(doc.id);
          if (!delivery.success) delivery = null;
        } catch (_) {
          delivery = null;
        }
      }
      results.add(_DocDetail(doc: doc, delivery: delivery));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.marker.customerInfo;
    if (info == null) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<_DocDetail>>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(info),
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Loading customer documents...'),
                ],
              );
            }

            final details = snapshot.data ?? [];
            if (details.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(info),
                  const Text(
                    'No document information available for this customer.',
                  ),
                ],
              );
            }

            final current = details[_docIndex.clamp(0, details.length - 1)];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: _header(info)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onClose,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: details.length <= 1
                          ? null
                          : () => setState(() {
                                _docIndex = (_docIndex - 1 + details.length) %
                                    details.length;
                              }),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Doc ${_docIndex + 1} of ${details.length}'),
                    IconButton(
                      onPressed: details.length <= 1
                          ? null
                          : () => setState(() {
                                _docIndex = (_docIndex + 1) % details.length;
                              }),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                _DocSlide(
                  detail: current,
                  trackingUrl: PortalTripMapLogic.generateTrackingUrl(
                    current.doc.id,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header(PortalCustomerInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.firmName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          'Address: ${info.address}, ${info.city}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
        Text(
          'Phone: ${info.phone}',
          style: const TextStyle(fontSize: 13, color: Colors.black54),
        ),
      ],
    );
  }
}

class _DocDetail {
  _DocDetail({required this.doc, this.delivery});

  final WebPortalDoc doc;
  final WebPortalDeliveryStatusResponse? delivery;
}

class _DocSlide extends StatelessWidget {
  const _DocSlide({required this.detail, required this.trackingUrl});

  final _DocDetail detail;
  final String trackingUrl;

  Color _statusColor(String status) {
    return switch (status) {
      AppConstants.docStatusDelivered => Colors.green,
      AppConstants.docStatusUndelivered => Colors.red,
      AppConstants.docStatusOnTrip => Colors.blue,
      'AT_TRANSIT_HUB' => Colors.orange,
      _ => Colors.grey,
    };
  }

  String _statusText(WebPortalDoc doc, WebPortalDeliveryStatusResponse? d) {
    final deliveredAt = d?.deliveredAt;
    if ((doc.status == AppConstants.docStatusDelivered ||
            doc.status == AppConstants.docStatusUndelivered) &&
        deliveredAt != null) {
      final now = DateTime.now();
      final local = deliveredAt.toLocal();
      final isToday = local.year == now.year &&
          local.month == now.month &&
          local.day == now.day;
      final timeStr = DateFormat('h:mm a').format(local);
      final label = doc.status == AppConstants.docStatusUndelivered
          ? 'DELIVERY FAILED'
          : 'DELIVERED';
      if (isToday) return '$label at $timeStr today';
      final dateStr = DateFormat('MMM d').format(local);
      return '$label at $timeStr on $dateStr';
    }
    return WebPortalUtilsDocStatus.label(doc.status);
  }

  String? _formatAmount(String? amount) {
    if (amount == null || amount.trim().isEmpty) return null;
    final n = num.tryParse(amount);
    if (n != null) return '₹${NumberFormat('#,##,###').format(n)}';
    return amount.startsWith('₹') ? amount : '₹$amount';
  }

  @override
  Widget build(BuildContext context) {
    final doc = detail.doc;
    final delivery = detail.delivery;
    final amount = _formatAmount(doc.docAmount);
    final docComment =
        doc.comment != null && doc.comment!.trim().isNotEmpty ? doc.comment : null;
    final deliveryComment = delivery?.comment != null &&
            delivery!.comment!.trim().isNotEmpty
        ? delivery.comment
        : null;
    final signature = delivery?.signature;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Doc ID: ${doc.id}'),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Status: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: _statusText(doc, delivery),
                style: TextStyle(
                  color: _statusColor(doc.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (amount != null) Text('Amount: $amount'),
        if (docComment != null) Text('Note: $docComment'),
        if (signature != null && signature.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Delivery Signature:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Image.memory(
            base64Decode(signature),
            height: 70,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text('Invalid signature image'),
          ),
        ],
        if (deliveryComment != null) ...[
          const SizedBox(height: 8),
          const Text(
            'Delivery Comment:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(deliveryComment, style: const TextStyle(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 8),
        const Text(
          'Tracking URL:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Expanded(
              child: SelectableText(
                trackingUrl,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: trackingUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tracking URL copied')),
                );
              },
              child: const Text('Copy'),
            ),
          ],
        ),
      ],
    );
  }
}

class WebPortalUtilsDocStatus {
  static String label(String status) {
    return switch (status) {
      AppConstants.docStatusUndelivered => 'DELIVERY FAILED',
      AppConstants.docStatusDelivered => 'DELIVERED',
      AppConstants.docStatusOnTrip => 'On Trip',
      'AT_TRANSIT_HUB' => 'At Transit Hub',
      'TRIP_SCHEDULED' => 'Trip Scheduled',
      'READY_FOR_DISPATCH' => 'Ready for Dispatch',
      _ => status,
    };
  }
}

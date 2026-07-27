import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../utils/doc_tracking_url.dart';
import '../../utils/open_external_url.dart';
import '../../utils/signature_image.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import '../my_trips/my_trips_models.dart';
import 'trip_dashboard_helpers.dart';
import 'trip_dashboard_models.dart';

class CustomerDeliveryCallout extends StatefulWidget {
  const CustomerDeliveryCallout({
    super.key,
    required this.docs,
    required this.apiClient,
    required this.onClose,
  });

  final List<TripDoc> docs;
  final ApiClient apiClient;
  final VoidCallback onClose;

  @override
  State<CustomerDeliveryCallout> createState() =>
      _CustomerDeliveryCalloutState();
}

class _DeliveryLoadState {
  DeliveryStatusDetails? details;
  String? error;
  bool loading = false;
}

class _CustomerDeliveryCalloutState extends State<CustomerDeliveryCallout> {
  int _docIndex = 0;
  final _deliveryState = <String, _DeliveryLoadState>{};

  TripDoc get _currentDoc => widget.docs[_docIndex];

  @override
  void initState() {
    super.initState();
    _preloadDeliveryStatuses();
  }

  @override
  void didUpdateWidget(covariant CustomerDeliveryCallout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.docs.map((d) => d.id).join(',');
    final newIds = widget.docs.map((d) => d.id).join(',');
    if (oldIds != newIds) {
      _docIndex = 0;
      _deliveryState.clear();
      _preloadDeliveryStatuses();
    }
  }

  void _preloadDeliveryStatuses() {
    for (final doc in widget.docs) {
      if (doc.isDelivered || doc.isUndelivered) {
        _loadDeliveryStatus(doc);
      }
    }
  }

  Future<void> _loadDeliveryStatus(TripDoc doc) async {
    final existing = _deliveryState[doc.id];
    if (existing != null &&
        (existing.loading ||
            existing.details != null ||
            existing.error != null)) {
      return;
    }

    setState(() {
      _deliveryState[doc.id] = _DeliveryLoadState()..loading = true;
    });

    try {
      final result = await widget.apiClient.getDocDeliveryStatus(docId: doc.id);
      if (!mounted) return;
      if (!result.success) {
        setState(() {
          _deliveryState[doc.id] = _DeliveryLoadState()
            ..error = result.message.isEmpty
                ? 'Could not load delivery details.'
                : result.message;
        });
        return;
      }
      setState(() {
        _deliveryState[doc.id] = _DeliveryLoadState()..details = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _deliveryState[doc.id] = _DeliveryLoadState()..error = error.toString();
      });
    }
  }

  void _goToDoc(int index) {
    if (index < 0 || index >= widget.docs.length) return;
    setState(() => _docIndex = index);
    _loadDeliveryStatus(_currentDoc);
  }

  Future<void> _copyTrackingUrl(String docId) async {
    final url = buildDocTrackingUrl(docId);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: 'Tracking link copied',
      type: AppSnackBarType.success,
    );
  }

  Future<void> _openTrackingPage(String docId) async {
    await openUrlInNewTab(buildDocTrackingUrl(docId));
  }

  @override
  Widget build(BuildContext context) {
    final doc = _currentDoc;
    final rep = widget.docs.first;
    final loadState = _deliveryState[doc.id];
    final addressParts = <String>[
      if (rep.customerAddress.trim().isNotEmpty) rep.customerAddress.trim(),
      if (rep.customerCity.trim().isNotEmpty) rep.customerCity.trim(),
    ];

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: AppSurface(
        borderRadius: 16,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rep.customerFirmName.trim().isEmpty
                            ? 'Customer'
                            : rep.customerFirmName.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
                if (addressParts.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    addressParts.join(', '),
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                  ),
                ],
                if (rep.customerPhone.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Phone: ${rep.customerPhone.trim()}',
                    style: const TextStyle(color: Colors.black, fontSize: 13),
                  ),
                ],
                const Divider(height: 20),
                if (widget.docs.isEmpty)
                  const Text('No document information available.')
                else ...[
                  if (widget.docs.length > 1) ...[
                    Row(
                      children: [
                        IconButton(
                          onPressed: _docIndex > 0
                              ? () => _goToDoc(_docIndex - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            'Doc ${_docIndex + 1} of ${widget.docs.length}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: _docIndex < widget.docs.length - 1
                              ? () => _goToDoc(_docIndex + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ],
                  _DocDetailsSection(
                    doc: doc,
                    delivery: loadState?.details,
                    loadingDelivery: loadState?.loading ?? false,
                    deliveryError: loadState?.error,
                    onCopyTracking: () => _copyTrackingUrl(doc.id),
                    onOpenTracking: () => _openTrackingPage(doc.id),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocDetailsSection extends StatelessWidget {
  const _DocDetailsSection({
    required this.doc,
    required this.delivery,
    required this.loadingDelivery,
    required this.deliveryError,
    required this.onCopyTracking,
    required this.onOpenTracking,
  });

  final TripDoc doc;
  final DeliveryStatusDetails? delivery;
  final bool loadingDelivery;
  final String? deliveryError;
  final VoidCallback onCopyTracking;
  final VoidCallback onOpenTracking;

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(docStatusColor(doc.status));
    final amount = formatInrAmount(doc.docAmount);
    final isTerminal = doc.isDelivered || doc.isUndelivered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Doc ID: ${doc.id}', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              docStatusLabel(doc.status),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        if (amount.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Amount: $amount', style: const TextStyle(fontSize: 13)),
        ],
        if (doc.comment.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Note: ${doc.comment.trim()}',
            style: const TextStyle(fontSize: 13),
          ),
        ],
        if (isTerminal) ...[
          const SizedBox(height: 10),
          if (loadingDelivery)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (deliveryError != null)
            Text(
              deliveryError!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC62828)),
            )
          else if (delivery != null) ...[
            Text(
              formatDeliveryStatusTimestamp(
                statusLabel: doc.isUndelivered
                    ? 'Delivery failed'
                    : 'Delivered',
                deliveredAt: delivery!.deliveredAt,
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            if (delivery!.comment.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Delivery comment: ${delivery!.comment.trim()}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (doc.isDelivered) ...[
              const SizedBox(height: 8),
              const Text(
                'Signature',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              SignatureImagePreview(signatureBase64: delivery!.signature),
            ],
          ],
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                buildDocTrackingUrl(doc.id),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
              ),
            ),
            IconButton(
              tooltip: 'Copy tracking link',
              onPressed: onCopyTracking,
              icon: const Icon(Icons.copy, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onOpenTracking,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open tracking page'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

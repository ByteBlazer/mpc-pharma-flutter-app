import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/app_constants.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/web_portal_models.dart';
import '../../../core/providers/providers.dart';
import 'portal_map_marker.dart';
import 'portal_map_utils.dart';
import 'portal_signature_image.dart';
import '../web_portal_utils.dart';

class PortalCustomerInfoPanel extends ConsumerStatefulWidget {
  const PortalCustomerInfoPanel({
    super.key,
    required this.marker,
    required this.onClose,
    this.onLayoutChanged,
  });

  /// Matches React InfoWindow width; wide enough for tracking URL on one line.
  static const panelWidth = 400.0;

  final PortalMapMarker marker;
  final VoidCallback onClose;
  final VoidCallback? onLayoutChanged;

  @override
  ConsumerState<PortalCustomerInfoPanel> createState() =>
      _PortalCustomerInfoPanelState();
}

class _PortalCustomerInfoPanelState
    extends ConsumerState<PortalCustomerInfoPanel> {
  int _docIndex = 0;
  List<_DocDetail> _details = const [];
  int _enrichGeneration = 0;

  static const _bodyStyle = TextStyle(fontSize: 14, color: Color(0xFF333333));
  static const _mutedStyle = TextStyle(fontSize: 13, color: Color(0xFF666666));
  static const _labelStyle = TextStyle(fontWeight: FontWeight.bold);

  @override
  void initState() {
    super.initState();
    _resetDetails();
    _enrichDetails();
  }

  @override
  void didUpdateWidget(PortalCustomerInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.marker.id != widget.marker.id) {
      setState(_resetDetails);
      _enrichDetails();
    }
  }

  void _resetDetails() {
    _docIndex = 0;
    _details = widget.marker.customerDocs
        .map((doc) => _DocDetail(doc: doc))
        .toList();
  }

  void _notifyLayoutChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onLayoutChanged?.call();
    });
  }

  /// Trip detail already includes doc metadata; fetch delivery extras in parallel
  /// (same as React TripDashboard — one delivery-status call per doc, no blocking UI).
  Future<void> _enrichDetails() async {
    final docs = widget.marker.customerDocs;
    if (docs.isEmpty) return;

    final generation = ++_enrichGeneration;
    final api = ref.read(apiClientProvider);
    final enriched = await Future.wait(
      docs.map((doc) => _fetchDocDetail(api, doc)),
    );

    if (!mounted || generation != _enrichGeneration) return;
    setState(() => _details = enriched);
    _notifyLayoutChanged();
  }

  Future<_DocDetail> _fetchDocDetail(
    ApiClient api,
    WebPortalDoc doc,
  ) async {
    WebPortalDeliveryStatusResponse? delivery;
    if (doc.status == AppConstants.docStatusDelivered ||
        doc.status == AppConstants.docStatusUndelivered) {
      try {
        delivery = await api.getDocDeliveryStatus(doc.id);
        if (!delivery.success) delivery = null;
      } catch (e) {
        debugPrint('delivery-status failed for ${doc.id}: $e');
        delivery = null;
      }
    }

    final signature = await _resolveSignature(api, doc, delivery);
    return _DocDetail(doc: doc, delivery: delivery, signature: signature);
  }

  /// React TripDashboard uses signature from delivery-status only; fall back to
  /// doc/signature when the delivery payload omits it.
  Future<String?> _resolveSignature(
    ApiClient api,
    WebPortalDoc doc,
    WebPortalDeliveryStatusResponse? delivery,
  ) async {
    if (doc.status != AppConstants.docStatusDelivered) return null;

    final fromDelivery = normalizePortalBase64Image(delivery?.signature);
    if (fromDelivery != null) return fromDelivery;

    try {
      final sig = await api.getDocSignature(doc.id);
      return normalizePortalBase64Image(sig.signature);
    } catch (e) {
      debugPrint('doc/signature failed for ${doc.id}: $e');
      return null;
    }
  }

  void _goToDoc(int delta) {
    if (_details.length <= 1) return;
    setState(() {
      _docIndex = (_docIndex + delta + _details.length) % _details.length;
    });
    _notifyLayoutChanged();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.marker.customerInfo;
    if (info == null) return const SizedBox.shrink();

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(4),
      color: Colors.white,
      child: Container(
        width: PortalCustomerInfoPanel.panelWidth,
        padding: const EdgeInsets.all(12),
        child: _details.isEmpty
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _headerWithClose(info),
                  const Text(
                    'No document information available for this customer.',
                    style: _mutedStyle,
                  ),
                ],
              )
            : _buildLoadedContent(info),
      ),
    );
  }

  Widget _buildLoadedContent(PortalCustomerInfo info) {
    final current = _details[_docIndex.clamp(0, _details.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _headerWithClose(info),
        _docNavigation(_details.length),
        _DocSlide(
          key: ValueKey(current.doc.id),
          detail: current,
          trackingUrl: PortalTripMapLogic.generateTrackingUrl(current.doc.id),
        ),
      ],
    );
  }

  /// Matches the native Google Maps InfoWindow × close control.
  Widget _headerWithClose(PortalCustomerInfo info) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _header(info)),
        _CloseButton(onPressed: widget.onClose),
      ],
    );
  }

  Widget _header(PortalCustomerInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.firmName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: _mutedStyle,
            children: [
              const TextSpan(text: 'Address: ', style: _labelStyle),
              TextSpan(text: '${info.address}, ${info.city}'),
            ],
          ),
        ),
        Text.rich(
          TextSpan(
            style: _mutedStyle,
            children: [
              const TextSpan(text: 'Phone: ', style: _labelStyle),
              TextSpan(text: info.phone),
            ],
          ),
        ),
      ],
    );
  }

  Widget _docNavigation(int total) {
    final disabled = total <= 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CarouselButton(
            label: '◀',
            enabled: !disabled,
            onPressed: () => _goToDoc(-1),
          ),
          Text(
            'Doc ${_docIndex + 1} of $total',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
          _CarouselButton(
            label: '▶',
            enabled: !disabled,
            onPressed: () => _goToDoc(1),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Text(
              '×',
              style: TextStyle(
                fontSize: 22,
                height: 1,
                color: Color(0xFF666666),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarouselButton extends StatelessWidget {
  const _CarouselButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE0E0E0),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
            ),
          ),
        ),
      ),
    );
  }
}

class _DocDetail {
  _DocDetail({required this.doc, this.delivery, this.signature});

  final WebPortalDoc doc;
  final WebPortalDeliveryStatusResponse? delivery;
  final String? signature;
}

class _DocSlide extends StatelessWidget {
  const _DocSlide({
    super.key,
    required this.detail,
    required this.trackingUrl,
  });

  final _DocDetail detail;
  final String trackingUrl;

  Color _statusColor(String status) => WebPortalUtils.docStatusColor(status);

  String _statusText(WebPortalDoc doc, WebPortalDeliveryStatusResponse? d) {
    if ((doc.status == AppConstants.docStatusDelivered ||
            doc.status == AppConstants.docStatusUndelivered) &&
        d?.deliveredAt != null) {
      return WebPortalUtils.formatDeliveryStatusTimestamp(
        doc.status,
        d!.deliveredAt,
      );
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
    final showSignature = doc.status == AppConstants.docStatusDelivered &&
        detail.signature != null &&
        detail.signature!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: _PortalCustomerInfoPanelState._bodyStyle,
            children: [
              const TextSpan(
                text: 'Doc ID: ',
                style: _PortalCustomerInfoPanelState._labelStyle,
              ),
              TextSpan(text: doc.id),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            style: _PortalCustomerInfoPanelState._bodyStyle,
            children: [
              const TextSpan(
                text: 'Status: ',
                style: _PortalCustomerInfoPanelState._labelStyle,
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
        if (amount != null) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: _PortalCustomerInfoPanelState._mutedStyle,
              children: [
                const TextSpan(
                  text: 'Amount: ',
                  style: _PortalCustomerInfoPanelState._labelStyle,
                ),
                TextSpan(text: amount),
              ],
            ),
          ),
        ],
        if (docComment != null) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: _PortalCustomerInfoPanelState._mutedStyle,
              children: [
                const TextSpan(
                  text: 'Note: ',
                  style: _PortalCustomerInfoPanelState._labelStyle,
                ),
                TextSpan(text: docComment),
              ],
            ),
          ),
        ],
        if (showSignature) ...[
          const SizedBox(height: 12),
          PortalSignatureImage(base64Signature: detail.signature),
        ],
        if (deliveryComment != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Delivery Comment:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF666666),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              deliveryComment,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFEEEEEE)),
        const SizedBox(height: 8),
        const Text(
          'Tracking URL:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Expanded(
              child: TextFormField(
                key: ValueKey(trackingUrl),
                initialValue: trackingUrl,
                readOnly: true,
                style: const TextStyle(fontSize: 12, height: 1.2),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFFCCCCCC)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Material(
                color: const Color(0xFF1976D2),
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: trackingUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tracking URL copied')),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Center(
                      child: Text(
                        'Copy',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          ),
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

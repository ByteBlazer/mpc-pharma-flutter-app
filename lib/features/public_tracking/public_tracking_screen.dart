import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/web_tab_visibility.dart';
import '../../utils/signature_image.dart';
import '../../widgets/app_brand_panel.dart';
import '../trip_dashboard/trip_dashboard_models.dart';
import 'public_tracking_helpers.dart';
import 'public_tracking_map.dart';
import 'public_tracking_models.dart';
import 'public_tracking_trip_documents.dart';

class PublicTrackingScreen extends StatefulWidget {
  const PublicTrackingScreen({super.key, this.token, ApiClient? apiClient})
    : _apiClient = apiClient;

  final String? token;
  final ApiClient? _apiClient;

  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  late final ApiClient _apiClient = widget._apiClient ?? ApiClient();
  late final bool _ownsApiClient = widget._apiClient == null;

  DocTrackingResponse? _tracking;
  DeliveryStatusDetails? _deliveryStatus;
  Object? _error;
  bool _loading = true;
  Timer? _pollTimer;
  StreamSubscription<bool>? _visibilitySub;
  bool _tabVisible = true;
  bool _pausePollingOnHidden = false;

  String? get _token => widget.token?.trim();

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _pausePollingOnHidden = isMobileWebViewport;
      _visibilitySub = webTabVisibilityStream().listen((visible) {
        if (!mounted) return;
        setState(() => _tabVisible = visible);
      });
    }
    unawaited(_refresh(showLoading: true));
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_shouldPoll) return;
      unawaited(_refresh(showLoading: false));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _visibilitySub?.cancel();
    if (_ownsApiClient) {
      _apiClient.close();
    }
    super.dispose();
  }

  bool get _shouldPoll {
    if (_pausePollingOnHidden && !_tabVisible) return false;
    return true;
  }

  Future<void> _refresh({required bool showLoading}) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = const DocTrackingException(
          'Invalid tracking link: No token provided',
        );
      });
      return;
    }

    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final tracking = await _apiClient.getDocTracking(token: token);
      DeliveryStatusDetails? deliveryStatus;
      if (tracking.isTerminal) {
        deliveryStatus = await _apiClient.getDocDeliveryStatusPublic(
          token: token,
        );
      }

      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _deliveryStatus = deliveryStatus;
        _error = null;
        _loading = false;
      });
    } on DocTrackingException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Delivery tracking is available on the web at mpcpharma.in/track.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (_loading && _tracking == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading tracking information...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _tracking == null) {
      final message = _error is DocTrackingException
          ? _error.toString()
          : 'Failed to load tracking information';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(message, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tracking = _tracking!;
    final status = publicTrackingStatusDisplay(tracking.status);
    final amount = formatPublicTrackingAmount(tracking.docAmountRaw);
    final customerName = tracking.customerFirmName.trim();
    final customerAddressLine = tracking.customerAddressLine;
    final showDeliveringTo = customerName.isNotEmpty || customerAddressLine.isNotEmpty;
    final tripDocuments = tracking.allTripDocuments;
    final showTripDocuments = tracking.hasOtherTripDocuments;
    final showTrackingComment =
        !showTripDocuments &&
        tracking.comment.trim().isNotEmpty &&
        !(tracking.isTerminal && _deliveryStatus != null);
    final mapMessage = publicTrackingMapMessage(
      status: tracking.status,
      hasMap: tracking.hasMap,
    );

    return Scaffold(
      body: Column(
        children: [
          Material(
            elevation: 3,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'Delivery Tracking',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          avatar: Icon(
                            status.icon,
                            color: status.color,
                            size: 18,
                          ),
                          label: Text(status.label),
                          side: BorderSide(
                            color: status.color.withValues(alpha: 0.4),
                          ),
                          backgroundColor: status.color.withValues(alpha: 0.08),
                        ),
                      ],
                    ),
                    if (showTripDocuments) ...[
                      const SizedBox(height: 8),
                      PublicTrackingTripDocuments(documents: tripDocuments),
                    ] else if (tracking.docId.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                          children: [
                            const TextSpan(
                              text: 'Invoice: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: tracking.docId),
                            if (amount.isNotEmpty) ...[
                              const TextSpan(text: ' — '),
                              TextSpan(
                                text: amount,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (showDeliveringTo) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                          children: [
                            const TextSpan(
                              text: 'Delivering To: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (customerName.isNotEmpty)
                              TextSpan(text: customerName),
                            if (customerAddressLine.isNotEmpty)
                              TextSpan(
                                text: customerName.isNotEmpty
                                    ? ' $customerAddressLine'
                                    : customerAddressLine,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: Colors.black54),
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (showTrackingComment) ...[
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                          children: [
                            const TextSpan(
                              text: 'Note: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: tracking.comment.trim()),
                          ],
                        ),
                      ),
                    ],
                    if (tracking.deliveryTimestamp != null) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.black54),
                          children: [
                            const TextSpan(
                              text: 'Delivered at: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: formatPublicTrackingInstant(
                                tracking.deliveryTimestamp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (tracking.driverLastKnownLocation?.receivedAt !=
                        null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Driver location updated: ${formatPublicTrackingDriverUpdate(tracking.driverLastKnownLocation!.receivedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (!tracking.isTerminal) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Estimated Delivery Time:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatPublicTrackingEta(tracking.eta, tracking.status),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: tracking.eta == -1
                              ? const Color(0xFFFF9800)
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    if (tracking.numEnrouteCustomers > 0) ...[
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                          children: [
                            TextSpan(
                              text: tracking.numEnrouteCustomers == 1
                                  ? 'The driver has 1 delivery before reaching you. Actual time may be longer than estimated.'
                                  : 'The driver has ${tracking.numEnrouteCustomers} other deliveries before reaching you. Actual time may be longer than estimated.',
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (tracking.isTerminal && _deliveryStatus != null) ...[
                      const SizedBox(height: 12),
                      if (_deliveryStatus!.signature.trim().isNotEmpty) ...[
                        Text(
                          'Delivery Signature:',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 120,
                              maxHeight: 80,
                            ),
                            child: SignatureImagePreview(
                              signatureBase64: _deliveryStatus!.signature,
                              height: 80,
                            ),
                          ),
                        ),
                      ],
                      if (_deliveryStatus!.comment.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Note:',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        AppBrandPanel(
                          child: Text(_deliveryStatus!.comment.trim()),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: tracking.hasMap
                ? PublicTrackingMap(tracking: tracking)
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AppBrandPanel(
                          padding: const EdgeInsets.all(16),
                          textAlign: TextAlign.center,
                          child: Text(mapMessage),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/web_tab_visibility.dart';
import '../../widgets/app_brand_panel.dart';
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
    if (_tracking?.allDocumentsTerminal == true) return false;
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

      if (!mounted) return;
      setState(() {
        _tracking = tracking;
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
    final customerName = tracking.customerFirmName.trim();
    final customerAddressLine = tracking.customerAddressLine;
    final showDeliveringTo =
        customerName.isNotEmpty || customerAddressLine.isNotEmpty;
    final tripDocuments = tracking.allTripDocuments;
    final tripCounts = tracking.tripDocumentCounts;
    final mapMode = resolvePublicTrackingMapMode(tripCounts);
    final showLiveTracking = mapMode == PublicTrackingMapMode.showMap;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = (constraints.maxHeight * 0.55).clamp(
            280.0,
            constraints.maxHeight,
          );
          final mapSection = SizedBox(
            height: mapHeight,
            child: showLiveTracking
                ? tracking.hasMap
                    ? PublicTrackingMap(tracking: tracking)
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: AppBrandPanel(
                              padding: const EdgeInsets.all(16),
                              textAlign: TextAlign.center,
                              child: Text(
                                publicTrackingMapPanelMessage(
                                  PublicTrackingMapMode.showMap,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AppBrandPanel(
                          padding: const EdgeInsets.all(16),
                          textAlign: TextAlign.center,
                          child: Text(publicTrackingMapPanelMessage(mapMode)),
                        ),
                      ),
                    ),
                  ),
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const Text(
                            'Delivery Tracking',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (tripDocuments.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            PublicTrackingTripDocuments(
                              documents: tripDocuments,
                            ),
                          ],
                          if (showDeliveringTo) ...[
                            const SizedBox(height: 12),
                            Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black54),
                                children: [
                                  const TextSpan(
                                    text: 'Delivering To: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (customerName.isNotEmpty)
                                    TextSpan(text: customerName),
                                  if (customerAddressLine.isNotEmpty)
                                    TextSpan(
                                      text: customerName.isNotEmpty
                                          ? ' $customerAddressLine'
                                          : customerAddressLine,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (showLiveTracking &&
                              tracking.driverLastKnownLocation?.receivedAt !=
                                  null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Driver location updated: ${formatPublicTrackingDriverUpdate(tracking.driverLastKnownLocation!.receivedAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.black38,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                          if (tracking.hasPendingTripDocuments) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Estimated Delivery Time:',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatPublicTrackingEta(
                                tracking.eta,
                                tracking.status,
                              ),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: tracking.eta == -1
                                    ? const Color(0xFFFF9800)
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                          if (showLiveTracking &&
                              tracking.hasPendingTripDocuments &&
                              tracking.numEnrouteCustomers > 0) ...[
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
                        ],
                      ),
                    ),
                  ),
                ),
                mapSection,
              ],
            ),
          );
        },
      ),
    );
  }
}

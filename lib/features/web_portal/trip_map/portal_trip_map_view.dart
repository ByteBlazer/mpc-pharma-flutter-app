import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/models/web_portal_models.dart';
import '../web_portal_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../web_portal_styles.dart';
import 'portal_customer_info_panel.dart';
import 'portal_map_marker.dart';
import 'portal_map_overlay.dart';
import 'portal_trip_summary_overlay.dart';

class PortalTripMapView extends StatefulWidget {
  const PortalTripMapView({
    super.key,
    required this.activeTab,
    required this.filteredTrips,
    required this.selectedTripId,
    required this.selectedTrip,
    required this.onTripSelected,
    required this.onClearTripSelection,
    required this.mapHeight,
  });

  final int activeTab;
  final List<WebPortalTrip> filteredTrips;
  final int? selectedTripId;
  final WebPortalTrip? selectedTrip;
  final ValueChanged<int> onTripSelected;
  final VoidCallback onClearTripSelection;
  final double mapHeight;

  @override
  State<PortalTripMapView> createState() => _PortalTripMapViewState();
}

class _PortalTripMapViewState extends State<PortalTripMapView> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _customerIcon;
  PortalMapMarker? _customerPanelMarker;
  Offset? _customerPanelAnchor;
  late final ValueNotifier<bool> _driverBlinkOn;
  Timer? _blinkTimer;
  final _panelMeasureKey = GlobalKey<_PanelHeightReporterState>();
  final _mapStackKey = GlobalKey();
  String? _markerFingerprint;
  Set<Marker>? _cachedMarkers;
  double _lastReportedPanelHeight = 420;
  bool _panelLayoutScheduled = false;

  static const _panelWidth = PortalCustomerInfoPanel.panelWidth;

  /// Initial guess before first layout; updated after measure.
  double _panelHeightEstimate = 420;

  @override
  void initState() {
    super.initState();
    _driverBlinkOn = ValueNotifier(true);
    _loadMarkerIcons();
    _blinkTimer = Timer.periodic(
      PortalTripMapLogic.driverBlinkToggleInterval,
      (_) => _driverBlinkOn.value = !_driverBlinkOn.value,
    );
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _driverBlinkOn.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final driver = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(60, 60)),
        'assets/map/truck-front.png',
      );
      final customer = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(65, 70)),
        'assets/map/customer.png',
      );
      if (!mounted) return;
      setState(() {
        _driverIcon = driver;
        _customerIcon = customer;
        // Map may have built with default pins before assets loaded; rebuild markers.
        _markerFingerprint = null;
        _cachedMarkers = null;
      });
    } catch (e, st) {
      debugPrint('Portal map marker icons failed to load: $e\n$st');
    }
  }

  @override
  void didUpdateWidget(PortalTripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectionChanged = oldWidget.selectedTripId != widget.selectedTripId;
    final detailLoaded = widget.selectedTripId != null &&
        oldWidget.selectedTrip?.docGroups == null &&
        widget.selectedTrip?.docGroups != null;

    if (selectionChanged) {
      _markerFingerprint = null;
      _cachedMarkers = null;
      setState(() {
        _customerPanelMarker = null;
        _customerPanelAnchor = null;
      });
    }

    if (detailLoaded) {
      _markerFingerprint = null;
      _cachedMarkers = null;
    }

    if ((selectionChanged || detailLoaded) && _canFitBounds) {
      _scheduleFitBounds();
    }
  }

  /// Trip list entries lack customer locations; wait for detail before fitting.
  bool get _canFitBounds {
    if (widget.selectedTripId == null) return true;
    return widget.selectedTrip?.docGroups != null;
  }

  void _scheduleFitBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitBounds();
    });
  }

  List<PortalMapMarker> get _portalMarkers {
    if (widget.selectedTripId != null && widget.selectedTrip != null) {
      return PortalTripMapLogic.buildSelectedTripMarkers(widget.selectedTrip!);
    }
    return PortalTripMapLogic.buildDriverMarkers(widget.filteredTrips);
  }

  String _markerDataFingerprint(bool driverBlinkOn) {
    final buf = StringBuffer()
      ..write('sel=${widget.selectedTripId}')
      ..write('|blink=$driverBlinkOn')
      ..write('|icons=${_driverIcon != null}:${_customerIcon != null}');
    for (final pm in _portalMarkers) {
      buf
        ..write('|${pm.id}:')
        ..write(pm.position.latitude)
        ..write(',')
        ..write(pm.position.longitude);
    }
    return buf.toString();
  }

  Set<Marker> _googleMarkers(bool driverBlinkOn) {
    final portalMarkers = _portalMarkers;
    final needsCustomerIcon =
        portalMarkers.any((p) => p.type == PortalMarkerType.customer);

    // Custom assets only — default pins are red/green teardrops, not truck/customer.
    if (_driverIcon == null || (needsCustomerIcon && _customerIcon == null)) {
      return {};
    }

    final fingerprint = _markerDataFingerprint(driverBlinkOn);
    if (fingerprint == _markerFingerprint && _cachedMarkers != null) {
      return _cachedMarkers!;
    }
    _markerFingerprint = fingerprint;

    final driverIcon = _driverIcon!;
    final customerIcon = _customerIcon!;
    final markers = <Marker>{};

    for (final pm in portalMarkers) {
      if (pm.type == PortalMarkerType.driver && !driverBlinkOn) {
        continue;
      }
      final driverClickable = widget.selectedTripId == null;
      markers.add(
        pm.toGoogleMarker(
          driverIcon: driverIcon,
          customerIcon: customerIcon,
          driverClickable: driverClickable,
          onTap: _onMarkerTap,
        ),
      );
    }
    _cachedMarkers = markers;
    return markers;
  }

  Future<void> _showCustomerPanel(PortalMapMarker marker) async {
    try {
      await _mapController?.hideMarkerInfoWindow(MarkerId(marker.id));
    } catch (_) {}
    final anchor = await _anchorForMarker(marker);
    if (!mounted) return;
    setState(() {
      _customerPanelMarker = marker;
      _customerPanelAnchor = anchor;
      _panelHeightEstimate = 420;
      _lastReportedPanelHeight = 420;
    });
  }

  void _closeCustomerPanel() {
    setState(() {
      _customerPanelMarker = null;
      _customerPanelAnchor = null;
      _panelLayoutScheduled = false;
    });
  }

  Future<void> _updateCustomerPanelAnchor() async {
    final marker = _customerPanelMarker;
    if (marker == null) return;
    final anchor = await _anchorForMarker(marker);
    if (!mounted || anchor == null) return;
    final prev = _customerPanelAnchor;
    if (prev != null &&
        (prev.dx - anchor.dx).abs() < 1 &&
        (prev.dy - anchor.dy).abs() < 1) {
      return;
    }
    setState(() => _customerPanelAnchor = anchor);
  }

  Future<Offset?> _anchorForMarker(PortalMapMarker marker) async {
    final controller = _mapController;
    if (controller == null) return null;
    try {
      final screen = await controller.getScreenCoordinate(marker.position);
      return Offset(screen.x.toDouble(), screen.y.toDouble());
    } catch (_) {
      return null;
    }
  }

  void _onMarkerTap(PortalMapMarker marker) {
    if (marker.type == PortalMarkerType.customer && marker.customerInfo != null) {
      _showCustomerPanel(marker);
      return;
    }
    if (marker.type == PortalMarkerType.driver &&
        marker.tripId != null &&
        widget.selectedTripId == null) {
      widget.onTripSelected(marker.tripId!);
    }
  }

  Future<void> _fitBounds() async {
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) return;

    try {
      final bounds = PortalTripMapLogic.boundsFor(_portalMarkers);
      if (!mounted) return;

      if (bounds == null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            const CameraPosition(
              target: PortalTripMapLogic.defaultCenter,
              zoom: 10,
            ),
          ),
        );
        return;
      }
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    } catch (e) {
      debugPrint('Map fitBounds skipped: $e');
    }
  }

  static double _safeClamp(double value, double min, double max) {
    if (max < min) return min;
    return value.clamp(min, max);
  }

  ({double left, double top}) _panelPosition(
    Offset anchor,
    Size mapSize,
    double panelHeight,
  ) {
    const padding = 8.0;
    final effectiveHeight =
        panelHeight.clamp(0.0, (mapSize.height - padding * 2).clamp(0.0, double.infinity));

    // Prefer above the pin (React InfoWindow); flip below if needed.
    var top = anchor.dy - effectiveHeight - 24;
    if (top < padding) {
      top = anchor.dy + 16;
    }
    final maxTop = mapSize.height - effectiveHeight - padding;
    top = _safeClamp(top, padding, maxTop);

    final maxLeft = mapSize.width - _panelWidth - padding;
    final left = _safeClamp(anchor.dx - _panelWidth / 2, padding, maxLeft);

    return (left: left, top: top);
  }

  void _onPanelHeightMeasured(double height) {
    if (!mounted) return;
    final capped = height.clamp(120.0, 520.0);
    if ((_lastReportedPanelHeight - capped).abs() < 2) return;
    _lastReportedPanelHeight = capped;
    if ((_panelHeightEstimate - capped).abs() < 2) return;
    setState(() => _panelHeightEstimate = capped);
  }

  Size _mapStackSize() {
    final box = _mapStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) return box.size;
    return Size.zero;
  }

  @override
  Widget build(BuildContext context) {
    final summary = PortalTripMapLogic.computeTripSummary(widget.selectedTrip);
    final heading = PortalTripMapLogic.mapHeading(
      activeTab: widget.activeTab,
      selectedTripId: widget.selectedTripId,
      selectedTrip: widget.selectedTrip,
    );
    // Match trip dashboard split layout (see WebPortalTripsScreen).
    final isWide = MediaQuery.sizeOf(context).width >= 800;
    final showMapSummary =
        isWide && widget.selectedTripId != null && widget.selectedTrip != null;

    return WebPortalPaper(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: WebPortalStyles.sectionTitle(context)),
          const SizedBox(height: 12),
          _MapRefreshToolbar(
            selectedTripId: widget.selectedTripId,
            onClearTripSelection: widget.onClearTripSelection,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                key: _mapStackKey,
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  RepaintBoundary(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _driverBlinkOn,
                      builder: (context, driverBlinkOn, _) {
                        return GoogleMap(
                          key: const ValueKey('portal-trip-map'),
                          initialCameraPosition: const CameraPosition(
                            target: PortalTripMapLogic.defaultCenter,
                            zoom: 10,
                          ),
                          markers: _googleMarkers(driverBlinkOn),
                          onMapCreated: (c) {
                            _mapController = c;
                            if (_canFitBounds) {
                              _scheduleFitBounds();
                            }
                          },
                          onCameraIdle: () {
                            if (_customerPanelMarker != null) {
                              _updateCustomerPanelAnchor();
                            }
                          },
                        );
                      },
                    ),
                  ),
                  if (showMapSummary)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: PortalMapOverlay(
                        child: summary != null
                            ? PortalTripSummaryOverlay(
                                trip: widget.selectedTrip!,
                                summary: summary,
                              )
                            : const PortalTripSummaryLoadingOverlay(),
                      ),
                    ),
                  if (_customerPanelMarker != null) ...[
                    Builder(
                      builder: (context) {
                        final mapSize = _mapStackSize();
                        if (mapSize == Size.zero) {
                          if (!_panelLayoutScheduled) {
                            _panelLayoutScheduled = true;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _panelLayoutScheduled = false;
                              if (mounted && _customerPanelMarker != null) {
                                setState(() {});
                              }
                            });
                          }
                          return const SizedBox.shrink();
                        }
                        final panelPos = _customerPanelAnchor != null
                            ? _panelPosition(
                                _customerPanelAnchor!,
                                mapSize,
                                _panelHeightEstimate,
                              )
                            : (left: 12.0, top: 12.0);
                        return Positioned(
                          left: panelPos.left,
                          top: panelPos.top,
                          child: PortalMapOverlay(
                            child: _PanelHeightReporter(
                              key: _panelMeasureKey,
                              onHeightMeasured: _onPanelHeightMeasured,
                              child: PortalCustomerInfoPanel(
                                key: ValueKey(_customerPanelMarker!.id),
                                marker: _customerPanelMarker!,
                                onClose: _closeCustomerPanel,
                                onLayoutChanged: () => _panelMeasureKey
                                    .currentState
                                    ?.scheduleReport(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!isWide &&
              widget.selectedTripId != null &&
              widget.selectedTrip != null) ...[
            const SizedBox(height: 12),
            summary != null
                ? PortalTripSummaryOverlay(
                    trip: widget.selectedTrip!,
                    summary: summary,
                  )
                : const PortalTripSummaryLoadingOverlay(),
          ],
        ],
      ),
    );
  }
}

/// Refresh row — matches React TripDashboard countdown + `isFetchingTrips` button state.
class _MapRefreshToolbar extends ConsumerStatefulWidget {
  const _MapRefreshToolbar({
    required this.selectedTripId,
    required this.onClearTripSelection,
  });

  final int? selectedTripId;
  final VoidCallback onClearTripSelection;

  @override
  ConsumerState<_MapRefreshToolbar> createState() => _MapRefreshToolbarState();
}

class _MapRefreshToolbarState extends ConsumerState<_MapRefreshToolbar> {
  static const _refreshIntervalSeconds = 20;

  int _countdown = _refreshIntervalSeconds;
  bool _refreshing = false;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    if (_countdown <= 1) {
      setState(() => _countdown = _refreshIntervalSeconds);
      unawaited(_refreshData());
    } else {
      setState(() => _countdown--);
    }
  }

  /// React `handleRefreshLocations` + react-query `isFetching` during refetch.
  Future<void> _refreshData({bool resetCountdown = false}) async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      if (resetCountdown) _countdown = _refreshIntervalSeconds;
    });

    ref.invalidate(portalAllTripsProvider);
    try {
      await ref.read(portalAllTripsProvider.future);
      final tripId = widget.selectedTripId;
      if (tripId != null) {
        ref.invalidate(portalTripDetailProvider(tripId));
        await ref.read(portalTripDetailProvider(tripId).future);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.selectedTripId != null)
          FilledButton.icon(
            onPressed: widget.onClearTripSelection,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Show All Trips'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
          ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _refreshing ? null : () => unawaited(_refreshData(resetCountdown: true)),
          style: WebPortalStyles.outlinedPrimaryButton(),
          icon: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(
            _refreshing
                ? 'Refreshing...'
                : 'Refresh Data (${_countdown.toString().padLeft(2, '0')})',
          ),
        ),
      ],
    );
  }
}

/// Reports intrinsic panel height so the overlay can reposition without clipping.
class _PanelHeightReporter extends StatefulWidget {
  const _PanelHeightReporter({
    super.key,
    required this.onHeightMeasured,
    required this.child,
  });

  final ValueChanged<double> onHeightMeasured;
  final Widget child;

  @override
  State<_PanelHeightReporter> createState() => _PanelHeightReporterState();
}

class _PanelHeightReporterState extends State<_PanelHeightReporter> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  void didUpdateWidget(_PanelHeightReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  double? _lastHeight;

  void _report() {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final h = box.size.height;
    if (_lastHeight != null && (h - _lastHeight!).abs() < 2) return;
    _lastHeight = h;
    widget.onHeightMeasured(h);
  }

  void scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}


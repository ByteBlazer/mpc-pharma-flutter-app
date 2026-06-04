import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';
import 'portal_customer_info_panel.dart';
import 'portal_map_marker.dart';

class PortalTripMapView extends StatefulWidget {
  const PortalTripMapView({
    super.key,
    required this.activeTab,
    required this.filteredTrips,
    required this.selectedTripId,
    required this.selectedTrip,
    required this.refreshing,
    required this.refreshCountdown,
    required this.onRefresh,
    required this.onTripSelected,
    required this.onClearTripSelection,
    required this.mapHeight,
  });

  final int activeTab;
  final List<WebPortalTrip> filteredTrips;
  final int? selectedTripId;
  final WebPortalTrip? selectedTrip;
  final bool refreshing;
  final int refreshCountdown;
  final VoidCallback onRefresh;
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
  bool _driverBlinkOn = true;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (mounted) setState(() => _driverBlinkOn = !_driverBlinkOn);
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    final driver = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(60, 60)),
      'assets/map/truck-front.png',
    );
    final customer = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(65, 70)),
      'assets/map/customer.png',
    );
    if (mounted) {
      setState(() {
        _driverIcon = driver;
        _customerIcon = customer;
      });
    }
  }

  @override
  void didUpdateWidget(PortalTripMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTripId != widget.selectedTripId) {
      setState(() => _customerPanelMarker = null);
      _fitBounds();
    } else if (oldWidget.filteredTrips != widget.filteredTrips ||
        oldWidget.selectedTrip != widget.selectedTrip) {
      _fitBounds();
    }
  }

  List<PortalMapMarker> get _portalMarkers {
    if (widget.selectedTripId != null && widget.selectedTrip != null) {
      return PortalTripMapLogic.buildSelectedTripMarkers(widget.selectedTrip!);
    }
    return PortalTripMapLogic.buildDriverMarkers(widget.filteredTrips);
  }

  Set<Marker> get _googleMarkers {
    final driverIcon =
        _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    final customerIcon = _customerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final portalMarkers = _portalMarkers;
    final markers = <Marker>{};

    for (final pm in portalMarkers) {
      if (pm.type == PortalMarkerType.driver && !_driverBlinkOn) {
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
    return markers;
  }

  void _onMarkerTap(PortalMapMarker marker) {
    if (marker.type == PortalMarkerType.customer && marker.customerInfo != null) {
      setState(() => _customerPanelMarker = marker);
      return;
    }
    if (marker.type == PortalMarkerType.driver &&
        marker.tripId != null &&
        widget.selectedTripId == null) {
      widget.onTripSelected(marker.tripId!);
    }
  }

  Future<void> _fitBounds() async {
    final controller = _mapController;
    if (controller == null) return;
    final bounds = PortalTripMapLogic.boundsFor(_portalMarkers);
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
  }

  @override
  Widget build(BuildContext context) {
    final summary = PortalTripMapLogic.computeTripSummary(widget.selectedTrip);
    final heading = PortalTripMapLogic.mapHeading(
      activeTab: widget.activeTab,
      selectedTripId: widget.selectedTripId,
      selectedTrip: widget.selectedTrip,
    );
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(heading, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.selectedTripId != null)
                  FilledButton.icon(
                    onPressed: widget.onClearTripSelection,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Show All Trips'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: widget.refreshing ? null : widget.onRefresh,
                  icon: widget.refreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    widget.refreshing
                        ? 'Refreshing...'
                        : 'Refresh Data (${widget.refreshCountdown.toString().padLeft(2, '0')})',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: widget.mapHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: PortalTripMapLogic.defaultCenter,
                        zoom: 10,
                      ),
                      markers: _googleMarkers,
                      onMapCreated: (c) {
                        _mapController = c;
                        _fitBounds();
                      },
                      onTap: (_) => setState(() => _customerPanelMarker = null),
                    ),
                    if (isWide && widget.selectedTripId != null && summary != null)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _TripSummaryOverlay(
                          trip: widget.selectedTrip!,
                          summary: summary,
                        ),
                      ),
                    if (_customerPanelMarker != null)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        right: 12,
                        child: PortalCustomerInfoPanel(
                          marker: _customerPanelMarker!,
                          onClose: () =>
                              setState(() => _customerPanelMarker = null),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (!isWide && widget.selectedTripId != null && summary != null) ...[
              const SizedBox(height: 12),
              _TripSummaryOverlay(
                trip: widget.selectedTrip!,
                summary: summary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripSummaryOverlay extends StatelessWidget {
  const _TripSummaryOverlay({required this.trip, required this.summary});

  final WebPortalTrip trip;
  final PortalTripSummary summary;

  @override
  Widget build(BuildContext context) {
    final title = switch (trip.status) {
      AppConstants.tripStatusScheduled => 'Trip Yet To Start',
      AppConstants.tripStatusStarted => 'Trip In Progress',
      _ => 'Trip Summary',
    };

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: Colors.white.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            _row('Total Customers:', '${summary.totalDeliveries}'),
            _row('✓ Completed:', '${summary.completedDeliveries}',
                color: Colors.green),
            _row('✗ Failed:', '${summary.failedDeliveries}', color: Colors.red),
            _row('⏳ Pending:', '${summary.pendingDeliveries}',
                color: Colors.orange),
            const Divider(),
            _row('📦 Lot Dropoffs Pending:', '${summary.dropoffsPending}',
                color: Colors.blue),
            if (summary.duration != null) ...[
              const Divider(),
              _row(summary.durationLabel ?? 'Duration:', summary.duration!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color ?? Colors.black54)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

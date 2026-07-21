import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_environment.dart';
import '../../utils/google_maps_loader.dart';
import '../../utils/map_marker_icon.dart';
import '../my_trips/my_trips_models.dart';
import 'trip_dashboard_helpers.dart';
import 'trip_dashboard_models.dart';

class TripDashboardMapSection extends StatefulWidget {
  const TripDashboardMapSection({
    super.key,
    required this.heading,
    required this.driverTrips,
    this.tripDetail,
    this.customerClusters = const [],
    this.selectedTripId,
    this.selectedClusterKey,
    this.driverMarkersInteractive = true,
    this.onDriverTripTap,
    this.onCustomerClusterTap,
    this.onMapTap,
    this.compact = false,
  });

  final String heading;
  final List<DashboardTripSummary> driverTrips;
  final SingleTripDetails? tripDetail;
  final List<CustomerMapCluster> customerClusters;
  final int? selectedTripId;
  final String? selectedClusterKey;
  final bool driverMarkersInteractive;
  final ValueChanged<int>? onDriverTripTap;
  final ValueChanged<CustomerMapCluster>? onCustomerClusterTap;
  final VoidCallback? onMapTap;
  final bool compact;

  @override
  State<TripDashboardMapSection> createState() =>
      _TripDashboardMapSectionState();
}

class _TripDashboardMapSectionState extends State<TripDashboardMapSection> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;
  bool _isLoading = true;
  String? _loadError;
  Timer? _pulseTimer;
  bool _pulseHigh = true;

  bool get _shouldPulseDriverMarkers {
    if (widget.tripDetail != null) {
      return widget.tripDetail!.hasDriverGps;
    }
    return widget.driverTrips.length == 1;
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _syncPulseTimer();
  }

  @override
  void didUpdateWidget(covariant TripDashboardMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPulseTimer();
    if (_mapDataChanged(oldWidget)) {
      _fitMapToMarkers();
    }
  }

  void _syncPulseTimer() {
    if (!_shouldPulseDriverMarkers) {
      _pulseTimer?.cancel();
      _pulseTimer = null;
      if (!_pulseHigh && mounted) {
        setState(() => _pulseHigh = true);
      }
      return;
    }

    if (_pulseTimer != null) return;

    _pulseTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (!mounted) return;
      setState(() => _pulseHigh = !_pulseHigh);
    });
  }

  bool _mapDataChanged(TripDashboardMapSection oldWidget) {
    final oldDetail = oldWidget.tripDetail;
    final detail = widget.tripDetail;
    if (oldDetail?.tripId != detail?.tripId) return true;
    if (oldDetail?.driverLat != detail?.driverLat) return true;
    if (oldDetail?.driverLng != detail?.driverLng) return true;
    if (!_sameDriverTrips(oldWidget.driverTrips, widget.driverTrips)) {
      return true;
    }
    if (!_sameCustomerClusters(
      oldWidget.customerClusters,
      widget.customerClusters,
    )) {
      return true;
    }
    return false;
  }

  bool _sameDriverTrips(
    List<DashboardTripSummary> a,
    List<DashboardTripSummary> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].tripId != b[i].tripId) return false;
      if (a[i].driverLat != b[i].driverLat) return false;
      if (a[i].driverLng != b[i].driverLng) return false;
    }
    return true;
  }

  bool _sameCustomerClusters(
    List<CustomerMapCluster> a,
    List<CustomerMapCluster> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
      if (a[i].latitude != b[i].latitude) return false;
      if (a[i].longitude != b[i].longitude) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _mapController = null;
    super.dispose();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await ensureGoogleMapsLoaded(AppEnvironment.googleMapApiKey);
      final results = await Future.wait([
        loadTripDashboardCustomerMapMarkerIcon(),
        loadDriverMapMarkerIcon(),
      ]);
      if (!mounted) return;
      setState(() {
        _customerIcon = results[0];
        _driverIcon = results[1];
        _isLoading = false;
      });
      _fitMapToMarkers();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    final customerIcon = _customerIcon;
    final driverIcon = _driverIcon;
    if (customerIcon == null || driverIcon == null) return const {};

    final markers = <Marker>{};
    final driverAlpha = _shouldPulseDriverMarkers && !_pulseHigh ? 0.45 : 1.0;

    if (widget.tripDetail != null) {
      final detail = widget.tripDetail!;
      if (detail.hasDriverGps) {
        markers.add(
          Marker(
            markerId: MarkerId('driver-${detail.tripId}'),
            position: LatLng(detail.driverLat!, detail.driverLng!),
            icon: driverIcon,
            alpha: driverAlpha,
            zIndexInt: 1,
            consumeTapEvents: false,
          ),
        );
      }
      for (final cluster in widget.customerClusters) {
        if (!cluster.hasGeo) continue;
        markers.add(
          Marker(
            markerId: MarkerId('customer-${cluster.key}'),
            position: LatLng(cluster.latitude!, cluster.longitude!),
            icon: customerIcon,
            zIndexInt: 2,
            onTap: () => widget.onCustomerClusterTap?.call(cluster),
          ),
        );
      }
      return markers;
    }

    for (final trip in widget.driverTrips) {
      if (!trip.hasDriverGps) continue;
      markers.add(
        Marker(
          markerId: MarkerId('driver-${trip.tripId}'),
          position: LatLng(trip.driverLat!, trip.driverLng!),
          icon: driverIcon,
          alpha: driverAlpha,
          zIndexInt: 1,
          consumeTapEvents: !widget.driverMarkersInteractive,
          onTap: widget.driverMarkersInteractive
              ? () => widget.onDriverTripTap?.call(trip.tripId)
              : null,
        ),
      );
    }
    return markers;
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null || _customerIcon == null || !mounted) return;

    final positions = <LatLng>[];
    for (final marker in _buildMarkers()) {
      positions.add(marker.position);
    }

    if (positions.isEmpty) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          const LatLng(kochiMapCenterLat, kochiMapCenterLng),
          10,
        ),
      );
      return;
    }

    if (positions.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 12),
      );
      return;
    }

    var minLat = positions.first.latitude;
    var maxLat = positions.first.latitude;
    var minLng = positions.first.longitude;
    var maxLng = positions.first.longitude;
    for (final point in positions.skip(1)) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
    } catch (_) {
      if (!mounted || _mapController == null) return;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          10,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _buildMapBody(context),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.heading,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _buildMapBody(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMapBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _initializeMap,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(kochiMapCenterLat, kochiMapCenterLng),
        zoom: 10,
      ),
      markers: _buildMarkers(),
      minMaxZoomPreference: const MinMaxZoomPreference(4, 20),
      mapType: MapType.normal,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      onMapCreated: (controller) async {
        if (!mounted) return;
        _mapController = controller;
        await _fitMapToMarkers();
      },
      onTap: (_) => widget.onMapTap?.call(),
    );
  }
}

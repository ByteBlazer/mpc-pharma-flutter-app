import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_environment.dart';
import '../../utils/google_maps_loader.dart';
import '../../utils/map_marker_icon.dart';
import '../trip_dashboard/trip_dashboard_helpers.dart';
import 'public_tracking_models.dart';

class PublicTrackingMap extends StatefulWidget {
  const PublicTrackingMap({super.key, required this.tracking});

  final DocTrackingResponse tracking;

  @override
  State<PublicTrackingMap> createState() => _PublicTrackingMapState();
}

class _PublicTrackingMapState extends State<PublicTrackingMap> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _driverIcon;
  bool _isLoading = true;
  String? _loadError;
  Timer? _pulseTimer;
  bool _pulseHigh = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 750), (_) {
      if (!mounted) return;
      setState(() => _pulseHigh = !_pulseHigh);
    });
  }

  @override
  void didUpdateWidget(covariant PublicTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracking != widget.tracking) {
      _fitMapToMarkers();
    }
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
    final driverAlpha = _pulseHigh ? 1.0 : 0.45;
    final tracking = widget.tracking;

    final customer = tracking.customerLocation;
    if (customer != null && customer.hasCoordinates) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(customer.lat!, customer.lng!),
          icon: customerIcon,
          infoWindow: const InfoWindow(title: 'Delivery Location'),
        ),
      );
    }

    final driver = tracking.driverLastKnownLocation;
    if (driver != null && driver.hasCoordinates) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver.lat!, driver.lng!),
          icon: driverIcon,
          alpha: driverAlpha,
          zIndexInt: 2,
          infoWindow: const InfoWindow(title: 'Driver Location'),
        ),
      );
    }

    return markers;
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null) return;

    final positions = <LatLng>[];
    final customer = widget.tracking.customerLocation;
    final driver = widget.tracking.driverLastKnownLocation;
    if (customer != null && customer.hasCoordinates) {
      positions.add(LatLng(customer.lat!, customer.lng!));
    }
    if (driver != null && driver.hasCoordinates) {
      positions.add(LatLng(driver.lat!, driver.lng!));
    }

    if (positions.isEmpty) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(
          const LatLng(kochiMapCenterLat, kochiMapCenterLng),
          12,
        ),
      );
      return;
    }

    if (positions.length == 1) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(positions.first, 14),
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
      await controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      await controller.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
          10,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(kochiMapCenterLat, kochiMapCenterLng),
        zoom: 12,
      ),
      markers: _buildMarkers(),
      onMapCreated: (controller) {
        _mapController = controller;
        _fitMapToMarkers();
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: true,
      minMaxZoomPreference: const MinMaxZoomPreference(4, 18),
    );
  }
}

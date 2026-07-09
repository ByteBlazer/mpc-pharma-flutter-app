import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../app_environment.dart';
import '../../utils/google_maps_loader.dart';
import '../../utils/map_marker_icon.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_view_details_button.dart';
import 'customer_models.dart';

class CustomersMapSection extends StatefulWidget {
  const CustomersMapSection({
    super.key,
    required this.customers,
    required this.canViewDetails,
    required this.onViewCustomer,
  });

  final List<CustomerSummary> customers;
  final bool canViewDetails;
  final ValueChanged<CustomerSummary> onViewCustomer;

  @override
  State<CustomersMapSection> createState() => _CustomersMapSectionState();
}

class _CustomersMapSectionState extends State<CustomersMapSection> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _markerIcon;
  CustomerSummary? _selectedCustomer;
  bool _isLoading = true;
  String? _loadError;

  List<CustomerSummary> get _mappableCustomers =>
      widget.customers.where((customer) => customer.hasCoordinates).toList();

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void didUpdateWidget(covariant CustomersMapSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customers != widget.customers) {
      final selectedId = _selectedCustomer?.id;
      if (selectedId != null &&
          !_mappableCustomers.any((customer) => customer.id == selectedId)) {
        _selectedCustomer = null;
      }
      _fitMapToMarkers();
    }
  }

  @override
  void dispose() {
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
      final markerIcon = await loadMapMarkerIcon();
      if (!mounted) return;
      setState(() {
        _markerIcon = markerIcon;
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
    final markerIcon = _markerIcon;
    if (markerIcon == null) return const {};

    return _mappableCustomers.map((customer) {
      final latitude = customer.latitude!;
      final longitude = customer.longitude!;

      return Marker(
        markerId: MarkerId(customer.id),
        position: LatLng(latitude, longitude),
        icon: markerIcon,
        onTap: () => setState(() => _selectedCustomer = customer),
      );
    }).toSet();
  }

  LatLng _initialCameraTarget() {
    final customers = _mappableCustomers;
    if (customers.isEmpty) {
      return const LatLng(20.5937, 78.9629);
    }

    final first = customers.first;
    return LatLng(first.latitude!, first.longitude!);
  }

  Future<void> _fitMapToMarkers() async {
    final controller = _mapController;
    if (controller == null || _markerIcon == null || !mounted) return;

    final customers = _mappableCustomers;
    if (customers.isEmpty) return;

    if (customers.length == 1) {
      final customer = customers.first;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(customer.latitude!, customer.longitude!),
          12,
        ),
      );
      return;
    }

    var minLat = customers.first.latitude!;
    var maxLat = customers.first.latitude!;
    var minLng = customers.first.longitude!;
    var maxLng = customers.first.longitude!;

    for (final customer in customers.skip(1)) {
      final latitude = customer.latitude!;
      final longitude = customer.longitude!;
      minLat = latitude < minLat ? latitude : minLat;
      maxLat = latitude > maxLat ? latitude : maxLat;
      minLng = longitude < minLng ? longitude : minLng;
      maxLng = longitude > maxLng ? longitude : maxLng;
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
          8,
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
      return _MapMessage(
        message: _loadError!,
        actionLabel: 'Retry',
        onAction: _initializeMap,
      );
    }

    if (_mappableCustomers.isEmpty) {
      return const _MapMessage(
        message: 'No customers with map coordinates match the search.',
      );
    }

    final markers = _buildMarkers();
    final missingCount = widget.customers.length - _mappableCustomers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (missingCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${_mappableCustomers.length} on map · $missingCount without coordinates',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _initialCameraTarget(),
                    zoom: 8,
                  ),
                  markers: markers,
                  mapType: MapType.normal,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                  onMapCreated: (controller) async {
                    if (!mounted) return;
                    _mapController = controller;
                    await _fitMapToMarkers();
                  },
                  onTap: (_) => setState(() => _selectedCustomer = null),
                ),
                if (_selectedCustomer != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _CustomerMapCallout(
                      customer: _selectedCustomer!,
                      canViewDetails: widget.canViewDetails,
                      onClose: () => setState(() => _selectedCustomer = null),
                      onViewDetails: () =>
                          widget.onViewCustomer(_selectedCustomer!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomerMapCallout extends StatelessWidget {
  const _CustomerMapCallout({
    required this.customer,
    required this.canViewDetails,
    required this.onClose,
    required this.onViewDetails,
  });

  final CustomerSummary customer;
  final bool canViewDetails;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final city = customer.city.trim();

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: AppSurface(
        borderRadius: 16,
        child: Padding(
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
                      customer.firmName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onClose,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
              if (city.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black, fontSize: 14),
                ),
              ],
              if (canViewDetails) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppViewDetailsButton(onPressed: onViewDetails),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

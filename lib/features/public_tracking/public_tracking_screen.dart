import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../web_portal/trip_map/portal_map_marker.dart';

/// MUI PublicTracking.tsx — palette + typography.
abstract final class _PublicTrackingStyles {
  static const panelBackground = Colors.white;
  static const bodySecondary = Color(0x99000000); // text.secondary ~60% black
  static const captionDisabled = Color(0x61000000); // text.disabled
  static const infoAlertBackground = Color(0xFFE5F6FD);
  static const infoAlertForeground = Color(0xFF014361);

  static const successMain = Color(0xFF2E7D32);
  static const errorMain = Color(0xFFD32F2F);
  static const warningMain = Color(0xFFED6C02);
  static const infoMain = Color(0xFF0288D1);
  static const defaultMain = Color(0xFF616161);
}

class PublicTrackingScreen extends ConsumerStatefulWidget {
  const PublicTrackingScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<PublicTrackingScreen> createState() =>
      _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends ConsumerState<PublicTrackingScreen> {
  WebPortalDocTrackingResponse? _tracking;
  Object? _error;
  bool _loading = true;
  Timer? _refreshTimer;
  GoogleMapController? _mapController;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _customerIcon;
  late final ValueNotifier<bool> _driverBlinkOn;
  Timer? _blinkTimer;

  @override
  void initState() {
    super.initState();
    _driverBlinkOn = ValueNotifier(true);
    _loadMarkerIcons();
    _blinkTimer = Timer.periodic(
      PortalTripMapLogic.driverBlinkToggleInterval,
      (_) => _driverBlinkOn.value = !_driverBlinkOn.value,
    );
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _blinkTimer?.cancel();
    _driverBlinkOn.dispose();
    _mapController = null;
    super.dispose();
  }

  Future<void> _loadMarkerIcons() async {
    final driver = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(75, 75)),
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

  Future<void> _loadData({bool silent = false}) async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Invalid tracking link: No token provided';
      });
      return;
    }

    if (!silent && mounted) {
      setState(() {
        _loading = _tracking == null;
        _error = null;
      });
    }

    try {
      final prefs = await ref.read(prefsProvider.future);
      final api = ApiClient(prefs);
      final tracking = await api.getDocTracking(token);

      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
        _error = null;
      });
      _scheduleFitBounds();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.parseError(e);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scheduleFitBounds() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
  }

  Future<void> _fitBounds() async {
    final controller = _mapController;
    if (controller == null || !mounted) return;

    final markers = _buildMapMarkers(_driverBlinkOn.value);
    if (markers.isEmpty) return;

    final bounds = PortalTripMapLogic.boundsFor(
      markers.map((m) {
        return PortalMapMarker(
          id: m.markerId.value,
          position: m.position,
          type: m.markerId.value.startsWith('driver')
              ? PortalMarkerType.driver
              : PortalMarkerType.customer,
          title: '',
        );
      }).toList(),
    );

    if (bounds == null) return;
    try {
      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    } catch (_) {}
  }

  Set<Marker> _buildMapMarkers(bool driverBlinkOn) {
    final tracking = _tracking;
    if (tracking == null) return {};

    final driverIcon =
        _driverIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    final customerIcon =
        _customerIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    final markers = <Marker>{};

    final customer = tracking.customerLocation;
    if (customer != null) {
      final lat = double.tryParse(customer.latitude);
      final lng = double.tryParse(customer.longitude);
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('customer'),
            position: LatLng(lat, lng),
            icon: customerIcon,
            zIndexInt: 2,
            infoWindow: const InfoWindow(title: 'Delivery Location'),
          ),
        );
      }
    }

    final driver = tracking.driverLastKnownLocation;
    if (driver != null && driverBlinkOn) {
      final lat = double.tryParse(driver.latitude);
      final lng = double.tryParse(driver.longitude);
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(lat, lng),
            icon: driverIcon,
            zIndexInt: 3,
            infoWindow: const InfoWindow(title: 'Driver Location'),
          ),
        );
      }
    }

    return markers;
  }

  bool get _hasMap {
    final t = _tracking;
    return t?.customerLocation != null || t?.driverLastKnownLocation != null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _tracking == null) {
      return const Scaffold(
        backgroundColor: _PublicTrackingStyles.panelBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading tracking information...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _tracking == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Material(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error?.toString() ?? 'Failed to load tracking information',
                    style: const TextStyle(color: Color(0xFFC62828)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final tracking = _tracking!;
    final status = _statusDisplay(tracking.status);
    final deliveringTo = _deliveringTo(tracking);

    return Scaffold(
      backgroundColor: _PublicTrackingStyles.panelBackground,
      body: Column(
        children: [
          Material(
            color: _PublicTrackingStyles.panelBackground,
            elevation: 3,
            shadowColor: Colors.black26,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Delivery Tracking',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                          ),
                        ),
                        _TrackingStatusChip(style: status),
                      ],
                    ),
                    if (tracking.docId != null &&
                        tracking.docId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _PublicTrackingStyles.bodySecondary,
                              ),
                          children: [
                            const TextSpan(
                              text: 'Invoice: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: tracking.docId),
                            if (_formatInr(tracking.docAmount) != null) ...[
                              const TextSpan(text: ' — '),
                              TextSpan(
                                text: _formatInr(tracking.docAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (deliveringTo != null) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _PublicTrackingStyles.bodySecondary,
                              ),
                          children: [
                            const TextSpan(
                              text: 'Delivering To: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: deliveringTo),
                          ],
                        ),
                      ),
                    ],
                    if (tracking.comment != null &&
                        tracking.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _PublicTrackingStyles.bodySecondary,
                              ),
                          children: [
                            const TextSpan(
                              text: 'Note: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: tracking.comment),
                          ],
                        ),
                      ),
                    ],
                    if (tracking.deliveryTimestamp != null) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: _PublicTrackingStyles.bodySecondary,
                              ),
                          children: [
                            const TextSpan(
                              text: 'Delivered at: ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(
                              text: _formatDeliveryTimestamp(
                                tracking.deliveryTimestamp!,
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
                        'Driver location updated: ${_formatDriverUpdate(tracking.driverLastKnownLocation!.receivedAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: _PublicTrackingStyles.captionDisabled,
                        ),
                      ),
                    ],
                    if (tracking.eta != null &&
                        tracking.status != AppConstants.docStatusDelivered &&
                        tracking.status !=
                            AppConstants.docStatusUndelivered) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Estimated Time To Delivery:',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _PublicTrackingStyles.bodySecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatEta(tracking.eta!, tracking.status),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tracking.eta == -1
                                  ? _PublicTrackingStyles.warningMain
                                  : AppColors.primary,
                            ),
                      ),
                    ],
                    if ((tracking.numEnrouteCustomers ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _PublicTrackingStyles.infoAlertBackground,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Note: The delivery agent has ${tracking.numEnrouteCustomers} '
                          '${tracking.numEnrouteCustomers == 1 ? 'delivery' : 'deliveries'} '
                          'to make before reaching you. The actual delivery time may be '
                          'longer than estimated.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color:
                                    _PublicTrackingStyles.infoAlertForeground,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _hasMap
                ? RepaintBoundary(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _driverBlinkOn,
                      builder: (context, driverBlinkOn, _) {
                        return GoogleMap(
                          key: const ValueKey('public-tracking-map'),
                          initialCameraPosition: const CameraPosition(
                            target: PortalTripMapLogic.defaultCenter,
                            zoom: 12,
                          ),
                          minMaxZoomPreference: const MinMaxZoomPreference(4, 18),
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                          markers: _buildMapMarkers(driverBlinkOn),
                          onMapCreated: (c) {
                            _mapController = c;
                            _scheduleFitBounds();
                          },
                        );
                      },
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _PublicTrackingStyles.infoAlertBackground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _noMapMessage(tracking.status),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color:
                                      _PublicTrackingStyles.infoAlertForeground,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String? _formatInr(String? amount) {
    if (amount == null || amount.trim().isEmpty) return null;
    final n = num.tryParse(amount);
    if (n != null) return '₹${NumberFormat('#,##,###', 'en_IN').format(n)}';
    return amount.startsWith('₹') ? amount : '₹$amount';
  }

  static String? _deliveringTo(WebPortalDocTrackingResponse tracking) {
    final parts = [
      tracking.customerFirmName,
      tracking.customerAddress,
      tracking.customerCity,
      tracking.customerPincode,
    ].where((v) => v != null && v.trim().isNotEmpty).cast<String>();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  static String _formatEta(double etaMinutes, String? status) {
    if (etaMinutes == -1) {
      return status == AppConstants.docStatusOnTrip
          ? 'Updating Soon'
          : 'Unavailable';
    }
    if (etaMinutes < 1) return 'Less than a minute';
    if (etaMinutes < 60) {
      final rounded = etaMinutes.round();
      return rounded == 1 ? '1 minute' : '$rounded minutes';
    }
    final hours = etaMinutes ~/ 60;
    final minutes = etaMinutes.round() % 60;
    return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
  }

  static String _formatDeliveryTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat('h:mm a', 'en_IN').format(local);
    if (isToday) return 'Today $time';
    final date = DateFormat('MMM d', 'en_IN').format(local);
    return '$date $time';
  }

  static String _formatDriverUpdate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time = DateFormat('h:mm a', 'en_IN').format(local);
    if (isToday) return time;
    final date = DateFormat('MMM d', 'en_IN').format(local);
    return '$date, $time';
  }

  static String _noMapMessage(String? status) {
    return switch (status) {
      AppConstants.docStatusDelivered =>
        'Delivery has been completed. Location tracking is no longer available.',
      AppConstants.docStatusUndelivered =>
        'Delivery could not be completed. Location tracking is no longer available.',
      _ =>
        'Location tracking is not available for this delivery at the moment.',
    };
  }

  static _TrackingStatusStyle _statusDisplay(String? status) {
    return switch (status) {
      AppConstants.docStatusDelivered => _TrackingStatusStyle(
        icon: Icons.check_circle,
        backgroundColor: _PublicTrackingStyles.successMain,
        foregroundColor: Colors.white,
        label: 'Delivered',
      ),
      AppConstants.docStatusUndelivered => _TrackingStatusStyle(
        icon: Icons.cancel,
        backgroundColor: _PublicTrackingStyles.errorMain,
        foregroundColor: Colors.white,
        label: 'DELIVERY FAILED',
      ),
      AppConstants.docStatusOnTrip => _TrackingStatusStyle(
        icon: Icons.local_shipping,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        label: 'On Trip',
      ),
      'AT_TRANSIT_HUB' => _TrackingStatusStyle(
        icon: Icons.local_shipping,
        backgroundColor: _PublicTrackingStyles.warningMain,
        foregroundColor: Colors.white,
        label: 'At Transit Hub',
      ),
      'TRIP_SCHEDULED' => _TrackingStatusStyle(
        icon: Icons.schedule,
        backgroundColor: _PublicTrackingStyles.infoMain,
        foregroundColor: Colors.white,
        label: 'Trip Scheduled',
      ),
      'READY_FOR_DISPATCH' => _TrackingStatusStyle(
        icon: Icons.schedule,
        backgroundColor: const Color(0xFFE0E0E0),
        foregroundColor: _PublicTrackingStyles.defaultMain,
        label: 'Ready for Dispatch',
      ),
      _ => _TrackingStatusStyle(
        icon: Icons.schedule,
        backgroundColor: const Color(0xFFE0E0E0),
        foregroundColor: _PublicTrackingStyles.defaultMain,
        label: status ?? 'Unknown',
      ),
    };
  }
}

/// MUI `<Chip color="primary" />` filled variant (icon + label on solid fill).
class _TrackingStatusStyle {
  const _TrackingStatusStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;
}

class _TrackingStatusChip extends StatelessWidget {
  const _TrackingStatusChip({required this.style});

  final _TrackingStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 18, color: style.foregroundColor),
            const SizedBox(width: 6),
            Text(
              style.label,
              style: TextStyle(
                color: style.foregroundColor,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

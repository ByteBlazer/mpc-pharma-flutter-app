import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/trip_widgets.dart';
import '../../routing/app_routes.dart';

class MyTripsScreen extends ConsumerStatefulWidget {
  const MyTripsScreen({super.key});

  @override
  ConsumerState<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends ConsumerState<MyTripsScreen> {
  ScheduledTripsResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _maybeSyncAfterLogin();
  }

  Future<void> _maybeSyncAfterLogin() async {
    final lastLogin = ref.read(lastLoginTimeProvider);
    if (lastLogin == null) return;
    if (DateTime.now().difference(lastLogin).inSeconds > 5) return;
    await _load(syncLocation: true);
  }

  Future<void> _load({bool syncLocation = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).getMyTrips();
      setState(() => _data = response);

      if (syncLocation) {
        final prefs = await ref.read(prefsProvider.future);
        final locationService = LocationTrackingService(
          prefs,
          ref.read(apiClientProvider),
        );
        await locationService.syncWithTrips(response.trips);
      }
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services')),
      );
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _onTripTap(ScheduledTrip trip) async {
    if (!await _ensureLocationReady()) return;

    final tripId = '${trip.tripId}';
    final prefs = await ref.read(prefsProvider.future);
    final api = ref.read(apiClientProvider);
    final locationService = LocationTrackingService(prefs, api);

    try {
      if (trip.status == AppConstants.tripStatusScheduled) {
        final response = await api.startTrip(tripId);
        await prefs.saveCurrentTripId(tripId);
        await locationService.start();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Trip started')),
          );
        }
      } else if (trip.status == AppConstants.tripStatusStarted) {
        await locationService.sendLocationIfNeeded();
      }

      if (mounted) {
        context.push('${AppRoutes.tripDetails}/$tripId');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  Future<void> _startTrip(ScheduledTrip trip) async {
    if (!await _ensureLocationReady()) return;
    await _onTripTap(trip);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(myTripsRefreshProvider, (_, __) => _load());

    if (_loading) return const LoadingOverlay();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final trips = _data?.trips ?? [];
    if (trips.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(message: 'Trips assigned to you\nNo data found'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          final isScheduled = trip.status == AppConstants.tripStatusScheduled;
          final isStarted = trip.status == AppConstants.tripStatusStarted;

          return Card(
            child: InkWell(
              onTap: () => _onTripTap(trip),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip #${trip.tripId}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    tripMetaRow(icon: Icons.route, label: 'Route', value: trip.route ?? ''),
                    tripMetaRow(
                      icon: Icons.local_shipping,
                      label: 'Vehicle',
                      value: trip.vehicleNumber ?? '',
                    ),
                    if (trip.deliveryCountStatusMsg?.isNotEmpty == true)
                      tripMetaRow(
                        icon: Icons.inventory_2,
                        label: 'Deliveries',
                        value: trip.deliveryCountStatusMsg!,
                      ),
                    const SizedBox(height: 8),
                    if (isScheduled || isStarted)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => _startTrip(trip),
                          child: Text(isStarted ? 'Resume Trip' : 'Start Trip'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

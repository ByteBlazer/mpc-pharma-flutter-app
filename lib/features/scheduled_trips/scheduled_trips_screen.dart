import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/trip_widgets.dart';

class ScheduledTripsScreen extends ConsumerStatefulWidget {
  const ScheduledTripsScreen({super.key});

  @override
  ConsumerState<ScheduledTripsScreen> createState() =>
      _ScheduledTripsScreenState();
}

class _ScheduledTripsScreenState extends ConsumerState<ScheduledTripsScreen> {
  ScheduledTripsResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).getScheduledTrips();
      setState(() => _data = response);
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelTrip(ScheduledTrip trip) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel Trip',
      message: 'Cancel trip #${trip.tripId}?',
    );
    if (confirmed != true) return;

    try {
      final response = await ref
          .read(apiClientProvider)
          .cancelScheduledTrip('${trip.tripId}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Trip cancelled')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(scheduledTripsRefreshProvider, (_, __) => _load());

    if (_loading) return const LoadingOverlay();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final trips = _data?.trips ?? [];
    if (trips.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(message: 'Trips scheduled from your location\nNo data found'),
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
          return Card(
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
                  tripMetaRow(
                    icon: Icons.person,
                    label: 'Driver',
                    value: trip.driverName ?? '',
                  ),
                  if (trip.deliveryCountStatusMsg?.isNotEmpty == true)
                    tripMetaRow(
                      icon: Icons.inventory_2,
                      label: 'Deliveries',
                      value: trip.deliveryCountStatusMsg!,
                    ),
                  if (trip.createdAt != null)
                    tripMetaRow(
                      icon: Icons.schedule,
                      label: 'Created',
                      value: formatTripCreatedAt(trip.createdAt),
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _cancelTrip(trip),
                      child: const Text('Cancel Trip'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

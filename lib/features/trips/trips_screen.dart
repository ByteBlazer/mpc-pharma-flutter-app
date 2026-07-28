import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'trips_models.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  late Future<ScheduledTripsResponse> _future;
  String? _emptyMessage;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ScheduledTripsResponse> _load() async {
    final response = await widget.apiClient.getScheduledList();
    if (!mounted) return response;
    setState(() {
      _emptyMessage =
          response.message.isNotEmpty ? response.message : 'No data found';
    });
    return response;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _confirmCancel(ScheduledTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Scheduled Trip'),
        content: Text(
          'Are you sure you want to cancel Trip #${trip.tripId} for the '
          '${trip.route} route?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    CancelTripResult result;
    try {
      result = await widget.apiClient.cancelScheduledTrip(tripId: trip.tripId);
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.statusCode == 403) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot cancel trip'),
            content: Text(error.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      if (isAuthErrorMessage(error)) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }
      result = CancelTripResult(
        statusCode: 0,
        success: false,
        message: error.toString(),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }

    if (!mounted) return;

    if (result.statusCode == 401) {
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: AppSnackBarType.error,
      );
      await widget.onLoginAgain();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (result.isPermissionDenied) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot cancel trip'),
          content: Text(result.displayMessage),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result.success ? 'Trip cancelled' : 'Cancel failed'),
        content: Text(result.displayMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result.success && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Scheduled Trips'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _cancelling ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<ScheduledTripsResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppLoadErrorState(
              title: 'Could not load trips',
              message: snapshot.error.toString(),
              onRetry: _refresh,
              onLoginAgain: widget.onLoginAgain,
            );
          }

          final trips = snapshot.data?.trips ?? const <ScheduledTrip>[];
          if (trips.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _emptyMessage ?? 'No data found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              const Text(
                'Trips scheduled from your location',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              for (final trip in trips) ...[
                _TripCard(
                  trip: trip,
                  cancelling: _cancelling,
                  onCancel: () => _confirmCancel(trip),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.cancelling,
    required this.onCancel,
  });

  final ScheduledTrip trip;
  final bool cancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Trip ',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: '#${trip.tripId}',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: cancelling ? null : onCancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel Trip'),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primary.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TripMetaRow(
              icon: Icons.route_outlined,
              text: trip.route,
            ),
            _TripMetaRow(
              icon: Icons.local_shipping_outlined,
              text: '${trip.vehicleNumber} - ${trip.driverName}',
            ),
            if (trip.deliveryCountStatusMsg.isNotEmpty)
              _TripMetaRow(
                icon: Icons.handshake_outlined,
                text: trip.deliveryCountStatusMsg,
              ),
            if (trip.dropOffCountStatusMsg.isNotEmpty)
              _TripMetaRow(
                icon: Icons.inventory_2_outlined,
                text: trip.dropOffCountStatusMsg,
              ),
            if (trip.createdBy.isNotEmpty ||
                trip.createdAtFormatted.isNotEmpty)
              _TripMetaRow(
                icon: Icons.person_outline,
                text: [
                  if (trip.createdBy.isNotEmpty) 'Created By ${trip.createdBy}',
                  if (trip.createdAtFormatted.isNotEmpty)
                    'at ${trip.createdAtFormatted}',
                ].join(' '),
                compact: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _TripMetaRow extends StatelessWidget {
  const _TripMetaRow({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: compact ? 16 : 18, color: Colors.black45),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: compact ? 12.5 : 13.5,
                fontWeight: compact ? FontWeight.w500 : FontWeight.w600,
                color: compact ? Colors.black54 : Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

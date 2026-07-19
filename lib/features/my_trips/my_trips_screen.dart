import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../services/trip_heartbeat_service.dart';
import '../../services/trip_location_gate.dart';
import '../../utils/platform_device.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'my_trips_models.dart';
import 'trip_detail_screen.dart';

class MyTripsScreen extends StatefulWidget {
  const MyTripsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<MyTripsScreen> createState() => _MyTripsScreenState();
}

class _MyTripsScreenState extends State<MyTripsScreen> {
  late Future<MyTripsListResponse> _future;
  String? _emptyMessage;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<MyTripsListResponse> _load() async {
    final response = await widget.apiClient.getMyTripsList();
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

  Future<bool?> _confirmSettings(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _startOrResume(DriverTripSummary trip) async {
    if (!isMobileNativePlatform) {
      showAppSnackBar(
        context,
        message: 'Start and Resume are only available on a mobile device.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final gate = await TripLocationGate.ensureReady(
      confirmSettings: _confirmSettings,
    );
    if (!gate.ok) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: gate.message,
        type: AppSnackBarType.warning,
      );
      return;
    }

    final simulating = await JwtPayload.currentIsImpersonation();
    setState(() => _busy = true);
    try {
      if (trip.isScheduled) {
        final started = await widget.apiClient.startTrip(tripId: trip.tripId);
        if (!mounted) return;
        if (started.statusCode == 401 || started.statusCode == 403) {
          await _handleAuth(started.displayMessage);
          return;
        }
        showAppSnackBar(
          context,
          message: started.displayMessage,
          type: started.success
              ? AppSnackBarType.success
              : AppSnackBarType.error,
        );
        if (!started.success) return;
      }

      if (!simulating) {
        final pingOk = await TripHeartbeatService.instance.pingOnce();
        if (!pingOk) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            message:
                'Could not register your location. The trip may already be '
                'started — use Resume Trip to try again.',
            type: AppSnackBarType.error,
          );
          _refresh();
          return;
        }
        final interval =
            await JwtPayload.currentLocationHeartbeatFrequencySeconds();
        await TripHeartbeatService.instance.start(intervalSeconds: interval);
      }

      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(
            apiClient: widget.apiClient,
            onLoginAgain: widget.onLoginAgain,
            tripId: trip.tripId,
          ),
        ),
      );
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      if (isAuthErrorMessage(error)) {
        await _handleAuth(error.toString());
        return;
      }
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleAuth(String message) async {
    showAppSnackBar(
      context,
      message: message,
      type: AppSnackBarType.error,
    );
    await widget.onLoginAgain();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<MyTripsListResponse>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return AppLoadErrorState(
                  title: 'Could not load my trips',
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                  onLoginAgain: widget.onLoginAgain,
                );
              }

              final trips = snapshot.data?.trips ?? const <DriverTripSummary>[];
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
                    'Trips assigned to you',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final trip in trips) ...[
                    _MyTripCard(
                      trip: trip,
                      enabled: !_busy,
                      onAction: () => _startOrResume(trip),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
          if (_busy)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _MyTripCard extends StatelessWidget {
  const _MyTripCard({
    required this.trip,
    required this.enabled,
    required this.onAction,
  });

  final DriverTripSummary trip;
  final bool enabled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final actionLabel = trip.isScheduled ? 'Start Trip' : 'Resume Trip';

    return AppSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text.rich(
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
            const SizedBox(height: 8),
            _Meta(icon: Icons.route_outlined, text: trip.route),
            _Meta(
              icon: Icons.local_shipping_outlined,
              text: '${trip.vehicleNumber} - ${trip.driverName}',
            ),
            if (trip.deliveryCountStatusMsg.isNotEmpty)
              _Meta(
                icon: Icons.handshake_outlined,
                text: trip.deliveryCountStatusMsg,
              ),
            if (trip.dropOffCountStatusMsg.isNotEmpty)
              _Meta(
                icon: Icons.inventory_2_outlined,
                text: trip.dropOffCountStatusMsg,
              ),
            if (trip.createdBy.isNotEmpty ||
                trip.createdAtFormatted.isNotEmpty)
              _Meta(
                icon: Icons.person_outline,
                text: [
                  if (trip.createdBy.isNotEmpty) 'Created By ${trip.createdBy}',
                  if (trip.createdAtFormatted.isNotEmpty)
                    'at ${trip.createdAtFormatted}',
                ].join(' '),
                compact: true,
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: enabled ? onAction : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
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

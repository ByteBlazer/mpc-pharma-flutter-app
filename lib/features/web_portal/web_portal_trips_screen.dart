import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'trip_map/portal_trip_map_view.dart';
import 'web_portal_providers.dart';
import 'web_portal_utils.dart';

class WebPortalTripsScreen extends ConsumerStatefulWidget {
  const WebPortalTripsScreen({super.key});

  @override
  ConsumerState<WebPortalTripsScreen> createState() =>
      _WebPortalTripsScreenState();
}

class _WebPortalTripsScreenState extends ConsumerState<WebPortalTripsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int? _selectedTripId;
  int _refreshCountdown = 20;
  Timer? _countdownTimer;
  Timer? _autoRefreshTimer;
  bool _refreshing = false;
  final _docSearchController = TextEditingController();
  final _tripCardKeys = <int, GlobalKey>{};
  bool _showGuidance = false;
  Timer? _guidanceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTripId = null);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _refreshCountdown = _refreshCountdown <= 1 ? 20 : _refreshCountdown - 1;
      });
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(portalAllTripsProvider);
      if (_selectedTripId != null) {
        ref.invalidate(portalTripDetailProvider(_selectedTripId!));
      }
    });
    _initGuidance();
  }

  Future<void> _initGuidance() async {
    final prefs = await ref.read(prefsProvider.future);
    if (prefs.tripDashboardGuidanceSeen) return;
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showGuidance = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _countdownTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _guidanceTimer?.cancel();
    _docSearchController.dispose();
    super.dispose();
  }

  void _scrollToTrip(int tripId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _tripCardKeys[tripId]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _selectTrip(int tripId) {
    final wasSelected = _selectedTripId == tripId;
    setState(() => _selectedTripId = wasSelected ? null : tripId);
    if (!wasSelected) _scrollToTrip(tripId);
  }

  Future<void> _maybeShowGuidance(List<WebPortalTrip> ongoing) async {
    if (_tabController.index != 0 || ongoing.isEmpty) {
      if (_showGuidance) setState(() => _showGuidance = false);
      return;
    }
    final prefs = await ref.read(prefsProvider.future);
    if (prefs.tripDashboardGuidanceSeen) return;
    if (!mounted) return;
    setState(() => _showGuidance = true);
    await prefs.setTripDashboardGuidanceSeen(true);
    _guidanceTimer?.cancel();
    _guidanceTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _showGuidance = false);
    });
  }

  String get _statusFilter => switch (_tabController.index) {
        0 => AppConstants.tripStatusStarted,
        1 => AppConstants.tripStatusScheduled,
        _ => 'ENDED',
      };

  Future<void> _manualRefresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(portalAllTripsProvider);
    if (_selectedTripId != null) {
      ref.invalidate(portalTripDetailProvider(_selectedTripId!));
    }
    setState(() {
      _refreshing = false;
      _refreshCountdown = 20;
    });
  }

  Future<void> _forceEnd(int tripId) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Force End Trip',
      message:
          'This cannot be undone. Pending deliveries will be marked FAILED. Force end Trip #$tripId?',
      confirmText: 'Force End',
    );
    if (ok != true) return;

    try {
      await ref.read(apiClientProvider).forceEndTrip(tripId);
      ref.invalidate(portalAllTripsProvider);
      setState(() => _selectedTripId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip force ended successfully.')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  Future<void> _docSearch() async {
    final docId = _docSearchController.text.trim();
    if (docId.isEmpty) return;

    try {
      final result = await ref.read(apiClientProvider).searchDoc(docId);
      if (result.docStatus == 'READY_FOR_DISPATCH') {
        _snack(
          'Document was scanned but not scheduled on a trip yet.',
        );
        return;
      }
      if (result.docStatus == 'AT_TRANSIT_HUB') {
        _snack('Document is at a transit hub and not on the next trip yet.');
        return;
      }
      if (result.tripId != null) {
        setState(() {
          _tabController.index = switch (result.tripStatus) {
            'SCHEDULED' => 1,
            'ENDED' => 2,
            _ => 0,
          };
          _selectedTripId = result.tripId;
        });
        _snack('Doc found in Trip #${result.tripId}. Trip selected.');
      }
    } on DioException catch (_) {
      _snack('Doc ID not found.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDocSearchDialog() {
    _docSearchController.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Find By Doc ID'),
        content: TextField(
          controller: _docSearchController,
          decoration: const InputDecoration(labelText: 'Document ID'),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _docSearch();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _docSearch();
            },
            child: const Text('Find'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(portalAllTripsProvider);
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    return tripsAsync.when(
      loading: () => const LoadingOverlay(message: 'Loading trips...'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(portalAllTripsProvider),
      ),
      data: (allTrips) {
        final filtered = allTrips.trips
            .where((t) => t.status == _statusFilter)
            .toList()
          ..sort((a, b) => b.tripId.compareTo(a.tripId));

        final ongoing = allTrips.trips
            .where((t) => t.status == AppConstants.tripStatusStarted)
            .toList();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowGuidance(ongoing);
        });

        WebPortalTrip? selectedTrip;
        if (_selectedTripId != null) {
          final detail =
              ref.watch(portalTripDetailProvider(_selectedTripId!));
          selectedTrip = detail.valueOrNull;
          if (selectedTrip == null) {
            for (final t in filtered) {
              if (t.tripId == _selectedTripId) {
                selectedTrip = t;
                break;
              }
            }
          }
        }

        final mapHeight = isWide ? 600.0 : 400.0;
        final listPane = _buildListPane(filtered);
        final mapPane = PortalTripMapView(
          activeTab: _tabController.index,
          filteredTrips: filtered,
          selectedTripId: _selectedTripId,
          selectedTrip: selectedTrip,
          refreshing: _refreshing,
          refreshCountdown: _refreshCountdown,
          onRefresh: _manualRefresh,
          onTripSelected: (id) => _selectTrip(id),
          onClearTripSelection: () => setState(() => _selectedTripId = null),
          mapHeight: mapHeight,
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip Dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: listPane),
                          const SizedBox(width: 16),
                          Expanded(flex: 6, child: mapPane),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: listPane),
                          const SizedBox(height: 12),
                          mapPane,
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListPane(List<WebPortalTrip> trips) {
    final tabLabel = switch (_tabController.index) {
      0 => 'Ongoing',
      1 => 'Scheduled',
      _ => 'Ended',
    };

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text('$tabLabel Trips (${trips.length})',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: _openDocSearchDialog,
                  child: const Text('Find By Doc ID'),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Ongoing'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Ended'),
            ],
          ),
          Expanded(
            child: trips.isEmpty
                ? const EmptyState(message: 'No trips in this tab.')
                : Stack(
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: trips.length,
                        itemBuilder: (context, i) {
                          final trip = trips[i];
                          final key = _tripCardKeys.putIfAbsent(
                            trip.tripId,
                            GlobalKey.new,
                          );
                          return _TripCard(
                            key: key,
                            trip: trip,
                            selected: _selectedTripId == trip.tripId,
                            onTap: () => _selectTrip(trip.tripId),
                            onForceEnd: trip.status ==
                                    AppConstants.tripStatusStarted
                                ? () => _forceEnd(trip.tripId)
                                : null,
                          );
                        },
                      ),
                      if (_showGuidance &&
                          _tabController.index == 0 &&
                          trips.isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            color: AppColors.primary,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '👋 The map is now showing all driver locations. '
                                      'Click on a trip card to view that trip\'s details alone.',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    onPressed: () =>
                                        setState(() => _showGuidance = false),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: _refreshing ? null : _manualRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(
                _refreshing
                    ? 'Refreshing...'
                    : 'Refresh (${_refreshCountdown.toString().padLeft(2, '0')})',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatefulWidget {
  const _TripCard({
    super.key,
    required this.trip,
    required this.selected,
    required this.onTap,
    this.onForceEnd,
  });

  final WebPortalTrip trip;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onForceEnd;

  @override
  State<_TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<_TripCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: widget.selected ? AppColors.primary : Colors.grey.shade300,
          width: widget.selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Trip #${trip.tripId} ${trip.route}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (!_expanded) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusChip(status: trip.status),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _expanded = true),
                      child: const Text('View More'),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Text(
                  '${trip.vehicleNumber} - ${trip.driverName} - Mob: ${trip.driverPhoneNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Created: ${WebPortalUtils.formatTripTimestamp(trip.createdAt)} by ${trip.createdBy}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (trip.status != AppConstants.tripStatusScheduled)
                  Text(
                    'Started: ${WebPortalUtils.formatTripTimestamp(trip.startedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (trip.status == 'ENDED')
                  Text(
                    'Ended: ${WebPortalUtils.formatTripTimestamp(trip.lastUpdatedAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (widget.onForceEnd != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onForceEnd,
                    icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
                    label: const Text('Force End Trip'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
                Row(
                  children: [
                    _StatusChip(status: trip.status),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _expanded = false),
                      child: const Text('View Less'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'STARTED' => Colors.blue,
      'SCHEDULED' => Colors.orange,
      'ENDED' => Colors.grey,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}

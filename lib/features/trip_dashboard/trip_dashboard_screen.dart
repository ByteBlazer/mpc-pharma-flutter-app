import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import '../my_trips/my_trips_models.dart';
import 'customer_delivery_callout.dart';
import 'trip_dashboard_helpers.dart';
import 'trip_dashboard_map_section.dart';
import 'trip_dashboard_models.dart';
import 'trip_summary_panel.dart';

const _wideBreakpoint = 900.0;
const _refreshIntervalSeconds = 20;

class TripDashboardScreen extends StatefulWidget {
  const TripDashboardScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<TripDashboardScreen> createState() => _TripDashboardScreenState();
}

class _TripDashboardScreenState extends State<TripDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  List<DashboardTripSummary> _allTrips = [];
  String? _loadError;
  bool _initialLoading = true;
  bool _refreshing = false;
  int _refreshCountdown = _refreshIntervalSeconds;

  int? _selectedTripId;
  SingleTripDetails? _tripDetail;
  String? _detailError;
  bool _detailLoading = false;
  int _detailRequestId = 0;

  final _expandedTripIds = <int>{};
  final _tripCardKeys = <int, GlobalKey>{};

  CustomerMapCluster? _selectedCluster;
  bool _canForceEnd = false;

  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _durationTimer;
  bool _appInForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadAdminFlag();
    _refreshAll(initial: true);
    _startTimers();
  }

  Future<void> _loadAdminFlag() async {
    final isAdmin = await JwtPayload.currentUserIsAppAdmin();
    if (mounted) setState(() => _canForceEnd = isAdmin);
  }

  void _startTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    _pollTimer = Timer.periodic(
      const Duration(seconds: _refreshIntervalSeconds),
      (_) {
        if (!mounted) return;
        if (!kIsWeb && !_appInForeground) return;
        _refreshAll();
      },
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_refreshCountdown <= 1) {
          _refreshCountdown = _refreshIntervalSeconds;
        } else {
          _refreshCountdown--;
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (kIsWeb) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground && !_appInForeground) {
      _refreshAll();
    }
    _appInForeground = foreground;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _durationTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _deselectTrip();
  }

  List<DashboardTripSummary> get _filteredTrips =>
      filterTripsByTab(_allTrips, _tabController.index);

  DashboardTripSummary? _tripSummary(int tripId) {
    for (final trip in _allTrips) {
      if (trip.tripId == tripId) return trip;
    }
    return null;
  }

  GlobalKey _keyForTrip(int tripId) =>
      _tripCardKeys.putIfAbsent(tripId, GlobalKey.new);

  Future<void> _refreshAll({bool initial = false}) async {
    if (_refreshing && !initial) return;
    if (initial) {
      setState(() {
        _initialLoading = true;
        _loadError = null;
      });
    } else {
      setState(() => _refreshing = true);
    }

    try {
      final response = await widget.apiClient.getAllTrips();
      if (!mounted) return;
      setState(() {
        _allTrips = response.trips;
        _loadError = null;
        _refreshCountdown = _refreshIntervalSeconds;
      });

      if (_selectedTripId != null) {
        await _loadTripDetail(_selectedTripId!, silent: true);
      }
    } catch (error) {
      if (!mounted) return;
      if (isAuthErrorMessage(error)) {
        await _handleAuthError(error);
        return;
      }
      setState(() {
        _loadError = 'Could not load trips: ${error.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _handleAuthError(Object error) async {
    showAppSnackBar(
      context,
      message: error.toString(),
      type: AppSnackBarType.error,
    );
    await widget.onLoginAgain();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _toggleTripSelection(int tripId) {
    if (_selectedTripId == tripId) {
      _deselectTrip();
      return;
    }
    setState(() {
      _selectedTripId = tripId;
      _selectedCluster = null;
      _tripDetail = null;
      _detailError = null;
    });
    _scrollTripIntoView(tripId);
    _loadTripDetail(tripId);
    _syncDurationTimer();
  }

  void _syncDurationTimer() {
    _durationTimer?.cancel();
    final detail = _tripDetail;
    if (_selectedTripId != null &&
        detail != null &&
        detail.status.toUpperCase() == 'STARTED') {
      _durationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _deselectTrip() {
    if (_selectedTripId == null) return;
    setState(() {
      _selectedTripId = null;
      _selectedCluster = null;
      _tripDetail = null;
      _detailError = null;
      _detailLoading = false;
    });
    _detailRequestId++;
    _durationTimer?.cancel();
  }

  void _scrollTripIntoView(int tripId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keyForTrip(tripId).currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.1,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _loadTripDetail(int tripId, {bool silent = false}) async {
    final requestId = ++_detailRequestId;
    if (!silent) {
      setState(() {
        _detailLoading = true;
        _detailError = null;
      });
    }

    try {
      final detail = await widget.apiClient.getSingleTripDetails(tripId: tripId);
      if (!mounted || requestId != _detailRequestId) return;
      setState(() {
        _tripDetail = detail;
        _detailError = null;
        _detailLoading = false;
      });
      _syncDurationTimer();
    } catch (error) {
      if (!mounted || requestId != _detailRequestId) return;
      if (isAuthErrorMessage(error)) {
        await _handleAuthError(error);
        return;
      }
      setState(() {
        _detailError = error.toString();
        _detailLoading = false;
      });
    }
  }

  Future<void> _openDocSearch() async {
    final docId = await showDialog<String>(
      context: context,
      builder: (context) => const _DocSearchDialog(),
    );
    if (docId == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await widget.apiClient.searchTripByDocId(docId: docId);
      if (!mounted) return;
      Navigator.of(context).pop();

      if (result.isReadyForDispatch) {
        showAppSnackBar(
          context,
          message: 'Document was scanned but is not on a trip yet.',
          type: AppSnackBarType.warning,
        );
        return;
      }
      if (result.isAtTransitHub) {
        showAppSnackBar(
          context,
          message: 'Document is at a transit hub and not on a trip yet.',
          type: AppSnackBarType.warning,
        );
        return;
      }
      if (!result.isOnTrip || result.tripId == null) {
        showAppSnackBar(
          context,
          message: 'Document ID not found.',
          type: AppSnackBarType.warning,
        );
        return;
      }

      final tab = tabIndexForTripStatus(result.tripStatus ?? '');
      _tabController.index = tab;
      _toggleTripSelection(result.tripId!);
      showAppSnackBar(
        context,
        message: 'Found in trip #${result.tripId}. Trip selected.',
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (isAuthErrorMessage(error)) {
        await _handleAuthError(error);
        return;
      }
      showAppSnackBar(
        context,
        message: 'Document ID not found.',
        type: AppSnackBarType.warning,
      );
    }
  }

  Future<void> _confirmForceEnd(DashboardTripSummary trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force end trip'),
        content: Text(
          'This cannot be undone.\n\n'
          'All pending deliveries will be marked as failed. '
          'They can be added to a future trip if needed.\n\n'
          'Force end trip #${trip.tripId}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Force end'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Force ending trip…')),
          ],
        ),
      ),
    );

    ForceEndTripResult result;
    try {
      result = await widget.apiClient.forceEndTrip(tripId: trip.tripId);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context).pop();
      if (isAuthErrorMessage(error)) {
        await _handleAuthError(error);
        return;
      }
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (!result.success) {
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: AppSnackBarType.error,
      );
      return;
    }

    _deselectTrip();
    await _refreshAll();
    if (!mounted) return;
    showAppSnackBar(
      context,
      message:
          'Trip force ended. Pending deliveries were marked as failed.',
      type: AppSnackBarType.success,
    );
  }

  Future<void> _openDriverMapModal() async {
    final tripsWithGps =
        _filteredTrips.where((trip) => trip.hasDriverGps).toList();
    if (tripsWithGps.isEmpty) {
      showAppSnackBar(
        context,
        message: 'No driver locations available for this tab.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Driver locations',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height * 0.72,
                      child: TripDashboardMapSection(
                        heading: mapHeading(
                          tabIndex: _tabController.index,
                          selectedTripId: null,
                          route: '',
                          detailLoading: false,
                        ),
                        driverTrips: tripsWithGps,
                        driverMarkersInteractive: true,
                        onDriverTripTap: (tripId) {
                          Navigator.of(context).pop();
                          _toggleTripSelection(tripId);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Trip Dashboard'),
        actions: [
          if (!isWide && _selectedTripId == null)
            IconButton(
              tooltip: 'Driver map',
              onPressed: _openDriverMapModal,
              icon: const Icon(Icons.map_outlined),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white70,
            ),
            onPressed: _refreshing ? null : () => _refreshAll(),
            icon: _refreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(
              _refreshing
                  ? 'Refreshing…'
                  : 'Refresh (${_refreshCountdown.toString().padLeft(2, '0')})',
            ),
          ),
          IconButton(
            tooltip: 'Find by doc ID',
            onPressed: _openDocSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null && _allTrips.isEmpty
            ? AppLoadErrorState(
                title: 'Could not load trips',
                message: _loadError!,
                onRetry: () => _refreshAll(initial: true),
                onLoginAgain: widget.onLoginAgain,
              )
            : isWide
            ? _buildWideBody()
            : _buildNarrowBody(),
      ),
    );
  }

  Widget _buildWideBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 1, child: _buildTripListPanel()),
        const VerticalDivider(width: 1),
        Expanded(flex: 2, child: _buildMapPanel(expanded: true)),
      ],
    );
  }

  Widget _buildNarrowBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildTripListPanel()),
        if (_selectedTripId != null) ...[
          const Divider(height: 1),
          SizedBox(height: 320, child: _buildMapPanel(expanded: false)),
        ],
      ],
    );
  }

  Widget _buildTripListPanel() {
    final filtered = _filteredTrips;
    final counts = [
      filterTripsByTab(_allTrips, 0).length,
      filterTripsByTab(_allTrips, 1).length,
      filterTripsByTab(_allTrips, 2).length,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loadError != null)
          MaterialBanner(
            content: Text(_loadError!),
            actions: [
              TextButton(
                onPressed: () => _refreshAll(),
                child: const Text('Retry'),
              ),
            ],
          ),
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Ongoing (${counts[0]})'),
            Tab(text: 'Scheduled (${counts[1]})'),
            Tab(text: 'Ended (${counts[2]})'),
          ],
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(_emptyTabMessage(_tabController.index)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final trip = filtered[index];
                    return _TripCard(
                      key: _keyForTrip(trip.tripId),
                      trip: trip,
                      selected: _selectedTripId == trip.tripId,
                      expanded: _expandedTripIds.contains(trip.tripId),
                      canForceEnd: _canForceEnd && trip.isStarted,
                      onTap: () => _toggleTripSelection(trip.tripId),
                      onToggleExpand: () {
                        setState(() {
                          if (_expandedTripIds.contains(trip.tripId)) {
                            _expandedTripIds.remove(trip.tripId);
                          } else {
                            _expandedTripIds.add(trip.tripId);
                          }
                        });
                      },
                      onForceEnd: () => _confirmForceEnd(trip),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMapPanel({required bool expanded}) {
    final selectedId = _selectedTripId;
    final summary = selectedId != null ? _tripSummary(selectedId) : null;
    final detail = _tripDetail;
    final clusters =
        detail != null ? clusterCustomerMarkers(detail) : <CustomerMapCluster>[];

    final driverTrips = selectedId == null
        ? _filteredTrips.where((t) => t.hasDriverGps).toList()
        : summary != null && summary.hasDriverGps
        ? [summary]
        : <DashboardTripSummary>[];

    final heading = mapHeading(
      tabIndex: _tabController.index,
      selectedTripId: selectedId,
      route: detail?.route ?? summary?.route ?? '',
      detailLoading: _detailLoading,
    );

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selectedId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _deselectTrip,
                icon: const Icon(Icons.grid_view_outlined, size: 18),
                label: const Text('Show all trips'),
              ),
            ),
          if (_detailError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    'Could not load trip details: $_detailError',
                    style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
                  ),
                ),
              ),
            ),
          if (detail != null && selectedId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TripSummaryPanel(
                detail: detail,
                summary: computeTripProgress(detail: detail, now: DateTime.now()),
              ),
            ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: TripDashboardMapSection(
                    heading: heading,
                    driverTrips: driverTrips,
                    tripDetail: selectedId != null ? detail : null,
                    customerClusters: clusters,
                    selectedTripId: selectedId,
                    driverMarkersInteractive: selectedId == null,
                    onDriverTripTap: _toggleTripSelection,
                    onCustomerClusterTap: (cluster) {
                      setState(() => _selectedCluster = cluster);
                    },
                    onMapTap: () => setState(() => _selectedCluster = null),
                  ),
                ),
                if (_selectedCluster != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: CustomerDeliveryCallout(
                      docs: _selectedCluster!.docs,
                      apiClient: widget.apiClient,
                      onClose: () => setState(() => _selectedCluster = null),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _emptyTabMessage(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return 'No ongoing trips found.';
      case 1:
        return 'No scheduled trips found.';
      default:
        return 'No ended trips found.';
    }
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    super.key,
    required this.trip,
    required this.selected,
    required this.expanded,
    required this.canForceEnd,
    required this.onTap,
    required this.onToggleExpand,
    required this.onForceEnd,
  });

  final DashboardTripSummary trip;
  final bool selected;
  final bool expanded;
  final bool canForceEnd;
  final VoidCallback onTap;
  final VoidCallback onToggleExpand;
  final VoidCallback onForceEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusStyle = _statusStyle(trip.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppSurface(
        borderRadius: 14,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.2),
                width: selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        trip.listTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    _StatusChip(style: statusStyle, label: trip.status),
                  ],
                ),
                if (!trip.hasDriverGps && trip.isStarted) ...[
                  const SizedBox(height: 6),
                  const _NoGpsBadge(),
                ],
                if (!expanded)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onToggleExpand,
                      child: const Text('View more'),
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  Text(
                    '${trip.vehicleNumber} · ${trip.driverName} · '
                    'Mob: ${trip.driverPhoneNumber.isEmpty ? '—' : trip.driverPhoneNumber}',
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formatSmartTimestamp(
                      trip.createdAt,
                      suffix: trip.createdBy.isEmpty
                          ? ''
                          : ' by ${trip.createdBy}',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  if (!trip.isScheduled && trip.startedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Started ${formatSmartTimestamp(trip.startedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  if (trip.isEnded && trip.lastUpdatedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ended ${formatSmartTimestamp(trip.lastUpdatedAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  if (canForceEnd) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: onForceEnd,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                      ),
                      child: const Text('Force end trip'),
                    ),
                  ],
                  Row(
                    children: [
                      _StatusChip(style: statusStyle, label: trip.status),
                      TextButton(
                        onPressed: onToggleExpand,
                        child: const Text('View less'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StatusVisual _statusStyle(String status) {
    switch (status.toUpperCase()) {
      case 'STARTED':
        return const _StatusVisual(
          color: Color(0xFF1565C0),
          icon: Icons.check_circle_outline,
        );
      case 'SCHEDULED':
        return const _StatusVisual(
          color: Color(0xFFEF6C00),
          icon: Icons.schedule,
        );
      case 'ENDED':
        return const _StatusVisual(
          color: Color(0xFF757575),
          icon: Icons.cancel_outlined,
        );
      default:
        return const _StatusVisual(
          color: Color(0xFF757575),
          icon: Icons.help_outline,
        );
    }
  }
}

class _StatusVisual {
  const _StatusVisual({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.style, required this.label});

  final _StatusVisual style;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: style.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoGpsBadge extends StatelessWidget {
  const _NoGpsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'No GPS',
        style: TextStyle(
          color: Color(0xFFE65100),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DocSearchDialog extends StatefulWidget {
  const _DocSearchDialog();

  @override
  State<_DocSearchDialog> createState() => _DocSearchDialogState();
}

class _DocSearchDialogState extends State<_DocSearchDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Enter a document ID.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Find by doc ID'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Document ID',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Search'),
        ),
      ],
    );
  }
}

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
import 'trip_map/trip_dashboard_guidance.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_styles.dart';
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
  final _tripCardKeys = <int, GlobalKey>{};
  bool _showGuidance = false;
  Timer? _guidanceTimer;
  String? _docSearchSuccessMessage;
  Timer? _docSearchSuccessTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTripId = null);
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
    _guidanceTimer?.cancel();
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

  Future<void> _forceEnd(int tripId) async {
    final ok = await WebPortalMuiDialog.showForceEndTripWarning(
      context: context,
      tripId: tripId,
    );
    if (ok != true) return;

    try {
      await ref.read(apiClientProvider).forceEndTrip(tripId);
      ref.invalidate(portalAllTripsProvider);
      setState(() => _selectedTripId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Trip has been force ended successfully. All pending deliveries '
              'have been marked as undelivered.',
            ),
          ),
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

  Future<FindByDocIdOutcome> _searchDocById(String docId) async {
    try {
      final result = await ref.read(apiClientProvider).searchDoc(docId);
      if (result.docStatus == 'READY_FOR_DISPATCH') {
        return FindByDocIdOutcome.validation(
          'Document was scanned but not scheduled on a trip yet.',
        );
      }
      if (result.docStatus == 'AT_TRANSIT_HUB') {
        return FindByDocIdOutcome.validation(
          'Document is at a transit hub and not scheduled on the next trip yet.',
        );
      }
      if (result.tripId != null) {
        final tripId = result.tripId!;
        _docSearchSuccessTimer?.cancel();
        setState(() {
          _tabController.index = switch (result.tripStatus) {
            'SCHEDULED' => 1,
            'ENDED' => 2,
            _ => 0,
          };
          _selectedTripId = tripId;
          _docSearchSuccessMessage =
              'Doc found in Trip #$tripId. Trip selected.';
        });
        _docSearchSuccessTimer = Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _docSearchSuccessMessage = null);
        });
        _scrollToTrip(tripId);
        return FindByDocIdOutcome.found;
      }
      return FindByDocIdOutcome.error('Doc ID not found.');
    } on DioException catch (_) {
      return FindByDocIdOutcome.error('Doc ID not found.');
    }
  }

  void _dismissDocSearchSuccess() {
    _docSearchSuccessTimer?.cancel();
    setState(() => _docSearchSuccessMessage = null);
  }

  void _openDocSearchDialog() {
    WebPortalMuiDialog.showFindByDocId(
      context: context,
      onSearch: _searchDocById,
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
          onTripSelected: (id) => _selectTrip(id),
          onClearTripSelection: () => setState(() => _selectedTripId = null),
          mapHeight: mapHeight,
        );

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip Dashboard', style: WebPortalStyles.pageTitle(context)),
              const SizedBox(height: 24),
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 1, child: listPane),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: mapPane),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: listPane),
                          const SizedBox(height: 12),
                          Expanded(flex: 2, child: mapPane),
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

    return WebPortalPaper(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$tabLabel Trips (${trips.length})',
                style: WebPortalStyles.sectionTitle(context),
              ),
              const Spacer(),
              WebPortalLinkText(
                label: 'Find By Doc ID',
                onTap: _openDocSearchDialog,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: AppColors.primary,
            dividerColor: WebPortalStyles.borderColor,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'Ongoing'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Ended'),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: trips.isEmpty
                ? const EmptyState(message: 'No trips in this tab.')
                : Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                        itemCount: trips.length,
                        itemBuilder: (context, i) {
                          final trip = trips[i];
                          final key = _tripCardKeys.putIfAbsent(
                            trip.tripId,
                            GlobalKey.new,
                          );
                          final card = _TripCard(
                            key: key,
                            trip: trip,
                            selected: _selectedTripId == trip.tripId,
                            onTap: () => _selectTrip(trip.tripId),
                            onForceEnd: trip.status ==
                                    AppConstants.tripStatusStarted
                                ? () => _forceEnd(trip.tripId)
                                : null,
                          );
                          if (i == 0 &&
                              _showGuidance &&
                              _tabController.index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const TripDashboardGuidance(),
                                const SizedBox(height: 8),
                                card,
                              ],
                            );
                          }
                          return card;
                        },
                      ),
                      if (_docSearchSuccessMessage != null)
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.center,
                            child: _DocSearchSuccessAlert(
                              message: _docSearchSuccessMessage!,
                              onClose: _dismissDocSearchSuccess,
                            ),
                          ),
                        ),
                    ],
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: widget.selected
                ? WebPortalStyles.selectedTripCardBg
                : Colors.white,
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary
                  : WebPortalStyles.borderColor,
              width: widget.selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip #${trip.tripId} ${trip.route}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    if (!_expanded) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          WebPortalTripStatusChip(status: trip.status),
                          const Spacer(),
                          WebPortalLinkText(
                            label: 'View More',
                            onTap: () => setState(() => _expanded = true),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.directions_car,
                            size: 16,
                            color: WebPortalStyles.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${trip.vehicleNumber} - ${trip.driverName} - Mob: ${trip.driverPhoneNumber}',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.43,
                                color: WebPortalStyles.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      Text(
                        'Created: ${WebPortalUtils.formatTripTimestamp(trip.createdAt)} by ${trip.createdBy}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.66,
                          color: WebPortalStyles.textSecondary,
                        ),
                      ),
                      if (trip.status != AppConstants.tripStatusScheduled)
                        Text(
                          'Started: ${WebPortalUtils.formatTripTimestamp(trip.startedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.66,
                            color: WebPortalStyles.textSecondary,
                          ),
                        ),
                      if (trip.status == 'ENDED')
                        Text(
                          'Ended: ${WebPortalUtils.formatTripTimestamp(trip.lastUpdatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.66,
                            color: WebPortalStyles.textSecondary,
                          ),
                        ),
                      if (widget.onForceEnd != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: widget.onForceEnd,
                            icon: const Icon(Icons.stop_circle, size: 20),
                            label: const Text('Force End Trip'),
                            style: WebPortalStyles.forceEndTripOutlinedButton(),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          WebPortalTripStatusChip(status: trip.status),
                          const Spacer(),
                          WebPortalLinkText(
                            label: 'View Less',
                            onTap: () => setState(() => _expanded = false),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// MUI success [Alert] shown over trip cards after doc search — React parity.
class _DocSearchSuccessAlert extends StatelessWidget {
  const _DocSearchSuccessAlert({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  static const _successGreen = Color(0xFF4CAF50);
  static const _successBg = Color(0xFFE8F5E9);
  static const _successFg = Color(0xFF1B5E20);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final alertWidth = width < 600 ? 300.0 : 400.0;
    final fontSize = width < 600 ? 14.4 : 17.6;

    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(4),
      color: _successBg,
      child: Container(
        width: alertWidth,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _successGreen, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: _successGreen, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: _successFg,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
              color: _successFg,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }
}

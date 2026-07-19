import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../services/trip_heartbeat_service.dart';
import '../../utils/open_maps_location.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'mark_delivered_sheet.dart';
import 'my_trips_models.dart';
import 'report_issue_dialog.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    required this.tripId,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final int tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Future<SingleTripDetails> _future;
  final _expanded = <String, bool>{};
  final _searchControllers = <String, TextEditingController>{};
  final _selectedDocIds = <String>{};
  bool _busy = false;
  String? _driverMismatch;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    for (final c in _searchControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<SingleTripDetails> _load() async {
    final details =
        await widget.apiClient.getSingleTripDetails(tripId: widget.tripId);
    final userId = await JwtPayload.currentUserId();
    if (userId == null || details.driverId != userId) {
      _driverMismatch =
          'This trip is assigned to another driver. You cannot work it in this session.';
    } else {
      _driverMismatch = null;
    }
    for (final group in details.docGroups) {
      _expanded.putIfAbsent(
        group.heading,
        () => group.expandGroupByDefault && !group.dropOffCompleted,
      );
      if (!group.droppable) {
        _searchControllers.putIfAbsent(
          group.heading,
          TextEditingController.new,
        );
      }
      for (final doc in group.docs.where((d) => d.isOnTrip && d.isDirectDelivery)) {
        _selectedDocIds.add(doc.id);
      }
    }
    return details;
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _insurancePing() async {
    if (await JwtPayload.currentIsImpersonation()) return;
    await TripHeartbeatService.instance.pingOnce();
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

  Future<void> _dropOff(TripDocGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Drop Off At Hub'),
        content: Text(
          'Confirm dropping off lot "${group.heading}" at the transit hub?',
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
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await widget.apiClient.dropOffLot(
        tripId: widget.tripId,
        heading: group.heading,
      );
      if (!mounted) return;
      if (result.statusCode == 401 || result.statusCode == 403) {
        await _handleAuth(result.displayMessage);
        return;
      }
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.success
            ? AppSnackBarType.success
            : AppSnackBarType.error,
      );
      if (result.success) {
        await _insurancePing();
        _refresh();
      }
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

  Future<void> _markClusterDelivered(CustomerDeliveryCluster cluster) async {
    final selected = cluster.onTripDocs
        .where((d) => _selectedDocIds.contains(d.id))
        .toList();
    if (selected.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Select at least one document.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    final ok = await showMarkDeliveredSheet(
      context: context,
      apiClient: widget.apiClient,
      tripId: widget.tripId,
      docs: selected,
      onLoginAgain: widget.onLoginAgain,
    );
    if (ok) {
      await _insurancePing();
      _refresh();
    }
  }

  Future<void> _reportIssue(TripDoc doc) async {
    final ok = await showReportIssueDialog(
      context: context,
      apiClient: widget.apiClient,
      docId: doc.id,
      onLoginAgain: widget.onLoginAgain,
    );
    if (ok) {
      await _insurancePing();
      _refresh();
    }
  }

  Future<void> _endTrip() async {
    setState(() => _busy = true);
    try {
      final result = await widget.apiClient.endTrip(tripId: widget.tripId);
      if (!mounted) return;
      if (result.statusCode == 401 || result.statusCode == 403) {
        await _handleAuth(result.displayMessage);
        return;
      }
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.success
            ? AppSnackBarType.success
            : AppSnackBarType.error,
      );
      if (result.success) {
        await TripHeartbeatService.instance.stop();
        if (mounted) Navigator.of(context).pop();
      }
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

  Future<void> _dial(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      showAppSnackBar(
        context,
        message: 'Could not open the phone dialer.',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _openMaps(TripDoc doc) async {
    final lat = doc.customerLat;
    final lng = doc.customerLng;
    if (lat == null || lng == null) return;
    try {
      await openCoordinatesInMaps(latitude: lat, longitude: lng);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: Text('Trip #${widget.tripId} details'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            onPressed: _busy || _driverMismatch != null ? null : _endTrip,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.red.shade700,
            ),
            child: const Text('End Trip'),
          ),
        ),
      ),
      body: Stack(
        children: [
          FutureBuilder<SingleTripDetails>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return AppLoadErrorState(
                  title: 'Could not load trip',
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                  onLoginAgain: widget.onLoginAgain,
                );
              }
              final details = snapshot.data!;
              if (_driverMismatch != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _driverMismatch!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _TripSummaryCard(details: details),
                  const SizedBox(height: 16),
                  for (final group in details.docGroups) ...[
                    _DocGroupSection(
                      group: group,
                      expanded: _expanded[group.heading] ?? false,
                      searchController: _searchControllers[group.heading],
                      selectedDocIds: _selectedDocIds,
                      enabled: !_busy,
                      onToggleExpanded: () {
                        setState(() {
                          final next = !(_expanded[group.heading] ?? false);
                          _expanded[group.heading] = next;
                          if (!next && !group.droppable) {
                            _searchControllers[group.heading]?.clear();
                          }
                        });
                      },
                      onDropOff: () => _dropOff(group),
                      onToggleDoc: (id, selected) {
                        setState(() {
                          if (selected) {
                            _selectedDocIds.add(id);
                          } else {
                            _selectedDocIds.remove(id);
                          }
                        });
                      },
                      onMarkCluster: _markClusterDelivered,
                      onIssue: _reportIssue,
                      onDial: _dial,
                      onMaps: _openMaps,
                      onSearchChanged: () => setState(() {}),
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

class _TripSummaryCard extends StatelessWidget {
  const _TripSummaryCard({required this.details});

  final SingleTripDetails details;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              details.route,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${details.vehicleNumber} - ${details.driverName}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (details.deliveryCountStatusMsg.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(details.deliveryCountStatusMsg),
            ],
            if (details.dropOffCountStatusMsg.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(details.dropOffCountStatusMsg),
            ],
            if (details.createdBy.isNotEmpty ||
                details.createdAtFormatted.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (details.createdBy.isNotEmpty)
                    'Created By ${details.createdBy}',
                  if (details.createdAtFormatted.isNotEmpty)
                    'at ${details.createdAtFormatted}',
                ].join(' '),
                style: const TextStyle(color: Colors.black54, fontSize: 12.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocGroupSection extends StatelessWidget {
  const _DocGroupSection({
    required this.group,
    required this.expanded,
    required this.searchController,
    required this.selectedDocIds,
    required this.enabled,
    required this.onToggleExpanded,
    required this.onDropOff,
    required this.onToggleDoc,
    required this.onMarkCluster,
    required this.onIssue,
    required this.onDial,
    required this.onMaps,
    required this.onSearchChanged,
  });

  final TripDocGroup group;
  final bool expanded;
  final TextEditingController? searchController;
  final Set<String> selectedDocIds;
  final bool enabled;
  final VoidCallback onToggleExpanded;
  final VoidCallback onDropOff;
  final void Function(String docId, bool selected) onToggleDoc;
  final Future<void> Function(CustomerDeliveryCluster cluster) onMarkCluster;
  final Future<void> Function(TripDoc doc) onIssue;
  final Future<void> Function(String phone) onDial;
  final Future<void> Function(TripDoc doc) onMaps;
  final VoidCallback onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final canExpand = !group.dropOffCompleted;
    return AppSurface(
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: canExpand ? onToggleExpanded : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      group.heading,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (group.droppable &&
                      group.showDropOffButton &&
                      group.hasOnTripDocs)
                    TextButton(
                      onPressed: enabled ? onDropOff : null,
                      child: const Text('Drop Off At Hub'),
                    )
                  else if (group.droppable && !group.showDropOffButton)
                    TextButton(
                      onPressed: canExpand ? onToggleExpanded : null,
                      child: const Text('Dropped Off At Hub'),
                    ),
                  if (canExpand)
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
            if (expanded) ...[
            const Divider(height: 1),
            if (!group.droppable && searchController != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: AppSearchField(
                  controller: searchController!,
                  labelText: 'Search deliveries',
                  hintText: 'Doc ID or firm name',
                ),
              ),
            if (group.droppable)
              ..._lotDocs(context)
            else if (searchController != null)
              ListenableBuilder(
                listenable: searchController!,
                builder: (context, _) => Column(
                  children: _directClusters(context),
                ),
              )
            else
              ..._directClusters(context),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  List<Widget> _lotDocs(BuildContext context) {
    return [
      for (final doc in group.docs)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: _DocTile(
            doc: doc,
            selected: selectedDocIds.contains(doc.id),
            showActions: false,
            enabled: enabled,
            onToggle: null,
            onIssue: null,
            onDial: doc.customerPhone.trim().isEmpty
                ? null
                : () => onDial(doc.customerPhone.trim()),
            onMaps: doc.hasCustomerGeo ? () => onMaps(doc) : null,
          ),
        ),
    ];
  }

  List<Widget> _directClusters(BuildContext context) {
    final query = searchController?.text.trim().toLowerCase() ?? '';
    var docs = group.docs;
    if (query.isNotEmpty) {
      docs = docs
          .where(
            (d) =>
                d.id.toLowerCase().contains(query) ||
                d.customerFirmName.toLowerCase().contains(query),
          )
          .toList();
    }
    if (docs.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No results',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
          ),
        ),
      ];
    }

    final clusters = clusterDirectDeliveries(docs);
    return [
      for (final cluster in clusters)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: _CustomerClusterCard(
            cluster: cluster,
            selectedDocIds: selectedDocIds,
            enabled: enabled,
            onToggleDoc: onToggleDoc,
            onMarkCluster: () => onMarkCluster(cluster),
            onIssue: onIssue,
            onDial: onDial,
            onMaps: onMaps,
          ),
        ),
    ];
  }
}

class _CustomerClusterCard extends StatelessWidget {
  const _CustomerClusterCard({
    required this.cluster,
    required this.selectedDocIds,
    required this.enabled,
    required this.onToggleDoc,
    required this.onMarkCluster,
    required this.onIssue,
    required this.onDial,
    required this.onMaps,
  });

  final CustomerDeliveryCluster cluster;
  final Set<String> selectedDocIds;
  final bool enabled;
  final void Function(String docId, bool selected) onToggleDoc;
  final VoidCallback onMarkCluster;
  final Future<void> Function(TripDoc doc) onIssue;
  final Future<void> Function(String phone) onDial;
  final Future<void> Function(TripDoc doc) onMaps;

  @override
  Widget build(BuildContext context) {
    final rep = cluster.representative;
    final onTrip = cluster.onTripDocs;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              rep.customerFirmName.isEmpty
                  ? 'Customer ${cluster.customerId}'
                  : rep.customerFirmName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if (rep.addressLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(rep.addressLine, style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (rep.customerPhone.trim().isNotEmpty)
                  TextButton.icon(
                    onPressed: enabled
                        ? () => onDial(rep.customerPhone.trim())
                        : null,
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                  ),
                if (rep.hasCustomerGeo)
                  TextButton.icon(
                    onPressed: enabled ? () => onMaps(rep) : null,
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('Navigate'),
                  ),
              ],
            ),
            for (final doc in cluster.docs) ...[
              const Divider(height: 16),
              _DocTile(
                doc: doc,
                selected: selectedDocIds.contains(doc.id),
                showActions: doc.isOnTrip,
                enabled: enabled,
                onToggle: doc.isOnTrip
                    ? (value) => onToggleDoc(doc.id, value)
                    : null,
                onIssue: doc.isOnTrip ? () => onIssue(doc) : null,
                onDial: null,
                onMaps: null,
              ),
            ],
            if (onTrip.isNotEmpty) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: enabled ? onMarkCluster : null,
                child: Text(
                  onTrip.length == 1
                      ? 'Mark delivered'
                      : 'Mark delivered (${onTrip.where((d) => selectedDocIds.contains(d.id)).length} selected)',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.doc,
    required this.selected,
    required this.showActions,
    required this.enabled,
    required this.onToggle,
    required this.onIssue,
    required this.onDial,
    required this.onMaps,
  });

  final TripDoc doc;
  final bool selected;
  final bool showActions;
  final bool enabled;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onIssue;
  final VoidCallback? onDial;
  final VoidCallback? onMaps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (onToggle != null)
              Checkbox(
                value: selected,
                onChanged: enabled
                    ? (value) => onToggle!(value ?? false)
                    : null,
              ),
            Expanded(
              child: Text(
                doc.id,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(
              doc.statusLabel,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: doc.isDelivered
                    ? Colors.green.shade700
                    : doc.isUndelivered
                        ? Colors.red.shade700
                        : Colors.black87,
              ),
            ),
          ],
        ),
        if (doc.docAmount.isNotEmpty)
          Text('Amount: ${doc.docAmount}',
              style: const TextStyle(color: Colors.black54)),
        if (doc.comment.isNotEmpty)
          Text(doc.comment, style: const TextStyle(color: Colors.black54)),
        if (showActions)
          Row(
            children: [
              TextButton(
                onPressed: enabled ? onIssue : null,
                child: const Text('Issue'),
              ),
            ],
          ),
        if (onDial != null || onMaps != null)
          Row(
            children: [
              if (onDial != null)
                IconButton(
                  onPressed: enabled ? onDial : null,
                  icon: const Icon(Icons.phone),
                ),
              if (onMaps != null)
                IconButton(
                  onPressed: enabled ? onMaps : null,
                  icon: const Icon(Icons.navigation_outlined),
                ),
            ],
          ),
      ],
    );
  }
}

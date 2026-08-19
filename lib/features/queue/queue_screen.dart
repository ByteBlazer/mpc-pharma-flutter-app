import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'queue_models.dart';
import 'schedule_new_trip_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  late Future<DispatchQueueResponse> _future;
  List<RouteSummary>? _routes;
  String? _emptyMessage;
  bool _unscanning = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Future<DispatchQueueResponse> _load() async {
    final response = await widget.apiClient.getDispatchQueueList();
    if (!mounted) return response;
    setState(() {
      _routes = response.routes;
      _emptyMessage =
          response.message.isNotEmpty ? response.message : 'No data found';
    });
    return response;
  }

  void _refresh() {
    setState(() {
      _routes = null;
      _future = _load();
    });
  }

  Future<void> _handleAuthIfNeeded(Object error) async {
    if (!isAuthErrorMessage(error)) return;
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: error.toString(),
      type: AppSnackBarType.error,
    );
    await widget.onLoginAgain();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _toggleBatch(QueueBatch batch) {
    setState(() => batch.isChecked = !batch.isChecked);
  }

  Future<void> _openDocsSheet(QueueBatch batch) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DocumentsSheet(
        batch: batch,
        onDeleteDoc: (docId) async {
          final ok = await _unscanDoc(docId);
          if (ok) _refresh();
        },
      ),
    );
  }

  Future<bool> _unscanDoc(String docId) async {
    setState(() => _unscanning = true);
    try {
      final result = await widget.apiClient.scanDoc(
        barcode: docId,
        unscan: true,
      );
      if (!mounted) return false;
      if (result.statusCode == 401 ||
          result.statusCode == 403 ||
          isAuthErrorMessage(result.message)) {
        showAppSnackBar(
          context,
          message: result.displayMessage,
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return false;
      }
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.success ? AppSnackBarType.success : AppSnackBarType.error,
      );
      return result.success;
    } catch (error) {
      if (!mounted) return false;
      if (isAuthErrorMessage(error)) {
        await _handleAuthIfNeeded(error);
        return false;
      }
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
      return false;
    } finally {
      if (mounted) setState(() => _unscanning = false);
    }
  }

  void _onScheduleTrip() {
    final routes = _routes;
    if (routes == null) return;

    final selectedByRoute = <String, List<QueueBatch>>{};
    for (final route in routes) {
      final checked = route.batches.where((b) => b.isChecked).toList();
      if (checked.isNotEmpty) {
        selectedByRoute[route.route] = checked;
      }
    }

    if (selectedByRoute.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Please select a route',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (selectedByRoute.length > 1) {
      showAppSnackBar(
        context,
        message:
            'You cannot mix routes. Please select from only a single route.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final routeName = selectedByRoute.keys.first;
    final batches =
        selectedByRoute[routeName]!.map((b) => b.toSelection()).toList();

    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ScheduleNewTripScreen(
          apiClient: widget.apiClient,
          onLoginAgain: widget.onLoginAgain,
          route: routeName,
          batches: batches,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _unscanning ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _unscanning ? null : _onScheduleTrip,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Trip'),
      ),
      body: Stack(
        children: [
          FutureBuilder<DispatchQueueResponse>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                final error = snapshot.error!;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _handleAuthIfNeeded(error);
                });
                return AppLoadErrorState(
                  title: 'Could not load queue',
                  message: error.toString(),
                  onRetry: _refresh,
                  onLoginAgain: widget.onLoginAgain,
                );
              }

              final routes = _routes ?? const <RouteSummary>[];
              if (routes.isEmpty) {
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

              final filteredRoutes = routes
                  .map((route) => route.filterForSearch(_searchQuery))
                  .whereType<QueueRouteSearchResult>()
                  .toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  const Text(
                    'Select docs from any one route',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppSearchField(
                    controller: _searchController,
                    labelText: 'Search routes or Doc ID',
                    hintText: 'Route name or document ID...',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${filteredRoutes.length} of ${routes.length} routes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredRoutes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No routes match the search.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    for (final entry in filteredRoutes) ...[
                    Text(
                      entry.route.route.isEmpty
                          ? 'Unknown route'
                          : entry.route.route,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    for (final batch in entry.visibleBatches) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 10),
                        child: _BatchCard(
                          batch: batch,
                          onToggle: () => _toggleBatch(batch),
                          onInfo: () => _openDocsSheet(batch),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              );
            },
          ),
          if (_unscanning)
            const ColoredBox(
              color: Color(0x66000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _BatchCard extends StatelessWidget {
  const _BatchCard({
    required this.batch,
    required this.onToggle,
    required this.onInfo,
  });

  final QueueBatch batch;
  final VoidCallback onToggle;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      borderRadius: 14,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (batch.scannedFromLocation.isNotEmpty)
                      Text(
                        batch.scannedFromLocation,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Documents Scanned: ${batch.count}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'View documents',
                          onPressed: onInfo,
                          icon: const Icon(Icons.info_outline, size: 20),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (batch.scannedByName.isNotEmpty)
                      Text(
                        batch.scannedByName,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              Checkbox(
                value: batch.isChecked,
                onChanged: (_) => onToggle(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentsSheet extends StatefulWidget {
  const _DocumentsSheet({
    required this.batch,
    required this.onDeleteDoc,
  });

  final QueueBatch batch;
  final Future<void> Function(String docId) onDeleteDoc;

  @override
  State<_DocumentsSheet> createState() => _DocumentsSheetState();
}

class _DocumentsSheetState extends State<_DocumentsSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    final docs = widget.batch.docIdList;
    if (_query.isEmpty) return docs;
    return docs
        .where((id) => id.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Future<void> _confirmDelete(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to remove this Doc ID $docId from the queue? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    Navigator.of(context).pop(); // close sheet before overlay
    await widget.onDeleteDoc(docId);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Documents Scanned',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSearchField(
                  controller: _searchController,
                  labelText: 'Search Doc ID',
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No data found',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final docId = filtered[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.only(left: 4),
                            title: Text(
                              docId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove from queue',
                              onPressed: () => _confirmDelete(docId),
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade700,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

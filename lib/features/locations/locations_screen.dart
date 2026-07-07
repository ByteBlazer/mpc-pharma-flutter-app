import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_list_controls_row.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_sort_controls.dart';
import '../users/user_models.dart';
import 'location_form_screen.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _searchController = TextEditingController();
  late Future<List<BaseLocation>> _locationsFuture;
  String _searchQuery = '';
  AppSortField _sortField = AppSortField.id;
  AppSortDirection _sortDirection = AppSortDirection.descending;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _locationsFuture = widget.apiClient.getBaseLocations();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    setState(() => _searchQuery = _searchController.text);
  }

  void _changeSort(AppSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortDirection = _sortDirection == AppSortDirection.ascending
            ? AppSortDirection.descending
            : AppSortDirection.ascending;
      } else {
        _sortField = field;
        _sortDirection = AppSortDirection.ascending;
      }
    });
  }

  void _refresh() {
    setState(() {
      _locationsFuture = widget.apiClient.getBaseLocations();
    });
  }

  Future<void> _addLocation() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LocationFormScreen(apiClient: widget.apiClient),
      ),
    );
    if (saved == true) {
      _showSuccessMessage('Location added successfully.');
      _refresh();
    }
  }

  Future<void> _editLocation(BaseLocation location) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LocationFormScreen(apiClient: widget.apiClient, location: location),
      ),
    );
    if (saved == true) {
      _showSuccessMessage('Location updated successfully.');
      _refresh();
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message: message, type: AppSnackBarType.success);
  }

  Future<void> _downloadLocations(List<BaseLocation> locations) async {
    try {
      final fileName =
          'mpc-pharma-locations-${DateTime.now().millisecondsSinceEpoch}.csv';
      await downloadFile(
        fileName: fileName,
        bytes: utf8.encode(_locationsToCsv(locations)),
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  String _locationsToCsv(List<BaseLocation> locations) {
    final rows = <List<String>>[
      ['ID', 'Name'],
      ...locations.map((location) => [location.id, location.name]),
    ];

    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  int _compareLocations(BaseLocation first, BaseLocation second) {
    final result = switch (_sortField) {
      AppSortField.name => first.name.toLowerCase().compareTo(
        second.name.toLowerCase(),
      ),
      AppSortField.id => _numericId(first.id).compareTo(_numericId(second.id)),
    };
    return _sortDirection == AppSortDirection.ascending ? result : -result;
  }

  int _numericId(String id) => int.tryParse(id) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locations')),
      body: SafeArea(
        child: FutureBuilder<List<BaseLocation>>(
          future: _locationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final locations = snapshot.data ?? const <BaseLocation>[];
            final visibleLocations = _showInactive
                ? locations
                : locations.where((location) => location.isActive).toList();
            final filteredLocations = visibleLocations
                .where((location) => location.matchesSearch(_searchQuery))
                .toList();
            filteredLocations.sort(_compareLocations);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchAndActions(
                        controller: _searchController,
                        shownCount: filteredLocations.length,
                        totalCount: visibleLocations.length,
                        sortField: _sortField,
                        sortDirection: _sortDirection,
                        showInactive: _showInactive,
                        onShowInactiveChanged: (value) {
                          setState(() => _showInactive = value);
                        },
                        onSortChanged: _changeSort,
                        onAddLocation: _addLocation,
                        onDownloadLocations: () =>
                            _downloadLocations(locations),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _LocationsSection(
                          locations: filteredLocations,
                          sortField: _sortField,
                          sortDirection: _sortDirection,
                          onEditLocation: _editLocation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndActions extends StatelessWidget {
  const _SearchAndActions({
    required this.controller,
    required this.shownCount,
    required this.totalCount,
    required this.sortField,
    required this.sortDirection,
    required this.showInactive,
    required this.onShowInactiveChanged,
    required this.onSortChanged,
    required this.onAddLocation,
    required this.onDownloadLocations,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final bool showInactive;
  final ValueChanged<bool> onShowInactiveChanged;
  final ValueChanged<AppSortField> onSortChanged;
  final VoidCallback onAddLocation;
  final VoidCallback onDownloadLocations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final search = AppSearchField(
          controller: controller,
          labelText: 'Search locations',
          hintText: 'ID or location name...',
        );
        final addLocation = ElevatedButton.icon(
          onPressed: onAddLocation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('New Location'),
        );
        final download = OutlinedButton.icon(
          onPressed: onDownloadLocations,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download'),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocationsCountText(
                shownCount: shownCount,
                totalCount: totalCount,
              ),
              const SizedBox(height: 8),
              search,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: download),
                  const SizedBox(width: 12),
                  Expanded(child: addLocation),
                ],
              ),
              const SizedBox(height: 8),
              AppListControlsRow(
                sortField: sortField,
                sortDirection: sortDirection,
                showInactive: showInactive,
                onShowInactiveChanged: onShowInactiveChanged,
                onSortChanged: onSortChanged,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LocationsCountText(shownCount: shownCount, totalCount: totalCount),
            const SizedBox(height: 8),
            search,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [download, addLocation],
              ),
            ),
            const SizedBox(height: 8),
            AppListControlsRow(
              sortField: sortField,
              sortDirection: sortDirection,
              showInactive: showInactive,
              onShowInactiveChanged: onShowInactiveChanged,
              onSortChanged: onSortChanged,
            ),
          ],
        );
      },
    );
  }
}

class _LocationsCountText extends StatelessWidget {
  const _LocationsCountText({
    required this.shownCount,
    required this.totalCount,
  });

  final int shownCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$shownCount of $totalCount locations',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LocationsSection extends StatefulWidget {
  const _LocationsSection({
    required this.locations,
    required this.sortField,
    required this.sortDirection,
    required this.onEditLocation,
  });

  final List<BaseLocation> locations;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final ValueChanged<BaseLocation> onEditLocation;

  @override
  State<_LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<_LocationsSection> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_LocationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sortField != widget.sortField ||
        oldWidget.sortDirection != widget.sortDirection) {
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locations.isEmpty) {
      return const _EmptyState(message: 'No locations match the search.');
    }

    return AppScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 20),
        itemCount: widget.locations.length,
        itemBuilder: (context, index) {
          final location = widget.locations[index];
          return _LocationListItem(
            location: location,
            onEdit: () => widget.onEditLocation(location),
          );
        },
      ),
    );
  }
}

class _LocationListItem extends StatelessWidget {
  const _LocationListItem({required this.location, required this.onEdit});

  final BaseLocation location;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _SmallInfo(
                  icon: Icons.location_on_outlined,
                  text: location.name,
                ),
              ),
              const SizedBox(width: 8),
              _SmallInfo(icon: Icons.badge_outlined, text: location.id),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Edit location',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.black),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.black)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onLoginAgain,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLoginAgain;

  bool get _isAuthError {
    final normalized = message.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('expired') ||
        normalized.contains('unauthorized') ||
        normalized.contains('401');
  }

  Future<void> _loginAgain(BuildContext context) async {
    await onLoginAgain();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Failed to load Locations',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isAuthError
                        ? () => _loginAgain(context)
                        : onRetry,
                    child: Text(_isAuthError ? 'Login Again' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

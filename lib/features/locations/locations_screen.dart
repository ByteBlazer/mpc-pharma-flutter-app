import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/download_file.dart';
import '../users/user_models.dart';
import 'location_form_screen.dart';

class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _searchController = TextEditingController();
  late Future<List<BaseLocation>> _locationsFuture;
  String _searchQuery = '';

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
    if (saved == true) _refresh();
  }

  Future<void> _editLocation(BaseLocation location) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            LocationFormScreen(apiClient: widget.apiClient, location: location),
      ),
    );
    if (saved == true) _refresh();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
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
              );
            }

            final locations = snapshot.data ?? const <BaseLocation>[];
            final filteredLocations = locations
                .where((location) => location.matchesSearch(_searchQuery))
                .toList();

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
                        totalCount: locations.length,
                        onAddLocation: _addLocation,
                        onDownloadLocations: () =>
                            _downloadLocations(locations),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _LocationsSection(
                          locations: filteredLocations,
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
    required this.onAddLocation,
    required this.onDownloadLocations,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final VoidCallback onAddLocation;
  final VoidCallback onDownloadLocations;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final search = TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search locations',
            prefixIcon: Icon(Icons.search),
            hintText: 'ID or location name...',
          ),
        );
        final addLocation = ElevatedButton.icon(
          onPressed: onAddLocation,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add New Location'),
        );
        final download = OutlinedButton.icon(
          onPressed: onDownloadLocations,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Download as Excel'),
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
    required this.onEditLocation,
  });

  final List<BaseLocation> locations;
  final ValueChanged<BaseLocation> onEditLocation;

  @override
  State<_LocationsSection> createState() => _LocationsSectionState();
}

class _LocationsSectionState extends State<_LocationsSection> {
  final _scrollController = ScrollController();

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

    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 8,
      radius: const Radius.circular(999),
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
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
                    onPressed: onRetry,
                    child: const Text('Retry'),
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

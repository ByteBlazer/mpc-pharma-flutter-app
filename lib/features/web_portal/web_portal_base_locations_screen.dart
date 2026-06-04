import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'web_portal_providers.dart';

class WebPortalBaseLocationsScreen extends ConsumerStatefulWidget {
  const WebPortalBaseLocationsScreen({super.key});

  @override
  ConsumerState<WebPortalBaseLocationsScreen> createState() =>
      _WebPortalBaseLocationsScreenState();
}

class _WebPortalBaseLocationsScreenState
    extends ConsumerState<WebPortalBaseLocationsScreen> {
  final _searchController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WebPortalBaseLocation> _filterAndSort(List<WebPortalBaseLocation> list) {
    final q = _searchController.text.trim().toLowerCase();
    var filtered = list.where((l) {
      if (q.isEmpty) return true;
      return l.id.toLowerCase().contains(q) ||
          l.name.toLowerCase().contains(q);
    }).toList();
    filtered.sort((a, b) => a.id.compareTo(b.id));
    return filtered;
  }

  Future<void> _showLocationDialog({WebPortalBaseLocation? location}) async {
    final nameController = TextEditingController(text: location?.name ?? '');
    final isAdd = location == null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAdd ? 'Add Base Location' : 'Edit Base Location'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name *'),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isAdd ? 'Create' : 'Update'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final name = nameController.text.trim();
    if (name.isEmpty || name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid name (1-50 chars)')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      if (location != null) {
        await api.updatePortalBaseLocation(location.id, name: name);
      } else {
        await api.createPortalBaseLocation(name: name);
      }
      ref.invalidate(portalBaseLocationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAdd
                  ? 'Base location created successfully!'
                  : 'Base location updated successfully!',
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(portalBaseLocationsProvider);

    return locationsAsync.when(
      loading: () => const LoadingOverlay(message: 'Loading base locations...'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(portalBaseLocationsProvider),
      ),
      data: (locations) {
        final filtered = _filterAndSort(locations);
        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        'Base Locations',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _showLocationDialog(),
                        child: const Text('Add Base Location'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search base locations by ID or name...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final loc = filtered[index];
                      return Card(
                        child: ListTile(
                          title: Text(loc.name),
                          subtitle: Text('ID: ${loc.id}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showLocationDialog(location: loc),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_saving) const LoadingOverlay(message: 'Saving...'),
          ],
        );
      },
    );
  }
}

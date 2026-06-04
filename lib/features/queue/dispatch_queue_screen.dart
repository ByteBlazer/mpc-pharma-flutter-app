import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class DispatchQueueScreen extends ConsumerStatefulWidget {
  const DispatchQueueScreen({super.key});

  @override
  ConsumerState<DispatchQueueScreen> createState() =>
      _DispatchQueueScreenState();
}

class _DispatchQueueScreenState extends ConsumerState<DispatchQueueScreen> {
  DispatchQueueResponse? _data;
  bool _loading = true;
  String? _error;
  String? _selectedRoute;
  final Map<String, UserSummaryList> _selectedUsers = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).getDispatchQueue();
      setState(() => _data = response);
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleUser(String route, UserSummaryList user) {
    setState(() {
      if (_selectedRoute != null && _selectedRoute != route) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select docs from any one route')),
        );
        return;
      }

      final key = '${user.scannedByUserId}';
      if (_selectedUsers.containsKey(key)) {
        _selectedUsers.remove(key);
        if (_selectedUsers.isEmpty) _selectedRoute = null;
      } else {
        _selectedRoute = route;
        _selectedUsers[key] = user;
      }
    });
  }

  Future<void> _unscanDoc(String docId) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Deletion',
      message: 'Remove document $docId from queue?',
    );
    if (confirmed != true) return;

    try {
      await ref.read(apiClientProvider).scanDoc(barcode: docId, unscan: true);
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  void _scheduleTrip() {
    if (_selectedRoute == null || _selectedUsers.isEmpty) return;
    final userIds = _selectedUsers.values
        .map((u) => u.scannedByUserId)
        .whereType<String>()
        .toList();
    context.push(
      '${AppRoutes.scheduleTrip}?route=${Uri.encodeComponent(_selectedRoute!)}&users=${Uri.encodeComponent(jsonEncode(userIds))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(queueRefreshProvider, (_, __) => _load());

    if (_loading) return const LoadingOverlay();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final routes = _data?.dispatchQueueList?.routeSummaryList ?? [];
    if (routes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EmptyState(message: 'No data found'),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _selectedUsers.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _scheduleTrip,
              icon: const Icon(Icons.add),
              label: const Text('Schedule Trip'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final routeGroup = routes[index];
            final routeName = routeGroup.route ?? 'Unknown';
            final users = routeGroup.userSummaryList ?? [];
            return Card(
              child: ExpansionTile(
                title: Text(routeName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${users.length} scanner(s)'),
                children: users.map((user) {
                  final selected = _selectedUsers.containsKey('${user.scannedByUserId}');
                  return Column(
                    children: [
                      CheckboxListTile(
                        value: selected,
                        onChanged: (_) => _toggleUser(routeName, user),
                        title: Text(user.scannedByName ?? 'Unknown'),
                        subtitle: Text(
                          '${user.scannedFromLocation ?? ''} • ${user.count ?? 0} docs',
                        ),
                        secondary: IconButton(
                          icon: const Icon(Icons.list),
                          onPressed: () => _showDocList(user),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDocList(UserSummaryList user) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final docs = user.docIdList ?? [];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Documents (${docs.length})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final docId = docs[index];
                      return ListTile(
                        title: Text(docId),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            Navigator.pop(context);
                            _unscanDoc(docId);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

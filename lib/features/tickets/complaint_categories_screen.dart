import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_list_controls_row.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_sort_controls.dart';
import '../departments/department_models.dart';
import 'complaint_category_form_screen.dart';
import 'ticket_models.dart';

class ComplaintCategoriesScreen extends StatefulWidget {
  const ComplaintCategoriesScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<ComplaintCategoriesScreen> createState() =>
      _ComplaintCategoriesScreenState();
}

class _ComplaintCategoriesScreenState extends State<ComplaintCategoriesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _loader = AppAsyncListLoader<_ComplaintCategoriesData>();
  String _searchQuery = '';
  bool _showInactive = false;
  AppSortField _sortField = AppSortField.name;
  AppSortDirection _sortDirection = AppSortDirection.ascending;

  @override
  void initState() {
    super.initState();
    _loader.initialize(_loadData);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<_ComplaintCategoriesData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getComplaintCategories(),
      widget.apiClient.getDepartments(),
    ]);
    return _ComplaintCategoriesData(
      categories: results[0] as List<ComplaintCategory>,
      departments: results[1] as List<Department>,
    );
  }

  Future<void> _refresh() {
    return _loader.reload(load: _loadData, setState: setState);
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message: message, type: AppSnackBarType.success);
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

  int _compareCategories(ComplaintCategory a, ComplaintCategory b) {
    final direction = _sortDirection == AppSortDirection.ascending ? 1 : -1;
    return switch (_sortField) {
      AppSortField.id => direction * a.id.compareTo(b.id),
      AppSortField.name => direction * a.name.compareTo(b.name),
    };
  }

  Future<void> _addCategory(_ComplaintCategoriesData data) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplaintCategoryFormScreen(
          apiClient: widget.apiClient,
          departments: data.departments,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    _showSuccessMessage('Category added successfully.');
    await _refresh();
  }

  Future<void> _editCategory(
    _ComplaintCategoriesData data,
    ComplaintCategory category,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ComplaintCategoryFormScreen(
          apiClient: widget.apiClient,
          departments: data.departments,
          category: category,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    _showSuccessMessage('Category updated successfully.');
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Complaint categories'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final data = await _loader.future;
          if (!mounted) return;
          await _addCategory(data);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add category'),
      ),
      body: SafeArea(
        child: FutureBuilder<_ComplaintCategoriesData>(
          key: ValueKey(_loader.refreshToken),
          future: _loader.future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Failed to load complaint categories',
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final data = snapshot.data ?? _ComplaintCategoriesData.empty();
            final visibleCategories = _showInactive
                ? data.categories
                : data.categories.where((category) => category.isActive).toList();
            final filtered = visibleCategories
                .where((category) => category.matchesSearch(_searchQuery))
                .toList()
              ..sort(_compareCategories);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchField(
                        controller: _searchController,
                        labelText: 'Search categories',
                        hintText: 'Name, department...',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Showing ${filtered.length} of ${data.categories.length} categories',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      AppListControlsRow(
                        sortField: _sortField,
                        sortDirection: _sortDirection,
                        showInactive: _showInactive,
                        onShowInactiveChanged: (value) =>
                            setState(() => _showInactive = value),
                        onSortChanged: _changeSort,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No complaint categories match the search.',
                                  style: TextStyle(color: Colors.black),
                                ),
                              )
                            : AppScrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(right: 20),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final category = filtered[index];
                                    return _ComplaintCategoryCard(
                                      category: category,
                                      onEdit: () => _editCategory(data, category),
                                    );
                                  },
                                ),
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
    ),
    );
  }
}

class _ComplaintCategoryCard extends StatelessWidget {
  const _ComplaintCategoryCard({
    required this.category,
    required this.onEdit,
  });

  final ComplaintCategory category;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final textColor = category.isActive ? Colors.black : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AppSurface(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category.assignedDepartmentName,
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID ${category.id}',
                      style: TextStyle(color: textColor.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              _StatusPill(isActive: category.isActive),
              IconButton(
                tooltip: 'Edit category',
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primary : Colors.black,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}

class _ComplaintCategoriesData {
  const _ComplaintCategoriesData({
    required this.categories,
    required this.departments,
  });

  final List<ComplaintCategory> categories;
  final List<Department> departments;

  factory _ComplaintCategoriesData.empty() => const _ComplaintCategoriesData(
    categories: [],
    departments: [],
  );
}

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../../auth/app_role.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_list_controls_row.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_sort_controls.dart';
import '../users/user_models.dart';
import 'department_form_screen.dart';
import 'department_models.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final _searchController = TextEditingController();
  late Future<_DepartmentsData> _dataFuture;
  String _searchQuery = '';
  AppSortField _sortField = AppSortField.id;
  AppSortDirection _sortDirection = AppSortDirection.descending;
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
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

  Future<_DepartmentsData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getDepartments(),
      widget.apiClient.getUsers(),
      _loadHasWebAccess(),
    ]);

    return _DepartmentsData(
      departments: results[0] as List<Department>,
      users: results[1] as List<UserAccount>,
      hasWebAccess: results[2] as bool,
    );
  }

  Future<bool> _loadHasWebAccess() async {
    final token = await AuthTokenStore().readToken();
    if (token == null) return false;

    final parts = token.split('.');
    if (parts.length < 2) return false;

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) return false;

    final roles = json['roles']?.toString().split(',').toAppRoles() ?? const [];
    return roles.hasRole(AppRole.webAccess);
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _addDepartment(_DepartmentsData data) async {
    if (!data.hasWebAccess) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DepartmentFormScreen(
          apiClient: widget.apiClient,
          availableUsers: data.users,
        ),
      ),
    );
    if (saved == true) {
      _showSuccessMessage('Department added successfully.');
      _refresh();
    }
  }

  Future<void> _editDepartment(
    _DepartmentsData data,
    Department department,
  ) async {
    if (!data.hasWebAccess) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DepartmentFormScreen(
          apiClient: widget.apiClient,
          availableUsers: data.users,
          department: department,
        ),
      ),
    );
    if (saved == true) {
      _showSuccessMessage('Department updated successfully.');
      _refresh();
    }
  }

  Future<void> _toggleLead({
    required Department department,
    required DepartmentUser user,
  }) async {
    try {
      await widget.apiClient.setDepartmentLead(
        departmentId: department.id,
        userId: user.id,
        isDepartmentLead: !user.isDepartmentLead,
      );
      if (!mounted) return;
      _showSuccessMessage(
        user.isDepartmentLead
            ? '${user.personName} unmarked as lead.'
            : '${user.personName} marked as lead.',
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message: message, type: AppSnackBarType.success);
  }

  Future<void> _downloadDepartments(List<Department> departments) async {
    try {
      final fileName =
          'mpc-pharma-departments-${DateTime.now().millisecondsSinceEpoch}.csv';
      await downloadFile(
        fileName: fileName,
        bytes: utf8.encode(_departmentsToCsv(departments)),
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

  String _departmentsToCsv(List<Department> departments) {
    final rows = <List<String>>[
      [
        'Department ID',
        'Department Name',
        'Department Active',
        'User ID',
        'Person Name',
        'Mobile',
        'Is Lead',
      ],
      for (final department in departments)
        if (department.users.isEmpty)
          [
            department.id,
            department.name,
            department.isActive ? 'Yes' : 'No',
            '',
            '',
            '',
            '',
          ]
        else
          for (final user in department.users)
            [
              department.id,
              department.name,
              department.isActive ? 'Yes' : 'No',
              user.id,
              user.personName,
              user.mobile,
              user.isDepartmentLead ? 'Yes' : 'No',
            ],
    ];

    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  int _compareDepartments(Department first, Department second) {
    final activeCompare = second.isActive == first.isActive
        ? 0
        : (first.isActive ? -1 : 1);
    if (activeCompare != 0) return activeCompare;

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
      appBar: AppBar(title: const Text('Departments')),
      body: SafeArea(
        child: FutureBuilder<_DepartmentsData>(
          future: _dataFuture,
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

            final data = snapshot.data ?? _DepartmentsData.empty();
            final visibleDepartments = _showInactive
                ? data.departments
                : data.departments
                      .where((department) => department.isActive)
                      .toList();
            final filteredDepartments = visibleDepartments
                .where((department) => department.matchesSearch(_searchQuery))
                .toList();
            filteredDepartments.sort(_compareDepartments);

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
                        shownCount: filteredDepartments.length,
                        totalCount: visibleDepartments.length,
                        sortField: _sortField,
                        sortDirection: _sortDirection,
                        showInactive: _showInactive,
                        onShowInactiveChanged: (value) {
                          setState(() => _showInactive = value);
                        },
                        onSortChanged: _changeSort,
                        canManage: data.hasWebAccess,
                        onAddDepartment: () => _addDepartment(data),
                        onDownloadDepartments: () =>
                            _downloadDepartments(data.departments),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _DepartmentsSection(
                          departments: filteredDepartments,
                          sortField: _sortField,
                          sortDirection: _sortDirection,
                          canManage: data.hasWebAccess,
                          onEditDepartment: (department) =>
                              _editDepartment(data, department),
                          onToggleLead: _toggleLead,
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
    required this.canManage,
    required this.onAddDepartment,
    required this.onDownloadDepartments,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final bool showInactive;
  final ValueChanged<bool> onShowInactiveChanged;
  final ValueChanged<AppSortField> onSortChanged;
  final bool canManage;
  final VoidCallback onAddDepartment;
  final VoidCallback onDownloadDepartments;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final search = TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search departments',
            prefixIcon: Icon(Icons.search),
            hintText: 'Department name, user name, mobile...',
          ),
        );
        final addDepartment = ElevatedButton.icon(
          onPressed: canManage ? onAddDepartment : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('Add New Dept'),
        );
        final download = OutlinedButton.icon(
          onPressed: onDownloadDepartments,
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
              _DepartmentsCountText(
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
                  Expanded(child: addDepartment),
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
            _DepartmentsCountText(
              shownCount: shownCount,
              totalCount: totalCount,
            ),
            const SizedBox(height: 8),
            search,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [download, addDepartment],
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

class _DepartmentsCountText extends StatelessWidget {
  const _DepartmentsCountText({
    required this.shownCount,
    required this.totalCount,
  });

  final int shownCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$shownCount of $totalCount departments',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DepartmentsSection extends StatefulWidget {
  const _DepartmentsSection({
    required this.departments,
    required this.sortField,
    required this.sortDirection,
    required this.canManage,
    required this.onEditDepartment,
    required this.onToggleLead,
  });

  final List<Department> departments;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final bool canManage;
  final ValueChanged<Department> onEditDepartment;
  final Future<void> Function({
    required Department department,
    required DepartmentUser user,
  })
  onToggleLead;

  @override
  State<_DepartmentsSection> createState() => _DepartmentsSectionState();
}

class _DepartmentsSectionState extends State<_DepartmentsSection> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_DepartmentsSection oldWidget) {
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
    if (widget.departments.isEmpty) {
      return const _EmptyState(message: 'No departments match the search.');
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
        itemCount: widget.departments.length,
        itemBuilder: (context, index) {
          final department = widget.departments[index];
          return _DepartmentListItem(
            department: department,
            canManage: widget.canManage,
            onEdit: () => widget.onEditDepartment(department),
            onToggleLead: widget.onToggleLead,
          );
        },
      ),
    );
  }
}

class _DepartmentListItem extends StatefulWidget {
  const _DepartmentListItem({
    required this.department,
    required this.canManage,
    required this.onEdit,
    required this.onToggleLead,
  });

  final Department department;
  final bool canManage;
  final VoidCallback onEdit;
  final Future<void> Function({
    required Department department,
    required DepartmentUser user,
  })
  onToggleLead;

  @override
  State<_DepartmentListItem> createState() => _DepartmentListItemState();
}

class _DepartmentListItemState extends State<_DepartmentListItem> {
  String? _togglingUserId;
  bool _isExpanded = false;

  int get _leadCount =>
      widget.department.users.where((user) => user.isDepartmentLead).length;

  Future<void> _handleToggleLead(DepartmentUser user) async {
    setState(() => _togglingUserId = user.id);
    try {
      await widget.onToggleLead(department: widget.department, user: user);
    } finally {
      if (mounted) setState(() => _togglingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final department = widget.department;
    final userCount = department.users.length;
    final leadCount = _leadCount;
    final summaryColor = department.isActive ? Colors.black54 : Colors.black38;

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.primary),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 18,
                          color: department.isActive
                              ? Colors.black
                              : Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            department.name,
                            style: TextStyle(
                              color: department.isActive
                                  ? Colors.black
                                  : Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(isActive: department.isActive),
                  if (widget.canManage) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit department',
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                userCount == 0
                    ? 'No users linked'
                    : '$userCount ${userCount == 1 ? 'user' : 'users'} · $leadCount ${leadCount == 1 ? 'lead' : 'leads'}',
                style: TextStyle(
                  color: summaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (userCount > 0) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                    ),
                    child: Text(_isExpanded ? 'Hide details' : 'View details'),
                  ),
                ),
              ],
              if (_isExpanded && userCount > 0) ...[
                const SizedBox(height: 4),
                ...department.users.map(
                  (user) => _DepartmentUserRow(
                    user: user,
                    isDepartmentActive: department.isActive,
                    canManage: widget.canManage,
                    isToggling: _togglingUserId == user.id,
                    onToggleLead: () => _handleToggleLead(user),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (department.isActive) return content;
    return Opacity(opacity: 0.62, child: content);
  }
}

class _DepartmentUserRow extends StatelessWidget {
  const _DepartmentUserRow({
    required this.user,
    required this.isDepartmentActive,
    required this.canManage,
    required this.isToggling,
    required this.onToggleLead,
  });

  final DepartmentUser user;
  final bool isDepartmentActive;
  final bool canManage;
  final bool isToggling;
  final VoidCallback onToggleLead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = isDepartmentActive ? Colors.black : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  _SmallInfo(
                    icon: Icons.person_outline,
                    text: user.personName,
                    color: textColor,
                  ),
                  _SmallInfo(
                    icon: Icons.badge_outlined,
                    text: user.id,
                    color: textColor,
                  ),
                  if (user.isDepartmentLead)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          'Lead',
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (canManage) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: isToggling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : TextButton(
                          onPressed: onToggleLead,
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            user.isDepartmentLead
                                ? 'Unmark as lead'
                                : 'Mark as lead',
                          ),
                        ),
                ),
              ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive ? const Color(0xFF2E7D32) : Colors.black38,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          isActive ? 'Active' : 'Inactive',
          style: TextStyle(
            color: isActive ? const Color(0xFF2E7D32) : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color)),
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
                    'Failed to load Departments',
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

class _DepartmentsData {
  const _DepartmentsData({
    required this.departments,
    required this.users,
    required this.hasWebAccess,
  });

  factory _DepartmentsData.empty() {
    return const _DepartmentsData(
      departments: [],
      users: [],
      hasWebAccess: false,
    );
  }

  final List<Department> departments;
  final List<UserAccount> users;
  final bool hasWebAccess;
}

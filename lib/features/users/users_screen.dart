import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_sort_controls.dart';
import 'user_form_screen.dart';
import 'user_models.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  late Future<_UsersData> _dataFuture;
  String _searchQuery = '';
  AppSortField _sortField = AppSortField.id;
  AppSortDirection _sortDirection = AppSortDirection.descending;

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

  Future<_UsersData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getUsers(),
      widget.apiClient.getUserRoles(),
      widget.apiClient.getBaseLocations(),
    ]);

    return _UsersData(
      users: results[0] as List<UserAccount>,
      roles: results[1] as List<UserRoleOption>,
      baseLocations: results[2] as List<BaseLocation>,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _addUser(_UsersData data) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(
          apiClient: widget.apiClient,
          availableRoles: data.roles,
          baseLocations: data.baseLocations,
        ),
      ),
    );
    if (saved == true) {
      _showSuccessMessage('User added successfully.');
      _refresh();
    }
  }

  Future<void> _editUser(_UsersData data, UserAccount user) async {
    try {
      final latestUser = await widget.apiClient.getUser(userId: user.id);
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UserFormScreen(
            apiClient: widget.apiClient,
            availableRoles: data.roles,
            baseLocations: data.baseLocations,
            user: latestUser,
          ),
        ),
      );
      if (saved == true) {
        _showSuccessMessage('User updated successfully.');
        _refresh();
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Failed to load user: $error',
        type: AppSnackBarType.error,
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    showAppSnackBar(context, message: message, type: AppSnackBarType.success);
  }

  Future<void> _downloadUsers(List<UserAccount> users) async {
    try {
      final fileName =
          'mpc-pharma-users-${DateTime.now().millisecondsSinceEpoch}.csv';
      await downloadFile(
        fileName: fileName,
        bytes: utf8.encode(_usersToCsv(users)),
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

  String _usersToCsv(List<UserAccount> users) {
    final rows = <List<String>>[
      [
        'ID',
        'Name',
        'Mobile',
        'Base Location ID',
        'Base Location',
        'Vehicle Number',
        'Active',
        'Roles',
        'Created At',
      ],
      ...users.map(
        (user) => [
          user.id,
          user.personName,
          user.mobile,
          user.baseLocationId,
          user.baseLocationName,
          user.vehicleNbr,
          user.isActive ? 'Active' : 'Inactive',
          user.roles.map((role) => role.tokenValue).join('; '),
          user.createdAt?.toLocal().toString() ?? '',
        ],
      ),
    ];

    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  int _compareUsers(UserAccount first, UserAccount second) {
    final result = switch (_sortField) {
      AppSortField.name => first.personName.toLowerCase().compareTo(
        second.personName.toLowerCase(),
      ),
      AppSortField.id => _numericId(first.id).compareTo(_numericId(second.id)),
    };
    return _sortDirection == AppSortDirection.ascending ? result : -result;
  }

  int _numericId(String id) => int.tryParse(id) ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: SafeArea(
        child: FutureBuilder<_UsersData>(
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

            final data = snapshot.data ?? _UsersData.empty();
            final filteredUsers = data.users
                .where((user) => user.matchesSearch(_searchQuery))
                .toList();
            filteredUsers.sort(_compareUsers);

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
                        shownCount: filteredUsers.length,
                        totalCount: data.users.length,
                        sortField: _sortField,
                        sortDirection: _sortDirection,
                        onSortChanged: _changeSort,
                        onAddUser: () => _addUser(data),
                        onDownloadUsers: () => _downloadUsers(data.users),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _UsersSection(
                          users: filteredUsers,
                          sortField: _sortField,
                          sortDirection: _sortDirection,
                          onEditUser: (user) => _editUser(data, user),
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
    required this.onSortChanged,
    required this.onAddUser,
    required this.onDownloadUsers,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final ValueChanged<AppSortField> onSortChanged;
  final VoidCallback onAddUser;
  final VoidCallback onDownloadUsers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final search = TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Search users',
            prefixIcon: Icon(Icons.search),
            hintText: 'Name, mobile, location, vehicle, role...',
          ),
        );
        final addUser = ElevatedButton.icon(
          onPressed: onAddUser,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Add New User'),
        );
        final download = OutlinedButton.icon(
          onPressed: onDownloadUsers,
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
              _UsersCountText(shownCount: shownCount, totalCount: totalCount),
              const SizedBox(height: 8),
              search,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: download),
                  const SizedBox(width: 12),
                  Expanded(child: addUser),
                ],
              ),
              const SizedBox(height: 8),
              AppSortControls(
                field: sortField,
                direction: sortDirection,
                onChanged: onSortChanged,
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UsersCountText(shownCount: shownCount, totalCount: totalCount),
            const SizedBox(height: 8),
            search,
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [download, addUser],
              ),
            ),
            const SizedBox(height: 8),
            AppSortControls(
              field: sortField,
              direction: sortDirection,
              onChanged: onSortChanged,
            ),
          ],
        );
      },
    );
  }
}

class _UsersCountText extends StatelessWidget {
  const _UsersCountText({required this.shownCount, required this.totalCount});

  final int shownCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$shownCount of $totalCount users',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _UsersSection extends StatefulWidget {
  const _UsersSection({
    required this.users,
    required this.sortField,
    required this.sortDirection,
    required this.onEditUser,
  });

  final List<UserAccount> users;
  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final ValueChanged<UserAccount> onEditUser;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_UsersSection oldWidget) {
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
    if (widget.users.isEmpty) {
      return const _EmptyState(message: 'No users match the search.');
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
        itemCount: widget.users.length,
        itemBuilder: (context, index) {
          final user = widget.users[index];
          return _UserListItem(
            user: user,
            onEdit: () => widget.onEditUser(user),
          );
        },
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  const _UserListItem({required this.user, required this.onEdit});

  final UserAccount user;
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.personName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _StatusPill(isActive: user.isActive),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit user',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _SmallInfo(icon: Icons.badge_outlined, text: user.id),
                  _SmallInfo(icon: Icons.phone_outlined, text: user.mobile),
                  _SmallInfo(
                    icon: Icons.location_on_outlined,
                    text: user.baseLocationName,
                  ),
                  if (user.vehicleNbr.isNotEmpty)
                    _SmallInfo(
                      icon: Icons.local_shipping_outlined,
                      text: user.vehicleNbr,
                    ),
                ],
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
                    'Failed to load Users',
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

class _UsersData {
  const _UsersData({
    required this.users,
    required this.roles,
    required this.baseLocations,
  });

  factory _UsersData.empty() {
    return const _UsersData(users: [], roles: [], baseLocations: []);
  }

  final List<UserAccount> users;
  final List<UserRoleOption> roles;
  final List<BaseLocation> baseLocations;
}

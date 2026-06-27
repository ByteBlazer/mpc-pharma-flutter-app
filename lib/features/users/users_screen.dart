import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import 'user_form_screen.dart';
import 'user_models.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.apiClient});

  final ApiClient apiClient;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchController = TextEditingController();
  late Future<_UsersData> _dataFuture;
  String _searchQuery = '';

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
    if (saved == true) _refresh();
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
      if (saved == true) _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load user: $error')));
    }
  }

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
              );
            }

            final data = snapshot.data ?? _UsersData.empty();
            final filteredUsers = data.users
                .where((user) => user.matchesSearch(_searchQuery))
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
                        shownCount: filteredUsers.length,
                        totalCount: data.users.length,
                        onAddUser: () => _addUser(data),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _UsersSection(
                          users: filteredUsers,
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
    required this.onAddUser,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final VoidCallback onAddUser;

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
          label: const Text('Add User'),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _UsersCountText(shownCount: shownCount, totalCount: totalCount),
              const SizedBox(height: 8),
              search,
              const SizedBox(height: 12),
              addUser,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UsersCountText(shownCount: shownCount, totalCount: totalCount),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                addUser,
              ],
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
  const _UsersSection({required this.users, required this.onEditUser});

  final List<UserAccount> users;
  final ValueChanged<UserAccount> onEditUser;

  @override
  State<_UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<_UsersSection> {
  final _scrollController = ScrollController();

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

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'web_portal_providers.dart';

enum _UserSortField { id, personName, baseLocationName }

class WebPortalUsersScreen extends ConsumerStatefulWidget {
  const WebPortalUsersScreen({super.key});

  @override
  ConsumerState<WebPortalUsersScreen> createState() =>
      _WebPortalUsersScreenState();
}

class _WebPortalUsersScreenState extends ConsumerState<WebPortalUsersScreen> {
  final _searchController = TextEditingController();
  _UserSortField _sortField = _UserSortField.id;
  bool _sortAsc = false;
  bool _showRoles = false;
  bool _hideInactive = true;
  WebPortalUser? _editingUser;
  bool _isAdding = false;
  bool _saving = false;

  final _personName = TextEditingController();
  final _mobile = TextEditingController();
  final _vehicleNbr = TextEditingController();
  String? _baseLocationId;
  final Set<String> _selectedRoles = {};
  bool _isActive = true;

  @override
  void dispose() {
    _searchController.dispose();
    _personName.dispose();
    _mobile.dispose();
    _vehicleNbr.dispose();
    super.dispose();
  }

  void _openAdd() {
    setState(() {
      _isAdding = true;
      _editingUser = null;
      _personName.clear();
      _mobile.clear();
      _vehicleNbr.clear();
      _baseLocationId = null;
      _selectedRoles.clear();
      _isActive = true;
    });
  }

  void _openEdit(WebPortalUser user) {
    setState(() {
      _isAdding = false;
      _editingUser = user;
      _personName.text = user.personName;
      _mobile.text = user.mobile;
      _vehicleNbr.text = user.vehicleNbr;
      _baseLocationId = user.baseLocationId;
      _selectedRoles
        ..clear()
        ..addAll(user.roles.map((r) => r.roleName));
      _isActive = user.isActive;
    });
  }

  bool _validateForm() {
    final nameOk =
        _personName.text.trim().isNotEmpty && _personName.text.trim().length <= 25;
    final mobileOk = RegExp(r'^\d{10}$').hasMatch(_mobile.text.trim());
    final locOk = _baseLocationId != null && _baseLocationId!.isNotEmpty;
    final rolesOk = _selectedRoles.isNotEmpty;
    final vehicleOk = _vehicleNbr.text.length <= 15;
    return nameOk && mobileOk && locOk && rolesOk && vehicleOk;
  }

  Future<void> _save() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix form errors')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = WebPortalUserFormData(
        mobile: _mobile.text.trim(),
        personName: _personName.text.trim(),
        baseLocationId: _baseLocationId!,
        vehicleNbr: _vehicleNbr.text,
        roles: _selectedRoles.toList(),
        isActive: _isActive,
      );
      if (_editingUser != null) {
        await api.updatePortalUser(_editingUser!.id, data);
      } else {
        await api.createPortalUser(data);
      }
      ref.invalidate(portalUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isAdding ? 'User created successfully!' : 'User updated successfully!',
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
  }

  List<WebPortalUser> _filterAndSort(List<WebPortalUser> users) {
    final q = _searchController.text.trim().toLowerCase();
    var list = users.where((u) {
      if (_hideInactive && !u.isActive) return false;
      if (q.isEmpty) return true;
      final fields = [
        u.id,
        u.personName,
        u.baseLocationName,
        u.mobile,
        u.vehicleNbr,
        ...u.roles.map((r) => r.roleName),
      ];
      return fields.any((f) => f.toLowerCase().contains(q));
    }).toList();

    list.sort((a, b) {
      String av;
      String bv;
      switch (_sortField) {
        case _UserSortField.personName:
          av = a.personName;
          bv = b.personName;
        case _UserSortField.baseLocationName:
          av = a.baseLocationName;
          bv = b.baseLocationName;
        case _UserSortField.id:
          av = a.id;
          bv = b.id;
      }
      final cmp = av.compareTo(bv);
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(portalUsersProvider);
    final rolesAsync = ref.watch(portalUserRolesListProvider);
    final locationsAsync = ref.watch(portalBaseLocationsProvider);

    return usersAsync.when(
      loading: () => const LoadingOverlay(message: 'Loading users...'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(portalUsersProvider),
      ),
      data: (users) => rolesAsync.when(
        loading: () => const LoadingOverlay(message: 'Loading roles...'),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (allRoles) => locationsAsync.when(
          loading: () => const LoadingOverlay(message: 'Loading locations...'),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (locations) {
            final filtered = _filterAndSort(users);
            return Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Text(
                            'Users',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () => _showUserDialog(
                              context,
                              allRoles,
                              locations,
                            ),
                            child: const Text('Add User'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search users by ID, name, location, mobile...',
                                border: const OutlineInputBorder(),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilterChip(
                            label: Text(_showRoles ? 'Hide Roles' : 'Show Roles'),
                            selected: _showRoles,
                            onSelected: (v) => setState(() => _showRoles = v),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              Colors.grey.shade100,
                            ),
                            columns: [
                              _sortableColumn('ID', _UserSortField.id),
                              _sortableColumn(
                                'Person Name',
                                _UserSortField.personName,
                              ),
                              _sortableColumn(
                                'Base Location',
                                _UserSortField.baseLocationName,
                              ),
                              const DataColumn(label: Text('Mobile')),
                              const DataColumn(label: Text('Vehicle')),
                              const DataColumn(label: Text('Created At')),
                              const DataColumn(label: Text('Active')),
                              if (_showRoles)
                                ...allRoles.map(
                                  (r) => DataColumn(label: Text(r.roleName)),
                                ),
                              const DataColumn(label: Text('')),
                            ],
                            rows: filtered.map((user) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(user.id)),
                                  DataCell(Text(user.personName)),
                                  DataCell(Text(user.baseLocationName)),
                                  DataCell(Text(user.mobile)),
                                  DataCell(Text(user.vehicleNbr)),
                                  DataCell(
                                    Text(user.createdAt.toLocal().toString()),
                                  ),
                                  DataCell(Text(user.isActive ? 'Yes' : 'No')),
                                  if (_showRoles)
                                    ...allRoles.map((role) {
                                      final has = user.roles.any(
                                        (r) => r.roleName == role.roleName,
                                      );
                                      return DataCell(
                                        Icon(
                                          has ? Icons.check_circle : Icons.cancel,
                                          color: has ? Colors.green : Colors.red,
                                          size: 20,
                                        ),
                                      );
                                    }),
                                  DataCell(
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => _showUserDialog(
                                        context,
                                        allRoles,
                                        locations,
                                        user: user,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    CheckboxListTile(
                      value: _hideInactive,
                      onChanged: (v) =>
                          setState(() => _hideInactive = v ?? true),
                      title: const Text('Hide Inactive Users'),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
                if (_saving)
                  const ModalBarrier(
                    dismissible: false,
                    color: Colors.black26,
                  ),
                if (_saving) const LoadingOverlay(message: 'Saving...'),
              ],
            );
          },
        ),
      ),
    );
  }

  DataColumn _sortableColumn(String label, _UserSortField field) {
    final active = _sortField == field;
    return DataColumn(
      label: InkWell(
        onTap: () => setState(() {
          if (active) {
            _sortAsc = !_sortAsc;
          } else {
            _sortField = field;
            _sortAsc = true;
          }
        }),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (active)
              Icon(_sortAsc ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showUserDialog(
    BuildContext context,
    List<WebPortalUserRole> allRoles,
    List<WebPortalBaseLocation> locations, {
    WebPortalUser? user,
  }) {
    if (user != null) {
      _openEdit(user);
    } else {
      _openAdd();
    }
    return showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(_isAdding ? 'Add User' : 'Edit User'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _personName,
                      decoration: const InputDecoration(labelText: 'Person Name *'),
                      maxLength: 25,
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    TextField(
                      controller: _mobile,
                      decoration: const InputDecoration(labelText: 'Mobile *'),
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    DropdownButtonFormField<String>(
                      value: _baseLocationId,
                      decoration:
                          const InputDecoration(labelText: 'Base Location *'),
                      items: locations
                          .map(
                            (l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => _baseLocationId = v),
                    ),
                    TextField(
                      controller: _vehicleNbr,
                      decoration:
                          const InputDecoration(labelText: 'Vehicle Number'),
                      maxLength: 15,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Roles *',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    ...allRoles.map(
                      (role) => CheckboxListTile(
                        dense: true,
                        title: Text(role.roleName),
                        value: _selectedRoles.contains(role.roleName),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) {
                              _selectedRoles.add(role.roleName);
                            } else {
                              _selectedRoles.remove(role.roleName);
                            }
                          });
                        },
                      ),
                    ),
                    if (_editingUser != null)
                      DropdownButtonFormField<bool>(
                        value: _isActive,
                        decoration: const InputDecoration(labelText: 'Active'),
                        items: const [
                          DropdownMenuItem(value: true, child: Text('Yes')),
                          DropdownMenuItem(value: false, child: Text('No')),
                        ],
                        onChanged: (v) =>
                            setDialogState(() => _isActive = v ?? true),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        await _save();
                        if (ctx.mounted && !_saving) Navigator.pop(ctx);
                      },
                child: Text(_isAdding ? 'Create User' : 'Update User'),
              ),
            ],
          );
        },
      ),
    );
  }
}

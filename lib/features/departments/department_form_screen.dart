import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../users/user_models.dart';
import 'department_models.dart';

class DepartmentFormScreen extends StatefulWidget {
  const DepartmentFormScreen({
    super.key,
    required this.apiClient,
    required this.availableUsers,
    this.department,
  });

  final ApiClient apiClient;
  final List<UserAccount> availableUsers;
  final Department? department;

  @override
  State<DepartmentFormScreen> createState() => _DepartmentFormScreenState();
}

class _DepartmentFormScreenState extends State<DepartmentFormScreen> {
  late final TextEditingController _nameController;
  late bool _isActive;
  late Set<String> _selectedUserIds;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.department != null;

  @override
  void initState() {
    super.initState();
    final department = widget.department;
    _nameController = TextEditingController(text: department?.name ?? '');
    _isActive = department?.isActive ?? true;
    _selectedUserIds = {
      if (department != null) ...department.users.map((user) => user.id),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _save() async {
    final validationMessage = _validateForm();
    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final request = DepartmentSaveRequest(
      name: _nameController.text.trim(),
      userIds: _selectedUserIds.toList(),
      isActive: _isActive,
    );

    try {
      final department = widget.department;
      if (department == null) {
        await widget.apiClient.createDepartment(request: request);
      } else {
        await widget.apiClient.updateDepartment(
          id: department.id,
          request: request,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isSaving = false;
      });
    }
  }

  String? _validateForm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return 'Enter department name.';
    }
    if (name.length > 100) {
      return 'Department name must be 100 characters or fewer.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Department' : 'Add Department'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        maxLength: 100,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => _clearErrorMessage(),
                        onSubmitted: (_) {
                          if (!_isSaving) _save();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Department name',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _UsersMultiSelectField(
                        availableUsers: widget.availableUsers,
                        selectedUserIds: _selectedUserIds,
                        enabled: !_isSaving,
                        onChanged: (userIds) {
                          setState(() {
                            _selectedUserIds = userIds;
                            _errorMessage = null;
                          });
                        },
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          title: const Text(
                            'Active',
                            style: TextStyle(color: Colors.black),
                          ),
                          onChanged: _isSaving
                              ? null
                              : (value) => setState(() => _isActive = value),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: Text(
                                  _isEditing
                                      ? 'Save Department'
                                      : 'Add Department',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UsersMultiSelectField extends StatelessWidget {
  const _UsersMultiSelectField({
    required this.availableUsers,
    required this.selectedUserIds,
    required this.enabled,
    required this.onChanged,
  });

  final List<UserAccount> availableUsers;
  final Set<String> selectedUserIds;
  final bool enabled;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedUserIds.isEmpty
        ? 'Select users'
        : '${selectedUserIds.length} ${selectedUserIds.length == 1 ? 'user' : 'users'} selected';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? () => _openUserPicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Users',
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedUserIds.isEmpty ? Colors.black54 : Colors.black,
          ),
        ),
      ),
    );
  }

  Future<void> _openUserPicker(BuildContext context) async {
    final nextSelection = await showDialog<Set<String>>(
      context: context,
      builder: (context) => _UserPickerDialog(
        availableUsers: availableUsers,
        initialSelection: selectedUserIds,
      ),
    );

    if (nextSelection != null) onChanged(nextSelection);
  }
}

class _UserPickerDialog extends StatefulWidget {
  const _UserPickerDialog({
    required this.availableUsers,
    required this.initialSelection,
  });

  final List<UserAccount> availableUsers;
  final Set<String> initialSelection;

  @override
  State<_UserPickerDialog> createState() => _UserPickerDialogState();
}

class _UserPickerDialogState extends State<_UserPickerDialog> {
  late Set<String> _selection;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
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

  List<UserAccount> get _filteredUsers {
    return widget.availableUsers
        .where((user) => user.matchesSearch(_searchQuery))
        .toList();
  }

  String _userLabel(UserAccount user) {
    if (user.isActive) return user.personName;
    return '${user.personName} (Inactive)';
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;
    final isFiltering = _searchQuery.trim().isNotEmpty;

    return AlertDialog(
      title: Text('Select users (${_selection.length} selected)'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: widget.availableUsers.isEmpty
            ? const Center(
                child: Text(
                  'No users available.',
                  style: TextStyle(color: Colors.black),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search users',
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Name, mobile, location...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFiltering
                        ? '${filteredUsers.length} of ${widget.availableUsers.length} users shown'
                        : '${widget.availableUsers.length} users',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filteredUsers.isEmpty
                        ? const Center(
                            child: Text(
                              'No users match the search.',
                              style: TextStyle(color: Colors.black),
                            ),
                          )
                        : Scrollbar(
                            thumbVisibility: true,
                            child: ListView.builder(
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _selection.contains(user.id),
                                  title: Text(
                                    _userLabel(user),
                                    style: TextStyle(
                                      color: user.isActive
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user.mobile,
                                    style: TextStyle(
                                      color: user.isActive
                                          ? Colors.black
                                          : Colors.black54,
                                    ),
                                  ),
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selection.add(user.id);
                                      } else {
                                        _selection.remove(user.id);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

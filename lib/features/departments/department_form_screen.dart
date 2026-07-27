import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_multi_select_field.dart';
import '../../widgets/app_screen_scaffold.dart';
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

  List<UserAccount> get _pickableUsers {
    if (!_isEditing) {
      return widget.availableUsers.where((user) => user.isActive).toList();
    }

    final taggedUserIds = widget.department!.users
        .map((user) => user.id)
        .toSet();
    return widget.availableUsers.where((user) {
      return user.isActive || taggedUserIds.contains(user.id);
    }).toList();
  }

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

  List<AppMultiSelectItem<String>> get _userSelectItems {
    return _pickableUsers
        .map(
          (user) => AppMultiSelectItem<String>(
            value: user.id,
            label: user.isActive
                ? user.personName
                : '${user.personName} (Inactive)',
            subtitle: user.mobile,
            searchText: [
              user.id,
              user.mobile,
              user.personName,
              user.baseLocationId,
              user.baseLocationName,
              user.vehicleNbr,
              user.isActive ? 'active' : 'inactive',
              ...user.roles.map((role) => role.tokenValue),
              ...user.roles.map((role) => role.label),
            ].join(' '),
            dimmed: !user.isActive,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Dept' : 'Add Dept')),
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
                      AppMultiSelectField<String>(
                        fieldLabel: 'Users',
                        dialogTitle: 'Select users',
                        countLabel: 'users',
                        items: _userSelectItems,
                        selectedValues: _selectedUserIds,
                        enabled: !_isSaving,
                        emptySelectionText: 'Select users',
                        searchLabel: 'Search users',
                        searchHint: 'Name, mobile, location...',
                        countSummary: const AppMultiSelectCountSummary(
                          singular: 'user',
                          plural: 'users',
                        ),
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
                                  _isEditing ? 'Save Dept' : 'Add Dept',
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

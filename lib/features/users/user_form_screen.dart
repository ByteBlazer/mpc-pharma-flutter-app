import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api/api_client.dart';
import '../../auth/app_role.dart';
import 'user_models.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({
    super.key,
    required this.apiClient,
    required this.availableRoles,
    required this.baseLocations,
    this.user,
  });

  final ApiClient apiClient;
  final List<UserRoleOption> availableRoles;
  final List<BaseLocation> baseLocations;
  final UserAccount? user;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _mobileController;
  late final TextEditingController _vehicleController;
  late bool _isActive;
  late String? _baseLocationId;
  late Set<AppRole> _selectedRoles;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.user != null;

  void _clearErrorMessage() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _nameController = TextEditingController(text: user?.personName ?? '');
    _mobileController = TextEditingController(text: user?.mobile ?? '');
    _vehicleController = TextEditingController(text: user?.vehicleNbr ?? '');
    _isActive = user?.isActive ?? true;
    _baseLocationId = user?.baseLocationId.isNotEmpty == true
        ? user!.baseLocationId
        : widget.baseLocations.isEmpty
        ? null
        : widget.baseLocations.first.id;
    _selectedRoles = {...?user?.roles};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _vehicleController.dispose();
    super.dispose();
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

    final baseLocationId = _baseLocationId!;
    final request = UserAccountSaveRequest(
      mobile: _mobileController.text.trim(),
      personName: _nameController.text.trim(),
      baseLocationId: baseLocationId,
      vehicleNbr: _vehicleController.text.trim(),
      isActive: _isActive,
      roles: _selectedRoles.toList(),
    );

    try {
      final user = widget.user;
      if (user == null) {
        await widget.apiClient.createUser(request: request);
      } else {
        await widget.apiClient.updateUser(userId: user.id, request: request);
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
    if (_nameController.text.trim().isEmpty) {
      return 'Enter person name.';
    }

    final mobile = _mobileController.text.trim();
    if (mobile.length != 10) {
      return 'Enter a valid 10 digit mobile number.';
    }

    final baseLocationId = _baseLocationId;
    if (baseLocationId == null || baseLocationId.isEmpty) {
      return 'Select base location.';
    }

    if (_selectedRoles.isEmpty) {
      return 'Select at least one role.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit User' : 'Add User')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearErrorMessage(),
                          decoration: const InputDecoration(
                            labelText: 'Person name',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mobileController,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) => _clearErrorMessage(),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Mobile number',
                            prefixText: '+91 ',
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _baseLocationId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Base location',
                          ),
                          items: widget.baseLocations
                              .map(
                                (location) => DropdownMenuItem(
                                  value: location.id,
                                  child: Text(location.name),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _baseLocationId = value;
                                    _errorMessage = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _vehicleController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearErrorMessage(),
                          decoration: const InputDecoration(
                            labelText: 'Vehicle number',
                          ),
                        ),
                        const SizedBox(height: 16),
                        _RolesMultiSelectField(
                          availableRoles: widget.availableRoles,
                          selectedRoles: _selectedRoles,
                          enabled: !_isSaving,
                          onChanged: (roles) {
                            setState(() {
                              _selectedRoles = roles;
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
                                    _isEditing ? 'Save User' : 'Add User',
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
      ),
    );
  }
}

class _RolesMultiSelectField extends StatelessWidget {
  const _RolesMultiSelectField({
    required this.availableRoles,
    required this.selectedRoles,
    required this.enabled,
    required this.onChanged,
  });

  final List<UserRoleOption> availableRoles;
  final Set<AppRole> selectedRoles;
  final bool enabled;
  final ValueChanged<Set<AppRole>> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = selectedRoles.isEmpty
        ? 'Select roles'
        : selectedRoles.map((role) => role.label).join(', ');

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? () => _openRolePicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Roles',
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          selectedLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedRoles.isEmpty ? Colors.black54 : Colors.black,
          ),
        ),
      ),
    );
  }

  Future<void> _openRolePicker(BuildContext context) async {
    final nextSelection = await showDialog<Set<AppRole>>(
      context: context,
      builder: (context) {
        var dialogSelection = {...selectedRoles};
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select roles'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: availableRoles.map((option) {
                      final role = option.role;
                      if (role == null) return const SizedBox.shrink();
                      return CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: dialogSelection.contains(role),
                        title: Text(
                          role.label,
                          style: const TextStyle(color: Colors.black),
                        ),
                        subtitle: option.description.isEmpty
                            ? null
                            : Text(
                                option.description,
                                style: const TextStyle(color: Colors.black),
                              ),
                        onChanged: (selected) {
                          setDialogState(() {
                            if (selected == true) {
                              dialogSelection.add(role);
                            } else {
                              dialogSelection.remove(role);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(dialogSelection),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nextSelection != null) onChanged(nextSelection);
  }
}

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../departments/department_models.dart';
import 'ticket_models.dart';

class ComplaintCategoryFormScreen extends StatefulWidget {
  const ComplaintCategoryFormScreen({
    super.key,
    required this.apiClient,
    required this.departments,
    this.category,
  });

  final ApiClient apiClient;
  final List<Department> departments;
  final ComplaintCategory? category;

  @override
  State<ComplaintCategoryFormScreen> createState() =>
      _ComplaintCategoryFormScreenState();
}

class _ComplaintCategoryFormScreenState
    extends State<ComplaintCategoryFormScreen> {
  late final TextEditingController _nameController;
  late bool _isActive;
  late int _slaDays;
  String? _selectedDepartmentId;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.category != null;

  List<Department> get _departmentOptions {
    final active = widget.departments.where((dept) => dept.isActive).toList();
    if (!_isEditing) return active;

    final currentId = widget.category!.assignedDepartmentId;
    if (currentId.isEmpty ||
        active.any((dept) => dept.id == currentId)) {
      return active;
    }

    final current = widget.departments
        .where((dept) => dept.id == currentId)
        .toList();
    return [...current, ...active];
  }

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _slaDays = category?.slaDays ?? 1;
    _isActive = category?.isActive ?? true;
    _selectedDepartmentId = category?.assignedDepartmentId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  String? _validateForm() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Category name is required.';
    if (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty) {
      return 'Select a department.';
    }
    if (!ComplaintCategory.slaDayOptions.contains(_slaDays)) {
      return 'Select SLA days.';
    }
    return null;
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

    try {
      final name = _nameController.text.trim();
      final departmentId = _selectedDepartmentId!;
      final slaHours = ComplaintCategory.slaHoursFromDays(_slaDays);
      if (_isEditing) {
        await widget.apiClient.updateComplaintCategory(
          categoryId: widget.category!.id,
          name: name,
          assignedDepartmentId: departmentId,
          slaHours: slaHours,
          isActive: _isActive,
        );
      } else {
        await widget.apiClient.createComplaintCategory(
          name: name,
          assignedDepartmentId: departmentId,
          slaHours: slaHours,
          isActive: _isActive,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit category' : 'Add category'),
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
                        enabled: !_isSaving,
                        onChanged: (_) => _clearErrorMessage(),
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _departmentOptions.any(
                          (dept) => dept.id == _selectedDepartmentId,
                        )
                            ? _selectedDepartmentId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Default department',
                        ),
                        items: _departmentOptions
                            .map(
                              (dept) => DropdownMenuItem(
                                value: dept.id,
                                child: Text(
                                  dept.isActive
                                      ? dept.name
                                      : '${dept.name} (inactive)',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedDepartmentId = value;
                                  _errorMessage = null;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'New complaints in this category are routed to this department by default.',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _slaDays,
                        decoration: const InputDecoration(
                          labelText: 'SLA Days',
                        ),
                        items: [
                          for (final days in ComplaintCategory.slaDayOptions)
                            DropdownMenuItem(
                              value: days,
                              child: Text(
                                days == 1 ? '1 day' : '$days days',
                              ),
                            ),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _slaDays = value;
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
                          subtitle: const Text(
                            'Inactive categories are hidden from complaint forms.',
                            style: TextStyle(color: Colors.black54),
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
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _save,
                              child: Text(
                                _isEditing ? 'Save category' : 'Add category',
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

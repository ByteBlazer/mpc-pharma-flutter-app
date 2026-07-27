import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_screen_scaffold.dart';
import 'ticket_models.dart';

class InternalCategoryFormScreen extends StatefulWidget {
  const InternalCategoryFormScreen({
    super.key,
    required this.apiClient,
    this.category,
  });

  final ApiClient apiClient;
  final InternalCategory? category;

  @override
  State<InternalCategoryFormScreen> createState() =>
      _InternalCategoryFormScreenState();
}

class _InternalCategoryFormScreenState
    extends State<InternalCategoryFormScreen> {
  late final TextEditingController _nameController;
  late bool _isActive;
  late int _slaDays;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _slaDays = category?.slaDays ?? 1;
    _isActive = category?.isActive ?? true;
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
    if (!InternalCategory.slaDayOptions.contains(_slaDays)) {
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
      final slaHours = InternalCategory.slaHoursFromDays(_slaDays);
      if (_isEditing) {
        await widget.apiClient.updateInternalCategory(
          categoryId: widget.category!.id,
          name: name,
          slaHours: slaHours,
          isActive: _isActive,
        );
      } else {
        await widget.apiClient.createInternalCategory(
          name: name,
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
                        DropdownButtonFormField<int>(
                          initialValue: _slaDays,
                          decoration: const InputDecoration(
                            labelText: 'SLA Days',
                          ),
                          items: [
                            for (final days in InternalCategory.slaDayOptions)
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
                              'Inactive categories are hidden from internal ticket forms.',
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_multi_select_field.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../customers/customer_models.dart';
import '../departments/department_models.dart';
import 'ticket_attachment_manager.dart';
import 'ticket_models.dart';
import 'widgets/ticket_description_field.dart';

class CreateEmployeeTicketScreen extends StatefulWidget {
  const CreateEmployeeTicketScreen({
    super.key,
    required this.apiClient,
    required this.ticketType,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final TicketType ticketType;
  final Future<void> Function() onLoginAgain;

  @override
  State<CreateEmployeeTicketScreen> createState() =>
      _CreateEmployeeTicketScreenState();
}

class _CreateEmployeeTicketScreenState extends State<CreateEmployeeTicketScreen> {
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  late final TicketAttachmentManager _attachmentManager;
  late Future<_CreateTicketData> _dataFuture;

  String? _selectedCustomerId;
  String? _selectedCategoryId;
  String? _selectedDepartmentId;
  String? _selectedAssigneeId;
  TicketPriority _priority = TicketPriority.medium;
  bool _isSubmitting = false;
  bool _allowExitWithoutPrompt = false;

  bool get _isCustomerTicket => widget.ticketType == TicketType.raisedForCustomer;

  bool get _hasUnsavedChanges {
    if (_allowExitWithoutPrompt) return false;
    if (_subjectController.text.trim().isNotEmpty) return true;
    if (_descriptionController.text.trim().isNotEmpty) return true;
    if (_attachmentManager.attachments.isNotEmpty) return true;
    if (_selectedCustomerId != null && _selectedCustomerId!.isNotEmpty) {
      return true;
    }
    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      return true;
    }
    if (_selectedDepartmentId != null && _selectedDepartmentId!.isNotEmpty) {
      return true;
    }
    if (_selectedAssigneeId != null && _selectedAssigneeId!.isNotEmpty) {
      return true;
    }
    if (_priority != TicketPriority.medium) return true;
    return false;
  }

  Future<void> _handlePopRequested() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await confirmDiscardUnsavedChanges(
      context,
      message:
          'This ticket has not been created yet. If you leave now, your draft will be lost.',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _attachmentManager = TicketAttachmentManager(widget.apiClient);
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<_CreateTicketData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getComplaintCategories(),
      widget.apiClient.getDepartments(),
      if (_isCustomerTicket) widget.apiClient.getCustomersLightweight(),
    ]);
    return _CreateTicketData(
      categories: results[0] as List<ComplaintCategory>,
      departments: results[1] as List<Department>,
      customers: _isCustomerTicket
          ? results[2] as List<CustomerSummary>
          : const [],
    );
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Department? _selectedDepartment(_CreateTicketData data) {
    final departmentId = _selectedDepartmentId;
    if (departmentId == null) return null;
    return data.departments
        .where((department) => department.id == departmentId)
        .firstOrNull;
  }

  List<DepartmentUser> _departmentUsers(_CreateTicketData data) {
    return _selectedDepartment(data)?.selectableUsers(
          includeUserId: _selectedAssigneeId,
        ) ??
        const [];
  }

  void _applyCategoryDefaults(_CreateTicketData data, String? categoryId) {
    if (categoryId == null) return;
    final category = data.categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null) return;
    _selectedDepartmentId = category.assignedDepartmentId;
    final department = data.departments
        .where((item) => item.id == category.assignedDepartmentId)
        .firstOrNull;
    _selectedAssigneeId = department?.activeTicketTriager?.id;
  }

  Future<void> _submit(_CreateTicketData data) async {
    final description = _descriptionController.text.trim();
    final departmentId = _selectedDepartmentId;
    final assigneeId = _selectedAssigneeId;
    if (_isCustomerTicket && (_selectedCustomerId == null || _selectedCustomerId!.isEmpty)) {
      _showError('Select a customer.');
      return;
    }
    if (_isCustomerTicket && (_selectedCategoryId == null || _selectedCategoryId!.isEmpty)) {
      _showError('Select a category.');
      return;
    }
    if (departmentId == null || departmentId.isEmpty) {
      _showError('Select a department.');
      return;
    }
    if (assigneeId == null || assigneeId.isEmpty) {
      _showError('Select an assignee.');
      return;
    }
    if (description.isEmpty) {
      _showError('Enter a description.');
      return;
    }
    final subject = _subjectController.text.trim();
    if (!_isCustomerTicket && subject.isEmpty) {
      _showError('Enter a subject.');
      return;
    }

    final body = <String, dynamic>{
      'ticketType': widget.ticketType.apiValue,
      'assignedDepartmentId': departmentId,
      'assigneeAppUserId': assigneeId,
      'description': description,
      'priority': _priority.apiValue,
      'attachmentIds': _attachmentManager.attachmentIds,
    };
    if (subject.isNotEmpty) body['subject'] = subject;
    if (_isCustomerTicket) {
      body['customerId'] = _selectedCustomerId;
      body['ticketComplaintCategoryId'] = _selectedCategoryId;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.createTicket(body: body, isEmployeeView: true);
      if (!mounted) return;
      _allowExitWithoutPrompt = true;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    showAppSnackBar(context, message: message, type: AppSnackBarType.error);
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCustomerTicket ? 'Raise for customer' : 'Internal ticket';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handlePopRequested());
      },
      child: Theme(
        data: AppTheme.withCompactButtons(Theme.of(context)),
        child: AppScreenScaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
        child: FutureBuilder<_CreateTicketData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Failed to load ticket form',
                message: snapshot.error.toString(),
                onRetry: _refreshData,
                onLoginAgain: widget.onLoginAgain,
              );
            }
            final data = snapshot.data ?? const _CreateTicketData.empty();
            final departments = data.departments.where((d) => d.isActive).toList();
            final categories = data.categories.where((c) => c.isActive).toList();
            final users = _departmentUsers(data);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isCustomerTicket)
                        AppMultiSelectField<String>(
                          fieldLabel: 'Customer',
                          dialogTitle: 'Select customer',
                          searchLabel: 'Search customers',
                          searchHint: 'ID, firm name, city...',
                          emptySelectionText: 'Select customer',
                          countLabel: 'customers',
                          singleSelect: true,
                          selectedValues: {
                            ?_selectedCustomerId,
                          },
                          enabled: !_isSubmitting,
                          items: data.customers
                              .map(
                                (customer) => AppMultiSelectItem<String>(
                                  value: customer.id,
                                  label:
                                      '${customer.firmName} (${customer.id})',
                                  searchText:
                                      '${customer.id} ${customer.firmName} ${customer.city}',
                                  subtitle: customer.city.isEmpty
                                      ? null
                                      : customer.city,
                                ),
                              )
                              .toList(),
                          onChanged: (values) => setState(
                            () => _selectedCustomerId =
                                values.isEmpty ? null : values.first,
                          ),
                        ),
                      if (_isCustomerTicket) const SizedBox(height: 16),
                      if (_isCustomerTicket) ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(() {
                                  _selectedCategoryId = value;
                                  _applyCategoryDefaults(data, value);
                                }),
                        ),
                        const SizedBox(height: 16),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: _selectedDepartmentId,
                        decoration: const InputDecoration(labelText: 'Department'),
                        items: departments
                            .map(
                              (department) => DropdownMenuItem(
                                value: department.id,
                                child: Text(department.name),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() {
                                _selectedDepartmentId = value;
                                final department = data.departments
                                    .where((item) => item.id == value)
                                    .firstOrNull;
                                _selectedAssigneeId =
                                    department?.activeTicketTriager?.id;
                              }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                          'assignee-$_selectedDepartmentId-$_selectedAssigneeId',
                        ),
                        initialValue: users.any((user) => user.id == _selectedAssigneeId)
                            ? _selectedAssigneeId
                            : null,
                        decoration: InputDecoration(
                          labelText: _selectedDepartmentId == null
                              ? 'Assignee (Select Dept First)'
                              : 'Assignee',
                        ),
                        items: users
                            .map(
                              (user) => DropdownMenuItem(
                                value: user.id,
                                child: Text(
                                  user.isActive
                                      ? user.personName
                                      : '${user.personName} (Inactive)',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting || _selectedDepartmentId == null
                            ? null
                            : (value) => setState(() => _selectedAssigneeId = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _subjectController,
                        enabled: !_isSubmitting,
                        decoration: InputDecoration(
                          labelText: _isCustomerTicket
                              ? 'Subject (optional)'
                              : 'Subject',
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<TicketPriority>(
                        initialValue: _priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: TicketPriority.values
                            .map(
                              (priority) => DropdownMenuItem(
                                value: priority,
                                child: Text(priority.label),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _priority = value);
                                }
                              },
                      ),
                      const SizedBox(height: 20),
                      TicketDescriptionField(
                        controller: _descriptionController,
                        attachmentManager: _attachmentManager,
                        onAttachmentsChanged: () => setState(() {}),
                        enabled: !_isSubmitting,
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _submit(data),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create ticket'),
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
      ),
    );
  }
}

class _CreateTicketData {
  const _CreateTicketData({
    required this.categories,
    required this.departments,
    required this.customers,
  });

  const _CreateTicketData.empty()
    : categories = const [],
      departments = const [],
      customers = const [];

  final List<ComplaintCategory> categories;
  final List<Department> departments;
  final List<CustomerSummary> customers;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

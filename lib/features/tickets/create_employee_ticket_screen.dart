import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
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
  late final Future<_CreateTicketData> _dataFuture;

  String? _selectedCustomerId;
  String? _selectedCategoryId;
  String? _selectedDepartmentId;
  String? _selectedAssigneeId;
  TicketPriority _priority = TicketPriority.medium;
  bool _isSubmitting = false;

  bool get _isCustomerTicket => widget.ticketType == TicketType.raisedForCustomer;

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

  List<DepartmentUser> _departmentUsers(_CreateTicketData data) {
    final departmentId = _selectedDepartmentId;
    if (departmentId == null) return const [];
    return data.departments
            .where((department) => department.id == departmentId)
            .map((department) => department.users)
            .firstOrNull ??
        const [];
  }

  void _applyCategoryDefaults(_CreateTicketData data, String? categoryId) {
    if (categoryId == null) return;
    final category = data.categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null) return;
    _selectedDepartmentId = category.assignedDepartmentId;
    final triager = data.departments
        .where((department) => department.id == category.assignedDepartmentId)
        .expand((department) => department.users)
        .where((user) => user.isTicketTriager)
        .firstOrNull;
    _selectedAssigneeId = triager?.id;
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

    final body = <String, dynamic>{
      'ticketType': widget.ticketType.apiValue,
      'assignedDepartmentId': departmentId,
      'assigneeAppUserId': assigneeId,
      'description': description,
      'priority': _priority.apiValue,
      'attachmentIds': _attachmentManager.attachmentIds,
    };
    final subject = _subjectController.text.trim();
    if (subject.isNotEmpty) body['subject'] = subject;
    if (_isCustomerTicket) {
      body['customerId'] = _selectedCustomerId;
      body['ticketComplaintCategoryId'] = _selectedCategoryId;
    } else if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      body['ticketComplaintCategoryId'] = _selectedCategoryId;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.createTicket(body: body, isEmployeeView: true);
      if (!mounted) return;
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<_CreateTicketData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text(snapshot.error.toString()));
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
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCustomerId,
                          decoration: const InputDecoration(labelText: 'Customer'),
                          items: data.customers
                              .map(
                                (customer) => DropdownMenuItem(
                                  value: customer.id,
                                  child: Text(
                                    '${customer.firmName} (${customer.id})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isSubmitting
                              ? null
                              : (value) => setState(() => _selectedCustomerId = value),
                        ),
                      if (_isCustomerTicket) const SizedBox(height: 16),
                      if (_isCustomerTicket || categories.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: _isCustomerTicket
                                ? 'Category'
                                : 'Category (optional)',
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
                                _selectedAssigneeId = null;
                                final triager = data.departments
                                    .where((department) => department.id == value)
                                    .expand((department) => department.users)
                                    .where((user) => user.isTicketTriager)
                                    .firstOrNull;
                                _selectedAssigneeId = triager?.id;
                              }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedAssigneeId,
                        decoration: const InputDecoration(labelText: 'Assignee'),
                        items: users
                            .map(
                              (user) => DropdownMenuItem(
                                value: user.id,
                                child: Text(user.personName),
                              ),
                            )
                            .toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _selectedAssigneeId = value),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _subjectController,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'Subject (optional)',
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
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : () => _submit(data),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Create ticket'),
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

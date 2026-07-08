import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
import 'ticket_attachment_manager.dart';
import 'ticket_models.dart';
import 'widgets/ticket_description_field.dart';

class CreateComplaintScreen extends StatefulWidget {
  const CreateComplaintScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<CreateComplaintScreen> createState() => _CreateComplaintScreenState();
}

class _CreateComplaintScreenState extends State<CreateComplaintScreen> {
  final _descriptionController = TextEditingController();
  late final TicketAttachmentManager _attachmentManager;
  late Future<List<ComplaintCategory>> _categoriesFuture;
  String? _selectedCategoryId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _attachmentManager = TicketAttachmentManager(widget.apiClient);
    _categoriesFuture = widget.apiClient.getComplaintCategories();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final categoryId = _selectedCategoryId;
    final description = _descriptionController.text.trim();
    if (categoryId == null || categoryId.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Select a complaint category.',
        type: AppSnackBarType.error,
      );
      return;
    }
    if (description.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Enter a description.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.createTicket(
        body: {
          'ticketComplaintCategoryId': categoryId,
          'description': description,
          'attachmentIds': _attachmentManager.attachmentIds,
        },
        isEmployeeView: false,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New complaint')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FutureBuilder<List<ComplaintCategory>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.black),
                        );
                      }
                      final categories = (snapshot.data ?? const [])
                          .where((category) => category.isActive)
                          .toList();
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
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
                            : (value) => setState(() => _selectedCategoryId = value),
                      );
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
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit complaint'),
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/unsaved_changes_dialog.dart';
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
  bool _allowExitWithoutPrompt = false;

  bool get _hasUnsavedChanges {
    if (_allowExitWithoutPrompt) return false;
    if (_descriptionController.text.trim().isNotEmpty) return true;
    if (_attachmentManager.attachments.isNotEmpty) return true;
    if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) {
      return true;
    }
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
          'This complaint has not been submitted yet. If you leave now, your draft will be lost.',
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _attachmentManager = TicketAttachmentManager(widget.apiClient);
    _categoriesFuture = widget.apiClient.getComplaintCategories();
  }

  void _refreshCategories() {
    setState(() {
      _categoriesFuture = widget.apiClient.getComplaintCategories();
    });
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
      _allowExitWithoutPrompt = true;
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handlePopRequested());
      },
      child: Theme(
        data: AppTheme.withCompactButtons(Theme.of(context)),
        child: AppScreenScaffold(
          appBar: AppBar(title: const Text('New complaint')),
          body: SafeArea(
            child: FutureBuilder<List<ComplaintCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppLoadErrorState(
                    title: 'Failed to load complaint form',
                    message: snapshot.error.toString(),
                    onRetry: _refreshCategories,
                    onLoginAgain: widget.onLoginAgain,
                  );
                }
                final categories = (snapshot.data ?? const [])
                    .where((category) => category.isActive)
                    .toList();
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                : (value) => setState(
                                    () => _selectedCategoryId = value,
                                  ),
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
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Submit complaint'),
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

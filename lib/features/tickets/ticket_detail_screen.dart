import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../auth/app_role.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../delivery_tracking/doc_line_items_dialog.dart';
import '../departments/department_models.dart';
import 'ticket_attachment_manager.dart';
import 'ticket_models.dart';
import 'widgets/ticket_description_field.dart';
import 'widgets/ticket_status_chip.dart';

class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({
    super.key,
    required this.apiClient,
    required this.ticketId,
    required this.isEmployeeView,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final String ticketId;
  final bool isEmployeeView;
  final Future<void> Function() onLoginAgain;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<TicketDetail> _ticketFuture;
  late TabController _discussionTabController;
  final _pageScrollController = ScrollController();
  final _commentsScrollController = ScrollController();
  final _commentController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _addCommentButtonKey = GlobalKey();
  late final TicketAttachmentManager _commentAttachmentManager;
  late final TicketAttachmentManager _descriptionAttachmentManager;
  bool _isSubmittingComment = false;
  bool _isEditingSubject = false;
  bool _isSavingSubject = false;
  bool _isEditingDescription = false;
  bool _isSavingDescription = false;
  bool _isComposingComment = false;
  bool _isAddingCustomerAttachments = false;
  bool _isLinkingCustomerAttachments = false;
  String? _currentUserId;

  bool get _hasUnsavedChanges {
    if (_isEditingSubject) return true;
    if (_isEditingDescription) return true;
    if (_isComposingComment) {
      if (_commentController.text.trim().isNotEmpty) return true;
      if (_commentAttachmentManager.attachments.isNotEmpty) return true;
    }
    if (_isAddingCustomerAttachments &&
        _descriptionAttachmentManager.attachments.isNotEmpty) {
      return true;
    }
    return false;
  }

  String get _unsavedChangesMessage {
    if (_isEditingSubject || _isEditingDescription) {
      return 'You have unsaved edits on this ticket. If you leave now, those changes will be lost.';
    }
    if (_isComposingComment) {
      return 'Your comment draft has not been posted. If you leave now, it will be lost.';
    }
    if (_isAddingCustomerAttachments) {
      return 'You have attachments that have not been uploaded yet. If you leave now, they will be lost.';
    }
    return 'You have unsaved changes. If you leave now, they will be lost.';
  }

  Future<void> _handlePopRequested() async {
    if (!_hasUnsavedChanges) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final leave = await confirmDiscardUnsavedChanges(
      context,
      message: _unsavedChangesMessage,
    );
    if (leave && mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _discussionTabController = TabController(length: 2, vsync: this);
    _discussionTabController.addListener(_handleDiscussionTabChange);
    _commentAttachmentManager = TicketAttachmentManager(widget.apiClient);
    _descriptionAttachmentManager = TicketAttachmentManager(widget.apiClient);
    _ticketFuture = _loadTicket();
    JwtPayload.currentUserId().then((userId) {
      if (!mounted) return;
      setState(() => _currentUserId = userId);
    });
  }

  @override
  void dispose() {
    _discussionTabController.removeListener(_handleDiscussionTabChange);
    _discussionTabController.dispose();
    _pageScrollController.dispose();
    _commentsScrollController.dispose();
    _commentController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _handleDiscussionTabChange() {
    if (_discussionTabController.indexIsChanging) return;
    if (_discussionTabController.index == 0) {
      _scrollCommentsToBottom();
    }
  }

  void _scrollCommentsToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_commentsScrollController.hasClients) return;
      _commentsScrollController.jumpTo(
        _commentsScrollController.position.maxScrollExtent,
      );
    });
  }

  void _startComposingComment(TicketDetail ticket) {
    _applyExistingAttachmentUsage(_commentAttachmentManager, ticket);
    setState(() => _isComposingComment = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _addCommentButtonKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _applyExistingAttachmentUsage(
    TicketAttachmentManager manager,
    TicketDetail ticket,
  ) {
    manager.setExistingAttachments(ticket.attachments);
  }

  Future<void> _cancelComposingComment() async {
    for (final attachment
        in List<PendingTicketAttachment>.from(_commentAttachmentManager.attachments)) {
      await _commentAttachmentManager.removeUnlinked(attachment.attachmentId);
    }
    _commentController.clear();
    if (!mounted) return;
    setState(() => _isComposingComment = false);
  }

  Future<TicketDetail> _loadTicket() {
    return widget.apiClient.getTicket(
      ticketId: widget.ticketId,
      isEmployeeView: widget.isEmployeeView,
    );
  }

  void _refresh() {
    setState(() {
      _ticketFuture = _loadTicket();
    });
  }

  Future<void> _downloadAttachment(TicketAttachment attachment) async {
    try {
      final download = await widget.apiClient.getTicketAttachmentDownload(
        attachmentId: attachment.attachmentId,
      );
      final uri = Uri.parse(download.downloadUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open attachment.');
      }
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Please write a comment before posting.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    setState(() => _isSubmittingComment = true);
    try {
      await widget.apiClient.addTicketComment(
        ticketId: widget.ticketId,
        comment: comment,
        attachmentIds: _commentAttachmentManager.attachmentIds,
      );
      _commentController.clear();
      _commentAttachmentManager.clear();
      if (mounted) setState(() => _isComposingComment = false);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _startWork() async {
    try {
      await widget.apiClient.startTicketWork(ticketId: widget.ticketId);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    }
  }

  Future<void> _resolveTicket() async {
    final summary = await _promptText(
      title: 'Resolve ticket',
      label: 'Resolution summary',
      required: true,
    );
    if (summary == null) return;
    try {
      await widget.apiClient.resolveTicket(
        ticketId: widget.ticketId,
        resolutionSummary: summary,
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    }
  }

  Future<void> _invalidateTicket() async {
    final reason = await _promptText(
      title: 'Invalidate ticket',
      label: 'Reason',
      required: true,
    );
    if (reason == null) return;
    try {
      await widget.apiClient.invalidateTicket(
        ticketId: widget.ticketId,
        reason: reason,
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    }
  }

  Future<void> _closeTicket() async {
    try {
      await widget.apiClient.closeTicket(ticketId: widget.ticketId);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    }
  }

  void _startEditingSubject(TicketDetail ticket) {
    _subjectController.text = ticket.subject;
    setState(() {
      _isEditingSubject = true;
      _isEditingDescription = false;
    });
  }

  void _cancelEditingSubject() {
    _subjectController.clear();
    setState(() => _isEditingSubject = false);
  }

  Future<void> _saveSubject(TicketDetail ticket) async {
    final subject = _subjectController.text.trim();
    if (subject.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Subject cannot be empty.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => _isSavingSubject = true);
    try {
      await widget.apiClient.updateTicket(
        ticketId: ticket.id,
        body: {'subject': subject},
        isEmployeeView: widget.isEmployeeView,
      );
      _subjectController.clear();
      if (mounted) setState(() => _isEditingSubject = false);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingSubject = false);
    }
  }

  void _startEditingDescription(TicketDetail ticket) {
    _descriptionController.text = ticket.description;
    _descriptionAttachmentManager.clear();
    _applyExistingAttachmentUsage(_descriptionAttachmentManager, ticket);
    setState(() {
      _isEditingDescription = true;
      _isEditingSubject = false;
    });
  }

  Future<void> _cancelEditingDescription() async {
    for (final attachment in List<PendingTicketAttachment>.from(
      _descriptionAttachmentManager.attachments,
    )) {
      await _descriptionAttachmentManager.removeUnlinked(attachment.attachmentId);
    }
    _descriptionController.clear();
    if (!mounted) return;
    setState(() => _isEditingDescription = false);
  }

  Future<void> _saveDescription(TicketDetail ticket) async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Description cannot be empty.',
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => _isSavingDescription = true);
    try {
      final body = <String, Object?>{
        'description': description,
      };
      if (_descriptionAttachmentManager.attachmentIds.isNotEmpty) {
        body['attachmentIds'] = _descriptionAttachmentManager.attachmentIds;
      }
      await widget.apiClient.updateTicket(
        ticketId: ticket.id,
        body: body,
        isEmployeeView: widget.isEmployeeView,
      );
      _descriptionController.clear();
      _descriptionAttachmentManager.clear();
      if (mounted) setState(() => _isEditingDescription = false);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSavingDescription = false);
    }
  }

  void _startAddingCustomerAttachments(TicketDetail ticket) {
    _descriptionAttachmentManager.clear();
    _applyExistingAttachmentUsage(_descriptionAttachmentManager, ticket);
    setState(() => _isAddingCustomerAttachments = true);
  }

  Future<void> _cancelAddingCustomerAttachments() async {
    for (final attachment in List<PendingTicketAttachment>.from(
      _descriptionAttachmentManager.attachments,
    )) {
      await _descriptionAttachmentManager.removeUnlinked(attachment.attachmentId);
    }
    if (!mounted) return;
    setState(() => _isAddingCustomerAttachments = false);
  }

  Future<void> _linkCustomerAttachments(TicketDetail ticket) async {
    final attachmentIds = _descriptionAttachmentManager.attachmentIds;
    if (attachmentIds.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Add at least one attachment.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => _isLinkingCustomerAttachments = true);
    try {
      await widget.apiClient.linkTicketAttachments(
        ticketId: ticket.id,
        attachmentIds: attachmentIds,
      );
      _descriptionAttachmentManager.clear();
      if (mounted) setState(() => _isAddingCustomerAttachments = false);
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLinkingCustomerAttachments = false);
    }
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required bool required,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _TicketPromptDialog(
        title: title,
        label: label,
        requiredField: required,
      ),
    );
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
          appBar: AppBar(
            title: Text(widget.isEmployeeView ? 'Ticket' : 'Complaint'),
          ),
          body: SafeArea(
        child: FutureBuilder<TicketDetail>(
          future: _ticketFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: widget.isEmployeeView
                    ? 'Failed to load Ticket'
                    : 'Failed to load Complaint',
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLoginAgain: widget.onLoginAgain,
              );
            }
            final ticket = snapshot.data;
            if (ticket == null) {
              return const Center(child: Text('Ticket not found.'));
            }
            return SingleChildScrollView(
              controller: _pageScrollController,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isEditingSubject &&
                          ticket.canEditSubjectAndDescription(_currentUserId)) ...[
                        Text(
                          '#${ticket.id}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _subjectController,
                          enabled: !_isSavingSubject,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Subject'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton(
                              onPressed:
                                  _isSavingSubject ? null : _cancelEditingSubject,
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _isSavingSubject
                                  ? null
                                  : () => _saveSubject(ticket),
                              child: _isSavingSubject
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                            const Spacer(),
                            TicketStatusChip(status: ticket.status),
                          ],
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                        height: 1.25,
                                      ),
                                  children: [
                                    TextSpan(text: '#${ticket.id} · '),
                                    TextSpan(
                                      text: ticket.subject.trim().isEmpty
                                          ? '—'
                                          : ticket.subject,
                                    ),
                                    if (widget.isEmployeeView &&
                                        ticket.canEditSubjectAndDescription(
                                          _currentUserId,
                                        ))
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 4),
                                          child: IconButton(
                                            tooltip: 'Edit subject',
                                            onPressed: () =>
                                                _startEditingSubject(ticket),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 28,
                                              minHeight: 28,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TicketStatusChip(status: ticket.status),
                          ],
                        ),
                      if (widget.isEmployeeView) ...[
                        const SizedBox(height: 8),
                        _RaisedByLine(
                          apiClient: widget.apiClient,
                          ticket: ticket,
                        ),
                        const SizedBox(height: 8),
                        _TicketAssigneeHeader(
                          apiClient: widget.apiClient,
                          ticket: ticket,
                          onReassigned: _refresh,
                        ),
                      ],
                      if (widget.isEmployeeView) ...[
                        const SizedBox(height: 16),
                        _EmployeeActions(
                          apiClient: widget.apiClient,
                          ticket: ticket,
                          onStart: _startWork,
                          onResolve: _resolveTicket,
                          onInvalidate: _invalidateTicket,
                          onClose: _closeTicket,
                        ),
                      ],
                      const SizedBox(height: 20),
                      if (widget.isEmployeeView &&
                          _isEditingDescription &&
                          ticket.canEditSubjectAndDescription(_currentUserId))
                        TicketDescriptionField(
                          controller: _descriptionController,
                          attachmentManager: _descriptionAttachmentManager,
                          onAttachmentsChanged: () => setState(() {}),
                          labelText: 'Description',
                          enabled: !_isSavingDescription,
                          isSubmitting: _isSavingDescription,
                          autofocus: true,
                          onCancel: _isSavingDescription
                              ? null
                              : _cancelEditingDescription,
                          onSubmit: _isSavingDescription
                              ? null
                              : () => _saveDescription(ticket),
                        )
                      else
                        _TicketDescriptionHero(
                          description: ticket.description,
                          onEdit: widget.isEmployeeView &&
                                  ticket.canEditSubjectAndDescription(
                                    _currentUserId,
                                  )
                              ? () => _startEditingDescription(ticket)
                              : null,
                        ),
                      if (widget.isEmployeeView || ticket.isRaisedByCustomer) ...[
                        const SizedBox(height: 16),
                        _AttachmentsSection(
                          attachments: ticket.attachments,
                          onOpen: _downloadAttachment,
                        ),
                      ],
                      if (!widget.isEmployeeView &&
                          ticket.canCustomerAddAttachments) ...[
                        const SizedBox(height: 16),
                        if (!_isAddingCustomerAttachments)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _startAddingCustomerAttachments(ticket),
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Add attachments'),
                            ),
                          )
                        else
                          TicketComposerField(
                            attachmentManager: _descriptionAttachmentManager,
                            onAttachmentsChanged: () => setState(() {}),
                            showTextField: false,
                            enabled: !_isLinkingCustomerAttachments,
                            isSubmitting: _isLinkingCustomerAttachments,
                            onCancel: _isLinkingCustomerAttachments
                                ? null
                                : _cancelAddingCustomerAttachments,
                            onSubmit: _isLinkingCustomerAttachments
                                ? null
                                : () => _linkCustomerAttachments(ticket),
                            submitLabel: 'Submit',
                          ),
                      ],
                      if (ticket.resolutionSummary.isNotEmpty ||
                          ticket.invalidationReason.isNotEmpty ||
                          ticket.hasRelatedDoc ||
                          widget.isEmployeeView) ...[
                        const SizedBox(height: 16),
                        _TicketFieldsPanel(
                          ticket: ticket,
                          isEmployeeView: widget.isEmployeeView,
                          onRelatedInvoiceTap: ticket.hasRelatedDoc
                              ? () => showDocLineItemsDialog(
                                    context: context,
                                    apiClient: widget.apiClient,
                                    docId: ticket.relatedDocId,
                                    onLoginAgain: widget.onLoginAgain,
                                  )
                              : null,
                        ),
                      ],
                      if (widget.isEmployeeView) ...[
                        const SizedBox(height: 24),
                        _TicketDiscussionTabs(
                          tabController: _discussionTabController,
                          comments: ticket.comments,
                          activity: ticket.activity,
                          attachments: ticket.attachments,
                          commentsScrollController: _commentsScrollController,
                          canComposeComment: !ticket.isClosed,
                          isComposingComment: _isComposingComment,
                          addCommentButtonKey: _addCommentButtonKey,
                          onStartComposing: () => _startComposingComment(ticket),
                          onOpenAttachment: _downloadAttachment,
                          commentComposer: _isComposingComment && !ticket.isClosed
                              ? _CommentComposer(
                                  controller: _commentController,
                                  attachmentManager: _commentAttachmentManager,
                                  isSubmitting: _isSubmittingComment,
                                  onAttachmentsChanged: () => setState(() {}),
                                  onCancel: _isSubmittingComment
                                      ? null
                                      : _cancelComposingComment,
                                  onSubmit: _addComment,
                                )
                              : null,
                        ),
                      ],
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

class _TicketPromptDialog extends StatefulWidget {
  const _TicketPromptDialog({
    required this.title,
    required this.label,
    required this.requiredField,
  });

  final String title;
  final String label;
  final bool requiredField;

  @override
  State<_TicketPromptDialog> createState() => _TicketPromptDialogState();
}

class _TicketPromptDialogState extends State<_TicketPromptDialog> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 3,
        maxLines: null,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (widget.requiredField && value.isEmpty) return;
            Navigator.of(context).pop(value);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EmployeeActions extends StatelessWidget {
  const _EmployeeActions({
    required this.apiClient,
    required this.ticket,
    required this.onStart,
    required this.onResolve,
    required this.onInvalidate,
    required this.onClose,
  });

  final ApiClient apiClient;
  final TicketDetail ticket;
  final VoidCallback onStart;
  final VoidCallback onResolve;
  final VoidCallback onInvalidate;
  final VoidCallback onClose;

  Future<_EmployeeActionPermissions> _loadPermissions() async {
    final userId = await JwtPayload.currentUserId();
    final roles = await JwtPayload.currentRoles();
    final isAssignee =
        userId != null && userId == ticket.assigneeAppUserId;
    final isAdmin = roles.hasRole(AppRole.appAdmin);

    var isDepartmentLead = false;
    var isTicketTriager = false;
    if (userId != null && ticket.assignedDepartmentId.isNotEmpty) {
      try {
        final departments = await apiClient.getDepartments();
        Department? assignedDepartment;
        for (final department in departments) {
          if (department.id == ticket.assignedDepartmentId) {
            assignedDepartment = department;
            break;
          }
        }
        final membership = assignedDepartment?.users
            .where((user) => user.id == userId)
            .firstOrNull;
        isDepartmentLead = membership?.isDepartmentLead == true;
        isTicketTriager = membership?.isTicketTriager == true;
      } catch (_) {
        // Keep resolve/invalidate hidden if department lookup fails.
      }
    }

    final canActOnWorkStatus =
        ticket.status == TicketStatus.open ||
        ticket.status == TicketStatus.assigned ||
        ticket.status == TicketStatus.inProgress;
    final canActOnTicket =
        (isAssignee || isDepartmentLead || isTicketTriager) &&
        canActOnWorkStatus;

    return _EmployeeActionPermissions(
      canStartWork: isAssignee &&
          (ticket.status == TicketStatus.open ||
              ticket.status == TicketStatus.assigned),
      canResolve: canActOnTicket && ticket.status == TicketStatus.inProgress,
      canInvalidate: canActOnTicket,
      canClose: isAdmin &&
          (ticket.status == TicketStatus.resolved ||
              ticket.status == TicketStatus.invalid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EmployeeActionPermissions>(
      future: _loadPermissions(),
      builder: (context, snapshot) {
        final permissions = snapshot.data;
        if (permissions == null) {
          return const SizedBox.shrink();
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (permissions.canStartWork)
              ElevatedButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: const Text('Start work'),
              ),
            if (permissions.canResolve)
              ElevatedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.check_circle_outline, size: 20),
                label: const Text('Resolve'),
              ),
            if (permissions.canInvalidate)
              ElevatedButton.icon(
                onPressed: onInvalidate,
                icon: const Icon(Icons.block_flipped, size: 20),
                label: const Text('Invalidate'),
              ),
            if (permissions.canClose)
              ElevatedButton.icon(
                onPressed: onClose,
                icon: const Icon(Icons.lock_outline, size: 20),
                label: const Text('Close ticket'),
              ),
          ],
        );
      },
    );
  }
}

class _EmployeeActionPermissions {
  const _EmployeeActionPermissions({
    required this.canStartWork,
    required this.canResolve,
    required this.canInvalidate,
    required this.canClose,
  });

  final bool canStartWork;
  final bool canResolve;
  final bool canInvalidate;
  final bool canClose;
}

class _TicketAssigneeHeader extends StatelessWidget {
  const _TicketAssigneeHeader({
    required this.apiClient,
    required this.ticket,
    required this.onReassigned,
  });

  final ApiClient apiClient;
  final TicketDetail ticket;
  final VoidCallback onReassigned;

  Future<_TicketAssignmentViewData> _load() async {
    final userId = await JwtPayload.currentUserId();
    List<Department> departments = const [];
    var canReassign = false;

    if (ticket.canReassignByStatus &&
        userId != null &&
        ticket.assignedDepartmentId.isNotEmpty) {
      try {
        departments = await apiClient.getDepartments();
        final currentDept = departments
            .where((department) => department.id == ticket.assignedDepartmentId)
            .firstOrNull;
        final membership = currentDept?.users
            .where((user) => user.id == userId)
            .firstOrNull;
        final isAssignee = userId == ticket.assigneeAppUserId;
        final isLead = membership?.isDepartmentLead == true;
        final isTriager = membership?.isTicketTriager == true;
        canReassign = isAssignee || isLead || isTriager;
      } catch (_) {
        canReassign = false;
        departments = const [];
      }
    }

    return _TicketAssignmentViewData(
      canReassign: canReassign,
      departments: departments,
    );
  }

  Future<void> _openReassignDialog(
    BuildContext context,
    List<Department> departments,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ReassignTicketDialog(
        apiClient: apiClient,
        ticket: ticket,
        departments: departments,
      ),
    );
    if (saved == true) onReassigned();
  }

  @override
  Widget build(BuildContext context) {
    final assigneeLabel =
        ticket.assigneeName.trim().isEmpty ? 'Unassigned' : ticket.assigneeName;
    final theme = Theme.of(context);

    return FutureBuilder<_TicketAssignmentViewData>(
      future: _load(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final canReassign = data?.canReassign == true;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Assignee',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                assigneeLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            if (canReassign) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reassign',
                onPressed: () => _openReassignDialog(
                  context,
                  data?.departments ?? const [],
                ),
                icon: const Icon(Icons.swap_horiz, size: 16),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  fixedSize: const Size(26, 26),
                  minimumSize: const Size(26, 26),
                  maximumSize: const Size(26, 26),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _TicketAssignmentViewData {
  const _TicketAssignmentViewData({
    required this.canReassign,
    required this.departments,
  });

  final bool canReassign;
  final List<Department> departments;
}

class _ReassignTicketDialog extends StatefulWidget {
  const _ReassignTicketDialog({
    required this.apiClient,
    required this.ticket,
    required this.departments,
  });

  final ApiClient apiClient;
  final TicketDetail ticket;
  final List<Department> departments;

  @override
  State<_ReassignTicketDialog> createState() => _ReassignTicketDialogState();
}

class _ReassignTicketDialogState extends State<_ReassignTicketDialog> {
  late String? _selectedDepartmentId;
  /// Empty string means unassigned; null means no selection yet.
  late String? _selectedAssigneeId;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _departmentChanged =>
      _selectedDepartmentId != null &&
      _selectedDepartmentId != widget.ticket.assignedDepartmentId;

  List<Department> get _departmentOptions {
    final active = widget.departments.where((dept) => dept.isActive).toList();
    final currentId = widget.ticket.assignedDepartmentId;
    if (currentId.isEmpty) return active;
    final alreadyIncluded = active.any((dept) => dept.id == currentId);
    if (alreadyIncluded) return active;
    final current = widget.departments
        .where((dept) => dept.id == currentId)
        .firstOrNull;
    if (current == null) return active;
    return [...active, current];
  }

  Department? get _selectedDepartment {
    final id = _selectedDepartmentId;
    if (id == null) return null;
    return widget.departments.where((dept) => dept.id == id).firstOrNull;
  }

  List<DepartmentUser> get _assigneeOptions {
    final department = _selectedDepartment;
    if (department == null) return const [];
    final includeId = _departmentChanged
        ? null
        : widget.ticket.assigneeAppUserId;
    return department.selectableUsers(includeUserId: includeId);
  }

  @override
  void initState() {
    super.initState();
    _selectedDepartmentId = widget.ticket.assignedDepartmentId.isEmpty
        ? null
        : widget.ticket.assignedDepartmentId;
    final currentAssignee = widget.ticket.assigneeAppUserId.trim();
    _selectedAssigneeId = currentAssignee.isEmpty ? '' : currentAssignee;
  }

  Future<void> _save() async {
    final departmentId = _selectedDepartmentId?.trim() ?? '';
    if (departmentId.isEmpty) {
      setState(() => _errorMessage = 'Select a department.');
      return;
    }

    final assigneeId = _selectedAssigneeId?.trim() ?? '';
    if (_departmentChanged && assigneeId.isEmpty) {
      setState(
        () => _errorMessage =
            'A new assignee from the new department is required when changing department.',
      );
      return;
    }

    if (widget.ticket.reassignReopensTicket) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reopen ticket?'),
          content: Text(
            'This ticket is ${widget.ticket.status.label.toLowerCase()}. '
            'Reassigning will reopen it '
            '(${assigneeId.isEmpty ? 'OPEN' : 'ASSIGNED'}). Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.apiClient.assignTicket(
        ticketId: widget.ticket.id,
        assignedDepartmentId: departmentId,
        assigneeAppUserId: assigneeId.isEmpty ? null : assigneeId,
      );
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
    final assignees = _assigneeOptions;
    final assigneeItems = <DropdownMenuItem<String>>[
      if (!_departmentChanged)
        const DropdownMenuItem<String>(
          value: '',
          child: Text('Unassigned'),
        ),
      ...assignees.map(
        (user) => DropdownMenuItem(
          value: user.id,
          child: Text(
            user.isActive
                ? user.personName
                : '${user.personName} (Inactive)',
          ),
        ),
      ),
    ];
    final assigneeValue = assigneeItems.any(
          (item) => item.value == _selectedAssigneeId,
        )
        ? _selectedAssigneeId
        : (_departmentChanged ? null : '');

    return AlertDialog(
      title: const Text('Reassign ticket'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _departmentOptions.any(
                    (dept) => dept.id == _selectedDepartmentId,
                  )
                  ? _selectedDepartmentId
                  : null,
              decoration: const InputDecoration(labelText: 'Department'),
              items: _departmentOptions
                  .map(
                    (dept) => DropdownMenuItem(
                      value: dept.id,
                      child: Text(
                        dept.isActive ? dept.name : '${dept.name} (Inactive)',
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
                        final dept = widget.departments
                            .where((item) => item.id == value)
                            .firstOrNull;
                        if (value != widget.ticket.assignedDepartmentId) {
                          _selectedAssigneeId =
                              dept?.activeTicketTriager?.id ?? '';
                        } else {
                          final current = widget.ticket.assigneeAppUserId.trim();
                          _selectedAssigneeId =
                              current.isEmpty ? '' : current;
                        }
                      });
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'reassign-assignee-$_selectedDepartmentId-$assigneeValue',
              ),
              initialValue: assigneeValue,
              decoration: InputDecoration(
                labelText: _selectedDepartmentId == null
                    ? 'Assignee (Select Dept First)'
                    : _departmentChanged
                        ? 'Assignee'
                        : 'Assignee (optional)',
              ),
              items: assigneeItems,
              onChanged: _isSaving || _selectedDepartmentId == null
                  ? null
                  : (value) => setState(() {
                        _selectedAssigneeId = value ?? '';
                        _errorMessage = null;
                      }),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _RaisedByDisplay {
  const _RaisedByDisplay({
    required this.name,
    this.onBehalfOfCustomer,
  });

  final String name;
  final String? onBehalfOfCustomer;
}

class _RaisedByLine extends StatefulWidget {
  const _RaisedByLine({
    required this.apiClient,
    required this.ticket,
  });

  final ApiClient apiClient;
  final TicketDetail ticket;

  @override
  State<_RaisedByLine> createState() => _RaisedByLineState();
}

class _RaisedByLineState extends State<_RaisedByLine> {
  late final Future<_RaisedByDisplay> _displayFuture = _resolveDisplay();

  Future<_RaisedByDisplay> _resolveDisplay() async {
    final ticket = widget.ticket;
    final apiClient = widget.apiClient;

    if (ticket.isCustomerSelfService) {
      final name = await _resolveCustomerName(
        apiClient: apiClient,
        customerId: ticket.raisedForCustomerId,
        fallbackName: ticket.raisedForCustomerName,
      );
      return _RaisedByDisplay(name: name);
    }

    final employeeName = await _resolveEmployeeName(
      apiClient: apiClient,
      ticket: ticket,
    );

    if (ticket.ticketType != TicketType.raisedForCustomer) {
      return _RaisedByDisplay(name: employeeName);
    }

    final onBehalf = await _resolveCustomerName(
      apiClient: apiClient,
      customerId: ticket.raisedForCustomerId,
      fallbackName: ticket.raisedOnBehalfOfCustomerLabel,
    );
    return _RaisedByDisplay(
      name: employeeName,
      onBehalfOfCustomer: onBehalf == 'Unknown' ? null : onBehalf,
    );
  }

  Future<String> _resolveEmployeeName({
    required ApiClient apiClient,
    required TicketDetail ticket,
  }) async {
    final fromTicket = ticket.raisedByLabel;
    if (fromTicket.isNotEmpty) return fromTicket;

    final userId = ticket.raisedByEmployeeId;
    if (userId.isEmpty) return 'Unknown';

    try {
      final users = await apiClient.getUsers();
      final match = users.where((user) => user.id == userId).firstOrNull;
      final name = match?.personName.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Fall through to departments lookup.
    }

    try {
      final departments = await apiClient.getDepartments();
      for (final department in departments) {
        final match =
            department.users.where((user) => user.id == userId).firstOrNull;
        final name = match?.personName.trim() ?? '';
        if (name.isNotEmpty) return name;
      }
    } catch (_) {
      // Keep Unknown if lookups fail.
    }

    return 'Unknown';
  }

  Future<String> _resolveCustomerName({
    required ApiClient apiClient,
    required String customerId,
    required String fallbackName,
  }) async {
    final fromTicket = fallbackName.trim();
    if (fromTicket.isNotEmpty) return fromTicket;

    final id = customerId.trim();
    if (id.isEmpty) return 'Unknown';

    try {
      final customer = await apiClient.getCustomer(id: id);
      final name = customer.firmName.trim();
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Keep Unknown if lookup fails.
    }

    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RaisedByDisplay>(
      future: _displayFuture,
      builder: (context, snapshot) {
        final display = snapshot.data;
        if (display == null || display.name.isEmpty) {
          return const SizedBox.shrink();
        }

        const primaryStyle = TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        );
        final onBehalf = display.onBehalfOfCustomer?.trim() ?? '';

        if (onBehalf.isEmpty) {
          return Text('Raised by ${display.name}', style: primaryStyle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Raised by ${display.name}', style: primaryStyle),
            const SizedBox(height: 2),
            Text(
              '(On behalf of customer $onBehalf)',
              style: primaryStyle.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TicketDescriptionHero extends StatelessWidget {
  const _TicketDescriptionHero({
    required this.description,
    this.onEdit,
  });

  final String description;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          height: 1.55,
          fontSize: 17,
        );
    final text = description.trim().isEmpty ? 'No description.' : description;

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit description',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(text, style: bodyStyle),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;
    final valueStyle = TextStyle(
      color: onTap == null ? Colors.black : primary,
      height: 1.35,
      fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w600,
      decoration: onTap == null ? null : TextDecoration.underline,
      decorationColor: primary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: onTap == null
                ? Text(value, style: valueStyle)
                : InkWell(
                    onTap: onTap,
                    child: Text(value, style: valueStyle),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TicketFieldsPanel extends StatelessWidget {
  const _TicketFieldsPanel({
    required this.ticket,
    required this.isEmployeeView,
    this.onRelatedInvoiceTap,
  });

  final TicketDetail ticket;
  final bool isEmployeeView;
  final VoidCallback? onRelatedInvoiceTap;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: 8),
            if (ticket.resolutionSummary.isNotEmpty)
              _InfoRow('Resolution', ticket.resolutionSummary),
            if (ticket.invalidationReason.isNotEmpty)
              _InfoRow('Invalidation reason', ticket.invalidationReason),
            if (ticket.hasRelatedDoc)
              _InfoRow(
                'Related invoice',
                ticket.relatedDocId,
                onTap: onRelatedInvoiceTap,
              ),
            if (isEmployeeView) ...[
              _InfoRow('Priority', ticket.priority.label),
              _InfoRow(
                'Department',
                ticket.assignedDepartmentName.isEmpty
                    ? '—'
                    : ticket.assignedDepartmentName,
              ),
              _InfoRow('Customer', ticket.raisedForCustomerName),
              _InfoRow('Category', ticket.categoryDisplayLabel),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.attachments, required this.onOpen});

  final List<TicketAttachment> attachments;
  final ValueChanged<TicketAttachment> onOpen;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Attachments',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
            ),
            const SizedBox(height: 12),
            if (attachments.isEmpty)
              const Text(
                'No attachments.',
                style: TextStyle(color: Colors.black54, height: 1.35),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: attachments
                    .map(
                      (attachment) => _AttachmentGridTile(
                        attachment: attachment,
                        onOpen: () => onOpen(attachment),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentGridTile extends StatelessWidget {
  const _AttachmentGridTile({
    required this.attachment,
    required this.onOpen,
    this.compact = false,
  });

  final TicketAttachment attachment;
  final VoidCallback onOpen;
  final bool compact;

  IconData get _icon {
    final mime = attachment.mimeType.toLowerCase();
    if (mime.startsWith('audio/')) return Icons.mic;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('sheet') || mime.contains('excel') || mime.contains('csv')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('word') || mime.contains('document')) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tileWidth = compact ? 64.0 : 88.0;
    final iconSize = compact ? 20.0 : 28.0;
    final fontSize = compact ? 9.0 : 11.0;
    final radius = compact ? 10.0 : 12.0;
    final padding = compact
        ? const EdgeInsets.fromLTRB(6, 10, 6, 6)
        : const EdgeInsets.fromLTRB(8, 10, 8, 8);
    final gap = compact ? 4.0 : 8.0;

    return Tooltip(
      message: attachment.originalFileName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            width: tileWidth,
            height: compact ? 64 : null,
            padding: padding,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: primary.withValues(alpha: 0.22)),
            ),
            child: Column(
              mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
              children: [
                Icon(
                  _icon,
                  size: iconSize,
                  color: AppTheme.primaryAccentText(primary),
                ),
                SizedBox(height: gap),
                if (compact)
                  Expanded(
                    child: Text(
                      attachment.originalFileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: fontSize,
                        height: 1.15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  Text(
                    attachment.originalFileName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: fontSize,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketDiscussionTabs extends StatelessWidget {
  const _TicketDiscussionTabs({
    required this.tabController,
    required this.comments,
    required this.activity,
    required this.attachments,
    required this.commentsScrollController,
    required this.canComposeComment,
    required this.isComposingComment,
    required this.addCommentButtonKey,
    required this.onStartComposing,
    required this.onOpenAttachment,
    this.commentComposer,
  });

  final TabController tabController;
  final List<TicketComment> comments;
  final List<TicketActivity> activity;
  final List<TicketAttachment> attachments;
  final ScrollController commentsScrollController;
  final bool canComposeComment;
  final bool isComposingComment;
  final GlobalKey addCommentButtonKey;
  final VoidCallback onStartComposing;
  final ValueChanged<TicketAttachment> onOpenAttachment;
  final Widget? commentComposer;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppSurface(
      borderRadius: 16,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.black54,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              splashFactory: NoSplash.splashFactory,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              tabs: [
                Tab(
                  height: 36,
                  text: 'Comments (${comments.length})',
                ),
                Tab(
                  height: 36,
                  text: 'Activity (${activity.length})',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                final showingComments = tabController.index == 0;
                if (!showingComments) {
                  return _ActivityList(activity: activity);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CommentList(
                      comments: comments,
                      attachments: attachments,
                      scrollController: commentsScrollController,
                      onOpenAttachment: onOpenAttachment,
                    ),
                    if (canComposeComment) ...[
                      const SizedBox(height: 12),
                      if (!isComposingComment)
                        Align(
                          key: addCommentButtonKey,
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: onStartComposing,
                            icon: const Icon(Icons.add_comment_outlined),
                            label: const Text('Add New Comment'),
                          ),
                        )
                      else
                        commentComposer!,
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.attachmentManager,
    required this.isSubmitting,
    required this.onAttachmentsChanged,
    required this.onSubmit,
    this.onCancel,
  });

  final TextEditingController controller;
  final TicketAttachmentManager attachmentManager;
  final bool isSubmitting;
  final VoidCallback onAttachmentsChanged;
  final VoidCallback onSubmit;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return TicketCommentField(
      controller: controller,
      attachmentManager: attachmentManager,
      onAttachmentsChanged: onAttachmentsChanged,
      enabled: !isSubmitting,
      isSubmitting: isSubmitting,
      onSubmit: onSubmit,
      onCancel: onCancel,
    );
  }
}

class _CommentList extends StatefulWidget {
  const _CommentList({
    required this.comments,
    required this.attachments,
    required this.scrollController,
    required this.onOpenAttachment,
  });

  final List<TicketComment> comments;
  final List<TicketAttachment> attachments;
  final ScrollController scrollController;
  final ValueChanged<TicketAttachment> onOpenAttachment;

  @override
  State<_CommentList> createState() => _CommentListState();
}

class _CommentListState extends State<_CommentList> {
  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _CommentList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comments.length != widget.comments.length ||
        oldWidget.comments.map((c) => c.id).join() !=
            widget.comments.map((c) => c.id).join()) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.scrollController.hasClients) return;
      widget.scrollController.jumpTo(
        widget.scrollController.position.maxScrollExtent,
      );
    });
  }

  List<TicketAttachment> _attachmentsFor(TicketComment comment) {
    return widget.attachments
        .where((attachment) => attachment.commentId == comment.id)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No comments yet.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: widget.comments.length == 1 ? 220 : 400,
      ),
      child: ListView.builder(
        controller: widget.scrollController,
        shrinkWrap: true,
        itemCount: widget.comments.length,
        itemBuilder: (context, index) {
          final comment = widget.comments[index];
          final commentAttachments = _attachmentsFor(comment);
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == widget.comments.length - 1 ? 0 : 12,
            ),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            comment.createdByName,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (comment.createdAt != null)
                          Text(
                            _formatTicketTimestamp(comment.createdAt!),
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.comment,
                      style: const TextStyle(color: Colors.black),
                    ),
                    if (commentAttachments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: commentAttachments
                            .map(
                              (attachment) => _AttachmentGridTile(
                                attachment: attachment,
                                compact: true,
                                onOpen: () =>
                                    widget.onOpenAttachment(attachment),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.activity});

  final List<TicketActivity> activity;

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return const Text(
        'No activity recorded yet.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: activity.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.message,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                  if (entry.createdAt != null)
                    Text(
                      _formatTicketTimestamp(entry.createdAt!),
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${entry.createdByName} · ${entry.activityType}',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

String _formatTicketTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final hourOfPeriod = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$month ${local.day}, ${local.year} · $hourOfPeriod:$minute $period';
}

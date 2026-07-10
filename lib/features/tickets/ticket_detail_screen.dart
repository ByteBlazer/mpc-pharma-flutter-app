import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../auth/app_role.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'ticket_attachment_manager.dart';
import 'ticket_models.dart';
import 'widgets/ticket_audio_recorder_button.dart';
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
  final _commentController = TextEditingController();
  late final TicketAttachmentManager _commentAttachmentManager;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _discussionTabController = TabController(length: 2, vsync: this);
    _commentAttachmentManager = TicketAttachmentManager(widget.apiClient);
    _ticketFuture = _loadTicket();
  }

  @override
  void dispose() {
    _discussionTabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<TicketDetail> _loadTicket() {
    return widget.apiClient.getTicket(
      ticketId: widget.ticketId,
      isEmployeeView: widget.isEmployeeView,
    );
  }

  void _refresh() {
    setState(() => _ticketFuture = _loadTicket());
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
    if (comment.isEmpty) return;
    setState(() => _isSubmittingComment = true);
    try {
      await widget.apiClient.addTicketComment(
        ticketId: widget.ticketId,
        comment: comment,
        attachmentIds: _commentAttachmentManager.attachmentIds,
      );
      _commentController.clear();
      _commentAttachmentManager.clear();
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

  Future<void> _addCustomerAttachments(TicketDetail ticket) async {
    if (_commentAttachmentManager.attachmentIds.isEmpty) return;
    try {
      await widget.apiClient.linkTicketAttachments(
        ticketId: ticket.id,
        attachmentIds: _commentAttachmentManager.attachmentIds,
      );
      _commentAttachmentManager.clear();
      _refresh();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    }
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: null,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (required && value.isEmpty) return;
              Navigator.of(context).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
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
              return Center(child: Text(snapshot.error.toString()));
            }
            final ticket = snapshot.data;
            if (ticket == null) {
              return const Center(child: Text('Ticket not found.'));
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '#${ticket.id} · ${ticket.subject}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TicketStatusChip(status: ticket.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.isEmployeeView) ...[
                        _InfoRow('Priority', ticket.priority.label),
                        _InfoRow('Type', ticket.ticketType.apiValue),
                        _InfoRow('Department', ticket.assignedDepartmentName),
                        _InfoRow('Assignee', ticket.assigneeName),
                        _InfoRow('Customer', ticket.raisedForCustomerName),
                        _InfoRow('Category', ticket.ticketComplaintCategoryName),
                      ],
                      _InfoRow('Description', ticket.description),
                      if (ticket.resolutionSummary.isNotEmpty)
                        _InfoRow('Resolution', ticket.resolutionSummary),
                      if (ticket.invalidationReason.isNotEmpty)
                        _InfoRow('Invalidation reason', ticket.invalidationReason),
                      const SizedBox(height: 16),
                      _AttachmentsSection(
                        attachments: ticket.attachments,
                        onOpen: _downloadAttachment,
                      ),
                      if (widget.isEmployeeView) ...[
                        const SizedBox(height: 24),
                        _TicketDiscussionTabs(
                          tabController: _discussionTabController,
                          comments: ticket.comments,
                          activity: ticket.activity,
                        ),
                        const SizedBox(height: 24),
                        if (!ticket.isClosed)
                          TicketCommentField(
                            controller: _commentController,
                            attachmentManager: _commentAttachmentManager,
                            onAttachmentsChanged: () => setState(() {}),
                          ),
                        if (!ticket.isClosed) ...[
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _isSubmittingComment ? null : _addComment,
                            child: _isSubmittingComment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Add comment'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _EmployeeActions(
                          ticket: ticket,
                          onStart: _startWork,
                          onResolve: _resolveTicket,
                          onInvalidate: _invalidateTicket,
                          onClose: _closeTicket,
                        ),
                      ] else if (!ticket.isTerminal) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Add attachments',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TicketAudioRecorderButton(
                          attachmentManager: _commentAttachmentManager,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        TicketAttachmentPicker(
                          attachmentManager: _commentAttachmentManager,
                          onChanged: () => setState(() {}),
                          enabled: true,
                        ),
                        if (_commentAttachmentManager.attachments.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TicketAttachmentList(
                            attachments: _commentAttachmentManager.attachments,
                            attachmentManager: _commentAttachmentManager,
                            onRemove: () => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _commentAttachmentManager.attachmentIds.isEmpty
                              ? null
                              : () => _addCustomerAttachments(ticket),
                          child: const Text('Upload attachments'),
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
    );
  }
}

class _EmployeeActions extends StatelessWidget {
  const _EmployeeActions({
    required this.ticket,
    required this.onStart,
    required this.onResolve,
    required this.onInvalidate,
    required this.onClose,
  });

  final TicketDetail ticket;
  final VoidCallback onStart;
  final VoidCallback onResolve;
  final VoidCallback onInvalidate;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(String?, List<AppRole>)>(
      future: () async {
        final userId = await JwtPayload.currentUserId();
        final roles = await JwtPayload.currentRoles();
        return (userId, roles);
      }(),
      builder: (context, snapshot) {
        final userId = snapshot.data?.$1;
        final roles = snapshot.data?.$2 ?? const [];
        final isAssignee = userId != null && userId == ticket.assigneeAppUserId;
        final isAdmin = roles.hasRole(AppRole.appAdmin);
        final canManageTicket = isAssignee || isAdmin;
        final canWork = canManageTicket &&
            (ticket.status == TicketStatus.open ||
                ticket.status == TicketStatus.assigned);
        final canResolve = canManageTicket &&
            (ticket.status == TicketStatus.open ||
                ticket.status == TicketStatus.assigned ||
                ticket.status == TicketStatus.inProgress);
        final canClose = isAdmin &&
            (ticket.status == TicketStatus.resolved ||
                ticket.status == TicketStatus.invalid);

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (canWork)
              OutlinedButton(onPressed: onStart, child: const Text('Start work')),
            if (canResolve)
              OutlinedButton(onPressed: onResolve, child: const Text('Resolve')),
            if (canResolve)
              OutlinedButton(onPressed: onInvalidate, child: const Text('Invalidate')),
            if (canClose)
              FilledButton(onPressed: onClose, child: const Text('Close ticket')),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
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
            child: Text(value, style: const TextStyle(color: Colors.black)),
          ),
        ],
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
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attachments',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...attachments.map(
          (attachment) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              attachment.isAudio ? Icons.mic : Icons.insert_drive_file_outlined,
            ),
            title: Text(
              attachment.originalFileName,
              style: const TextStyle(color: Colors.black),
            ),
            trailing: TextButton(
              onPressed: () => onOpen(attachment),
              child: const Text('Open'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketDiscussionTabs extends StatelessWidget {
  const _TicketDiscussionTabs({
    required this.tabController,
    required this.comments,
    required this.activity,
  });

  final TabController tabController;
  final List<TicketComment> comments;
  final List<TicketActivity> activity;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AppSurface(
      borderRadius: 16,
      clip: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: tabController,
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(8),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.black54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            padding: const EdgeInsets.all(8),
            tabs: [
              Tab(text: 'Comments (${comments.length})'),
              Tab(text: 'Activity (${activity.length})'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedBuilder(
              animation: tabController,
              builder: (context, _) {
                return tabController.index == 0
                    ? _CommentList(comments: comments)
                    : _ActivityList(activity: activity);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.comments});

  final List<TicketComment> comments;

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Text(
        'No comments yet.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: comments.map((comment) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                ],
              ),
            ),
          ),
        );
      }).toList(),
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

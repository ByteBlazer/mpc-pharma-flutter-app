import 'package:flutter/material.dart';

import '../../../api/api_client.dart';
import '../../../widgets/app_snack_bar.dart';
import '../leave_helpers.dart';
import '../leave_models.dart';
import 'leave_status_chip.dart';

Future<bool?> showLeaveDetailSheet({
  required BuildContext context,
  required ApiClient apiClient,
  required LeaveRequest leave,
  required String currentUserId,
  required Set<String> leadDepartmentIds,
  required Future<void> Function() onLoginAgain,
  required VoidCallback onChanged,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => LeaveDetailSheet(
      apiClient: apiClient,
      leave: leave,
      currentUserId: currentUserId,
      leadDepartmentIds: leadDepartmentIds,
      onLoginAgain: onLoginAgain,
      onChanged: onChanged,
    ),
  );
}

class LeaveDetailSheet extends StatefulWidget {
  const LeaveDetailSheet({
    super.key,
    required this.apiClient,
    required this.leave,
    required this.currentUserId,
    required this.leadDepartmentIds,
    required this.onLoginAgain,
    required this.onChanged,
  });

  final ApiClient apiClient;
  final LeaveRequest leave;
  final String currentUserId;
  final Set<String> leadDepartmentIds;
  final Future<void> Function() onLoginAgain;
  final VoidCallback onChanged;

  @override
  State<LeaveDetailSheet> createState() => _LeaveDetailSheetState();
}

class _LeaveDetailSheetState extends State<LeaveDetailSheet> {
  late LeaveRequest _leave;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _leave = widget.leave;
  }

  bool get _canWithdraw =>
      _leave.status.isPending && _leave.requesterId == widget.currentUserId;

  bool get _canApproveOrReject => canActOnLeaveRequest(
    leave: _leave,
    leadDepartmentIds: widget.leadDepartmentIds,
  );

  Future<void> _handleAuthError(Object error) async {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: error.toString(),
      type: AppSnackBarType.error,
    );
    await widget.onLoginAgain();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw leave?'),
        content: const Text(
          'This pending leave request will be withdrawn and cannot be acted on.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final updated = await widget.apiClient.withdrawLeave(
        leaveId: _leave.leaveId,
      );
      if (!mounted) return;
      setState(() => _leave = updated);
      widget.onChanged();
      showAppSnackBar(
        context,
        message: 'Leave request withdrawn.',
        type: AppSnackBarType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      if (message.contains('401') || message.contains('403')) {
        await _handleAuthError(error);
        return;
      }
      showAppSnackBar(context, message: message, type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<String?> _promptComment({
    required String title,
    required bool required,
    String? hint,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 4,
          minLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _approve() async {
    final comment = await _promptComment(
      title: 'Approve leave',
      required: false,
      hint: 'Optional comment',
    );
    if (comment == null || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final updated = await widget.apiClient.approveLeave(
        leaveId: _leave.leaveId,
        comment: comment,
      );
      if (!mounted) return;
      setState(() => _leave = updated);
      widget.onChanged();
      showAppSnackBar(
        context,
        message: 'Leave request approved.',
        type: AppSnackBarType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _reject() async {
    final comment = await _promptComment(
      title: 'Reject leave',
      required: true,
      hint: 'Reason for rejection (required)',
    );
    if (comment == null || comment.isEmpty || !mounted) return;

    setState(() => _isSubmitting = true);
    try {
      final updated = await widget.apiClient.rejectLeave(
        leaveId: _leave.leaveId,
        comment: comment,
      );
      if (!mounted) return;
      setState(() => _leave = updated);
      widget.onChanged();
      showAppSnackBar(
        context,
        message: 'Leave request rejected.',
        type: AppSnackBarType.success,
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(context, message: error.toString(), type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = _leave;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Leave #${leave.leaveId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              LeaveStatusChip(status: leave.status),
              IconButton(
                onPressed: _isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Requester', value: leave.requesterName),
          _DetailRow(label: 'Department', value: leave.departmentName),
          _DetailRow(
            label: 'Nominated approver',
            value: leave.nominatedApproverName,
          ),
          _DetailRow(label: 'Dates', value: leave.dateRangeLabel),
          _DetailRow(label: 'Session', value: leave.leaveSession.label),
          if (leave.requestComment.isNotEmpty)
            _DetailRow(label: 'Request comment', value: leave.requestComment),
          if (leave.actedByName != null && leave.actedByName!.isNotEmpty)
            _DetailRow(label: 'Acted by', value: leave.actedByName!),
          if (leave.actionComment != null && leave.actionComment!.isNotEmpty)
            _DetailRow(label: 'Action comment', value: leave.actionComment!),
          if (leave.actionAt != null)
            _DetailRow(
              label: 'Action at',
              value: leave.actionAt!.toLocal().toString(),
            ),
          const SizedBox(height: 16),
          if (_canWithdraw)
            OutlinedButton(
              onPressed: _isSubmitting ? null : _withdraw,
              child: const Text('Withdraw request'),
            ),
          if (_canApproveOrReject) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _approve,
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

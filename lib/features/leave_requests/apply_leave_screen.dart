import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../departments/department_models.dart';
import 'leave_helpers.dart';
import 'leave_models.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    this.departments,
    this.userId,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final List<Department>? departments;
  final String? userId;

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  late Future<_ApplyLeaveData> _dataFuture;
  final _commentController = TextEditingController();

  String? _selectedDepartmentId;
  String? _selectedApproverId;
  DateTime? _fromDate;
  DateTime? _toDate;
  LeaveSession _leaveSession = LeaveSession.fullDay;
  bool _isSubmitting = false;
  bool _allowExitWithoutPrompt = false;

  bool get _hasDraft =>
      _selectedDepartmentId != null ||
      _selectedApproverId != null ||
      _fromDate != null ||
      _toDate != null ||
      _commentController.text.trim().isNotEmpty ||
      _leaveSession != LeaveSession.fullDay;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<_ApplyLeaveData> _loadData() async {
    final departments =
        widget.departments ?? await widget.apiClient.getDepartments();
    final userId = widget.userId?.trim() ?? '';
    final myDepartments = departmentsForUser(departments, userId);
    return _ApplyLeaveData(
      userId: userId,
      myDepartments: myDepartments,
    );
  }

  void _refreshData() {
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _handlePopRequested() async {
    if (_allowExitWithoutPrompt || !_hasDraft) {
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final leave = await confirmDiscardUnsavedChanges(
      context,
      message:
          'This leave request has not been submitted yet. If you leave now, your draft will be lost.',
    );
    if (leave && mounted) Navigator.of(context).pop(false);
  }

  Department? _selectedDepartment(_ApplyLeaveData data) {
    final id = _selectedDepartmentId;
    if (id == null) return null;
    return data.myDepartments
        .where((department) => department.id == id)
        .firstOrNull;
  }

  List<DepartmentUser> _approverOptions(_ApplyLeaveData data) {
    final department = _selectedDepartment(data);
    if (department == null) return const [];
    return activeDepartmentLeads(department);
  }

  bool get _isSingleDay =>
      _fromDate != null && _toDate != null && _fromDate == _toDate;

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? leaveEarliestAllowedDate(),
      firstDate: leaveEarliestAllowedDate(),
      lastDate: leaveLatestAllowedDate(),
      helpText: 'From date (IST)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _fromDate = picked;
      if (_toDate == null || _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
      if (!_isSingleDay) _leaveSession = LeaveSession.fullDay;
    });
  }

  Future<void> _pickToDate() async {
    final initialFrom = _fromDate ?? leaveEarliestAllowedDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? initialFrom,
      firstDate: initialFrom,
      lastDate: leaveLatestAllowedDate(),
      helpText: 'To date (IST)',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _toDate = picked;
      if (_fromDate == null || _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
      if (!_isSingleDay) _leaveSession = LeaveSession.fullDay;
    });
  }

  Future<void> _submit(_ApplyLeaveData data) async {
    final departmentId = _selectedDepartmentId;
    final approverId = _selectedApproverId;
    final fromDate = _fromDate;
    final toDate = _toDate;

    if (departmentId == null || departmentId.isEmpty) {
      _showError('Select a department.');
      return;
    }
    if (approverId == null || approverId.isEmpty) {
      _showError('Select a nominated approver.');
      return;
    }
    if (fromDate == null || toDate == null) {
      _showError('Select leave dates.');
      return;
    }

    final validationError = validateLeaveDateRange(
      fromDate: fromDate,
      toDate: toDate,
      session: _leaveSession,
    );
    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.applyLeave(
        body: ApplyLeaveRequest(
          departmentId: departmentId,
          nominatedApproverAppUserId: approverId,
          fromDate: formatLeaveDateForApi(fromDate),
          toDate: formatLeaveDateForApi(toDate),
          leaveSession: _leaveSession,
          comment: _commentController.text,
        ),
      );
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handlePopRequested());
      },
      child: Theme(
        data: AppTheme.withCompactButtons(Theme.of(context)),
        child: AppScreenScaffold(
          appBar: AppBar(title: const Text('Apply for leave')),
          body: SafeArea(
            child: FutureBuilder<_ApplyLeaveData>(
              future: _dataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return AppLoadErrorState(
                    title: 'Failed to load leave form',
                    message: snapshot.error.toString(),
                    onRetry: _refreshData,
                    onLoginAgain: widget.onLoginAgain,
                  );
                }

                final data = snapshot.data ?? const _ApplyLeaveData.empty();
                if (data.myDepartments.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'You must belong to at least one department before '
                        'applying for leave. Contact your administrator.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }

                final approvers = _approverOptions(data);
                final noLeads =
                    _selectedDepartmentId != null && approvers.isEmpty;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Department',
                            ),
                            items: data.myDepartments
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
                                    _selectedApproverId = null;
                                  }),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedApproverId,
                            decoration: const InputDecoration(
                              labelText: 'Nominated approver',
                            ),
                            items: approvers
                                .map(
                                  (user) => DropdownMenuItem(
                                    value: user.id,
                                    child: Text(user.personName),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting || noLeads
                                ? null
                                : (value) =>
                                      setState(() => _selectedApproverId = value),
                          ),
                          if (noLeads) ...[
                            const SizedBox(height: 8),
                            Text(
                              'This department has no active department lead. '
                              'Leave cannot be submitted.',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : _pickFromDate,
                                  child: Text(
                                    _fromDate == null
                                        ? 'From date'
                                        : formatLeaveDate(_fromDate!),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _isSubmitting ? null : _pickToDate,
                                  child: Text(
                                    _toDate == null
                                        ? 'To date'
                                        : formatLeaveDate(_toDate!),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Allowed window: ${formatLeaveDate(leaveEarliestAllowedDate())} '
                            'to ${formatLeaveDate(leaveLatestAllowedDate())} (IST)',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<LeaveSession>(
                            initialValue: _leaveSession,
                            decoration: const InputDecoration(
                              labelText: 'Session',
                            ),
                            items: (_isSingleDay
                                    ? LeaveSession.values
                                    : [LeaveSession.fullDay])
                                .map(
                                  (session) => DropdownMenuItem(
                                    value: session,
                                    child: Text(session.label),
                                  ),
                                )
                                .toList(),
                            onChanged: _isSubmitting || !_isSingleDay
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => _leaveSession = value);
                                  },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentController,
                            enabled: !_isSubmitting,
                            maxLines: 4,
                            minLines: 3,
                            maxLength: 500,
                            decoration: const InputDecoration(
                              labelText: 'Comment (optional)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isSubmitting || noLeads
                                ? null
                                : () => _submit(data),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Submit leave request'),
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

class _ApplyLeaveData {
  const _ApplyLeaveData({
    required this.userId,
    required this.myDepartments,
  });

  const _ApplyLeaveData.empty()
    : userId = '',
      myDepartments = const [];

  final String userId;
  final List<Department> myDepartments;
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import '../departments/department_models.dart';
import 'apply_leave_screen.dart';
import 'leave_helpers.dart';
import 'leave_models.dart';
import 'widgets/leave_detail_sheet.dart';
import 'widgets/leave_status_chip.dart';

enum _LeaveTab { myLeaves, approvals, report }

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    this.initialLeaveId,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final int? initialLeaveId;

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _loader = AppAsyncListLoader<_LeaveScreenData>();
  TabController? _tabController;
  int _tabControllerLength = 0;
  String _searchQuery = '';
  bool _pendingOnly = true;
  String? _reportDepartmentId;
  bool _openedInitialLeave = false;

  @override
  void initState() {
    super.initState();
    _loader.initialize(_loadData);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  Future<_LeaveScreenData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getDepartments(),
      JwtPayload.currentUserId(),
      JwtPayload.currentUserIsAppAdmin(),
    ]);
    final departments = results[0] as List<Department>;
    final userId = (results[1] as String?)?.trim() ?? '';
    final isAppAdmin = results[2] as bool;
    final leadDepartmentIds = departmentIdsLedByUser(departments, userId);
    final isDepartmentLead = leadDepartmentIds.isNotEmpty;
    final myDepartments = departmentsForUser(departments, userId);

    final myLeavesResponse = await widget.apiClient.getMyLeaveRequests();
    LeaveListResponse? approvalResponse;
    if (isDepartmentLead) {
      approvalResponse = await widget.apiClient.getLeaveApprovalQueue();
    }

    LeaveListResponse? reportResponse;
    if (isAppAdmin || isDepartmentLead) {
      try {
        reportResponse = await widget.apiClient.getLeaveReport();
      } catch (_) {
        reportResponse = LeaveListResponse.fromJson(const {
          'success': true,
          'message': '',
          'leaves': [],
          'totalLeaves': 0,
        });
      }
    }

    return _LeaveScreenData(
      userId: userId,
      departments: departments,
      myDepartments: myDepartments,
      isAppAdmin: isAppAdmin,
      isDepartmentLead: isDepartmentLead,
      leadDepartmentIds: leadDepartmentIds,
      myLeaves: myLeavesResponse.leaves,
      approvalLeaves: approvalResponse?.leaves ?? const [],
      reportLeaves: reportResponse?.leaves ?? const [],
      canViewReport: isAppAdmin || isDepartmentLead,
    );
  }

  Future<void> _refresh() {
    return _loader.reload(load: _loadData, setState: setState);
  }

  void _ensureTabController(int length) {
    if (length <= 0) length = 1;
    if (_tabController != null && _tabControllerLength == length) return;
    _tabController?.dispose();
    _tabControllerLength = length;
    _tabController = TabController(length: length, vsync: this)
      ..addListener(() {
        if (_tabController!.indexIsChanging) return;
        setState(() {});
      });
  }

  List<_LeaveTab> _visibleTabs(_LeaveScreenData data) {
    return [
      _LeaveTab.myLeaves,
      if (data.isDepartmentLead) _LeaveTab.approvals,
      if (data.canViewReport) _LeaveTab.report,
    ];
  }

  String _tabLabel(_LeaveTab tab) => switch (tab) {
    _LeaveTab.myLeaves => 'My leaves',
    _LeaveTab.approvals => 'Approvals',
    _LeaveTab.report => 'Report',
  };

  List<LeaveRequest> _leavesForCurrentTab(_LeaveScreenData data) {
    final tabs = _visibleTabs(data);
    final controller = _tabController;
    if (controller == null || tabs.isEmpty) return const [];
    final tab = tabs[controller.index];

    final leaves = switch (tab) {
      _LeaveTab.myLeaves => data.myLeaves,
      _LeaveTab.approvals => data.approvalLeaves,
      _LeaveTab.report => _filteredReportLeaves(data),
    };

    var filtered = leaves.where((leave) => leave.matchesSearch(_searchQuery));
    if (tab == _LeaveTab.approvals && _pendingOnly) {
      filtered = filtered.where((leave) => leave.status.isPending);
    }
    return filtered.toList();
  }

  List<LeaveRequest> _filteredReportLeaves(_LeaveScreenData data) {
    final departmentId = _reportDepartmentId;
    if (departmentId == null || departmentId.isEmpty) {
      return data.reportLeaves;
    }
    return data.reportLeaves
        .where((leave) => leave.departmentId == departmentId)
        .toList();
  }

  List<Department> _reportDepartments(_LeaveScreenData data) {
    if (data.isAppAdmin) {
      return data.departments.where((department) => department.isActive).toList();
    }
    return data.departments
        .where((department) => data.leadDepartmentIds.contains(department.id))
        .toList();
  }

  Future<void> _openApplyLeave(_LeaveScreenData data) async {
    if (data.myDepartments.isEmpty) {
      showAppSnackBar(
        context,
        message:
            'You must belong to at least one department before applying '
            'for leave. Contact your administrator.',
        type: AppSnackBarType.error,
      );
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ApplyLeaveScreen(
          apiClient: widget.apiClient,
          onLoginAgain: widget.onLoginAgain,
          departments: data.departments,
          userId: data.userId,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _refresh();
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Leave request submitted.',
        type: AppSnackBarType.success,
      );
    }
  }

  Future<void> _openLeaveDetail(
    _LeaveScreenData data,
    LeaveRequest leave,
  ) async {
    final changed = await showLeaveDetailSheet(
      context: context,
      apiClient: widget.apiClient,
      leave: leave,
      currentUserId: data.userId,
      leadDepartmentIds: data.leadDepartmentIds,
      onLoginAgain: widget.onLoginAgain,
      onChanged: _refresh,
    );
    if (changed == true && mounted) {
      await _refresh();
    }
  }

  void _maybeOpenInitialLeave(_LeaveScreenData data) {
    final leaveId = widget.initialLeaveId;
    if (_openedInitialLeave || leaveId == null) return;
    _openedInitialLeave = true;

    LeaveRequest? leave;
    for (final candidate in [
      ...data.myLeaves,
      ...data.approvalLeaves,
      ...data.reportLeaves,
    ]) {
      if (candidate.leaveId == leaveId) {
        leave = candidate;
        break;
      }
    }
    if (leave == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openLeaveDetail(data, leave!));
    });
  }

  Future<void> _downloadReport(_LeaveScreenData data) async {
    try {
      final leaves = _filteredReportLeaves(data);
      final fileName =
          'mpc-pharma-leave-report-${DateTime.now().millisecondsSinceEpoch}.csv';
      await downloadFile(
        fileName: fileName,
        bytes: utf8.encode(leavesToCsv(leaves)),
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Leave Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<_LeaveScreenData>(
        future: _loader.future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _openApplyLeave(data),
            icon: const Icon(Icons.add),
            label: const Text('Apply leave'),
          );
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: FutureBuilder<_LeaveScreenData>(
                key: ValueKey(_loader.refreshToken),
                future: _loader.future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AppLoadErrorState(
                      title: 'Failed to load leave requests',
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                      onLoginAgain: widget.onLoginAgain,
                    );
                  }

                  final data = snapshot.data ?? const _LeaveScreenData.empty();
                  final tabs = _visibleTabs(data);
                  _ensureTabController(tabs.length);
                  _maybeOpenInitialLeave(data);
                  final currentTab = tabs[_tabController!.index];
                  final leaves = _leavesForCurrentTab(data);
                  final primary = Theme.of(context).colorScheme.primary;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchField(
                        controller: _searchController,
                        labelText: 'Search leave requests',
                        hintText: 'Requester, department, dates, status…',
                      ),
                      if (tabs.length > 1) ...[
                        const SizedBox(height: 16),
                        _LeaveTabBar(
                          controller: _tabController!,
                          labels: tabs.map(_tabLabel).toList(),
                          primary: primary,
                        ),
                      ],
                      if (currentTab == _LeaveTab.approvals) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _LeaveApprovalFilterChip(
                                label: 'Pending only',
                                selected: _pendingOnly,
                                primary: primary,
                                onTap: () =>
                                    setState(() => _pendingOnly = true),
                              ),
                              _LeaveApprovalFilterChip(
                                label: 'All Requests',
                                selected: !_pendingOnly,
                                primary: primary,
                                onTap: () =>
                                    setState(() => _pendingOnly = false),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (currentTab == _LeaveTab.report) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _reportDepartmentId,
                                decoration: const InputDecoration(
                                  labelText: 'Department filter',
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All departments'),
                                  ),
                                  ..._reportDepartments(data).map(
                                    (department) => DropdownMenuItem<String?>(
                                      value: department.id,
                                      child: Text(department.name),
                                    ),
                                  ),
                                ],
                                onChanged: (value) => setState(
                                  () => _reportDepartmentId = value,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => _downloadReport(data),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Export'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Expanded(
                        child: leaves.isEmpty
                            ? Center(
                                child: Text(
                                  switch (currentTab) {
                                    _LeaveTab.myLeaves =>
                                      'You have not applied for leave yet.',
                                    _LeaveTab.approvals =>
                                      _pendingOnly
                                          ? 'No pending leave requests to review.'
                                          : 'No leave requests in the approval queue.',
                                    _LeaveTab.report =>
                                      'No leave records found for the report.',
                                  },
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              )
                            : AppScrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  controller: _scrollController,
                                  itemCount: leaves.length,
                                  itemBuilder: (context, index) {
                                    final leave = leaves[index];
                                    return _LeaveRequestCard(
                                      leave: leave,
                                      showRequester:
                                          currentTab != _LeaveTab.myLeaves,
                                      onTap: () => _openLeaveDetail(data, leave),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveScreenData {
  const _LeaveScreenData({
    required this.userId,
    required this.departments,
    required this.myDepartments,
    required this.isAppAdmin,
    required this.isDepartmentLead,
    required this.leadDepartmentIds,
    required this.myLeaves,
    required this.approvalLeaves,
    required this.reportLeaves,
    required this.canViewReport,
  });

  const _LeaveScreenData.empty()
    : userId = '',
      departments = const [],
      myDepartments = const [],
      isAppAdmin = false,
      isDepartmentLead = false,
      leadDepartmentIds = const {},
      myLeaves = const [],
      approvalLeaves = const [],
      reportLeaves = const [],
      canViewReport = false;

  final String userId;
  final List<Department> departments;
  final List<Department> myDepartments;
  final bool isAppAdmin;
  final bool isDepartmentLead;
  final Set<String> leadDepartmentIds;
  final List<LeaveRequest> myLeaves;
  final List<LeaveRequest> approvalLeaves;
  final List<LeaveRequest> reportLeaves;
  final bool canViewReport;
}

class _LeaveRequestCard extends StatelessWidget {
  const _LeaveRequestCard({
    required this.leave,
    required this.showRequester,
    required this.onTap,
  });

  final LeaveRequest leave;
  final bool showRequester;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AppSurface(
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
                        leave.dateRangeLabel,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    LeaveStatusChip(status: leave.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  leave.leaveSession.label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  leave.departmentName,
                  style: const TextStyle(color: Colors.black54),
                ),
                if (showRequester) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Requester: ${leave.requesterName}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                if (leave.requestComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    leave.requestComment,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaveApprovalFilterChip extends StatelessWidget {
  const _LeaveApprovalFilterChip({
    required this.label,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? primary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? primary : primary.withValues(alpha: 0.45),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaveTabBar extends StatelessWidget {
  const _LeaveTabBar({
    required this.controller,
    required this.labels,
    required this.primary,
  });

  final TabController controller;
  final List<String> labels;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
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
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tabs: [for (final label in labels) Tab(height: 36, text: label)],
    );
  }
}

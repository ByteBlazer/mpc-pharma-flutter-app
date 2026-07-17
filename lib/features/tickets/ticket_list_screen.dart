import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../departments/department_models.dart';
import 'ticket_detail_screen.dart';
import 'ticket_models.dart';
import 'widgets/ticket_status_chip.dart';

enum _EmployeeTicketTab {
  assignedToMe,
  raisedByMe,
  myDepartment,
  all,
  custom,
}

enum _CustomFilterBy {
  assignedToMe,
  raisedByMe,
  myDepartment,
  all;

  String get label => switch (this) {
    _CustomFilterBy.assignedToMe => 'Assigned to me',
    _CustomFilterBy.raisedByMe => 'Raised by me',
    _CustomFilterBy.myDepartment => 'My department',
    _CustomFilterBy.all => 'All tickets',
  };

  _EmployeeTicketTab get scopeTab => switch (this) {
    _CustomFilterBy.assignedToMe => _EmployeeTicketTab.assignedToMe,
    _CustomFilterBy.raisedByMe => _EmployeeTicketTab.raisedByMe,
    _CustomFilterBy.myDepartment => _EmployeeTicketTab.myDepartment,
    _CustomFilterBy.all => _EmployeeTicketTab.all,
  };

  static _CustomFilterBy fromStorage(String? value) {
    return _CustomFilterBy.values.firstWhere(
      (item) => item.name == value,
      orElse: () => _CustomFilterBy.all,
    );
  }
}

enum _CustomOpenForMoreThan {
  oneDay(1, 'More than 1 day'),
  twoDays(2, 'More than 2 days'),
  threeDays(3, 'More than 3 days'),
  fourDays(4, 'More than 4 days'),
  fivePlus(5, '5+ days');

  const _CustomOpenForMoreThan(this.days, this.label);

  final int days;
  final String label;

  /// `fivePlus` means open for 5 or more days; others mean strictly more than N days.
  bool matchesAge(Duration age) {
    if (this == _CustomOpenForMoreThan.fivePlus) {
      return age.inDays >= days;
    }
    return age > Duration(days: days);
  }

  static _CustomOpenForMoreThan fromStorage(String? value) {
    if (value == 'fiveDays') return _CustomOpenForMoreThan.fivePlus;
    return _CustomOpenForMoreThan.values.firstWhere(
      (item) => item.name == value,
      orElse: () => _CustomOpenForMoreThan.oneDay,
    );
  }
}

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    required this.isEmployeeView,
    required this.title,
    required this.onCreate,
    this.createLabel,
    this.createSuccessMessage,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final bool isEmployeeView;
  final String title;
  final Future<bool> Function() onCreate;
  final String? createLabel;
  final String? createSuccessMessage;

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen>
    with SingleTickerProviderStateMixin {
  static const _customFilterByPrefsKey = 'ticket_list_custom_filter_by';
  static const _customOpenForPrefsKey = 'ticket_list_custom_open_for';
  static const _lastTabPrefsKey = 'ticket_list_last_tab';

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _loader = AppAsyncListLoader<_TicketListData>();
  TabController? _tabController;
  String _searchQuery = '';
  _TicketListData _listData = const _TicketListData.empty();
  _CustomFilterBy _customFilterBy = _CustomFilterBy.all;
  _CustomOpenForMoreThan _customOpenFor = _CustomOpenForMoreThan.oneDay;

  @override
  void initState() {
    super.initState();
    if (widget.isEmployeeView) {
      _tabController = TabController(
        length: _EmployeeTicketTab.values.length,
        vsync: this,
      );
      _tabController!.addListener(_onTabChanged);
      _loadEmployeeListPrefs();
    }
    _loader.initialize(_loadData);
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadEmployeeListPrefs() async {
    final preferences = await SharedPreferences.getInstance();
    final filterBy = _CustomFilterBy.fromStorage(
      preferences.getString(_customFilterByPrefsKey),
    );
    final openFor = _CustomOpenForMoreThan.fromStorage(
      preferences.getString(_customOpenForPrefsKey),
    );
    final lastTab = _EmployeeTicketTab.values.firstWhere(
      (tab) => tab.name == preferences.getString(_lastTabPrefsKey),
      orElse: () => _EmployeeTicketTab.assignedToMe,
    );
    if (!mounted) return;
    setState(() {
      _customFilterBy = filterBy;
      _customOpenFor = openFor;
    });
    final controller = _tabController;
    if (controller == null) return;
    if (controller.index != lastTab.index) {
      controller.index = lastTab.index;
    } else if (lastTab == _EmployeeTicketTab.custom) {
      _clearSearch();
    }
  }

  Future<void> _persistCustomFilterPrefs() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customFilterByPrefsKey, _customFilterBy.name);
    await preferences.setString(_customOpenForPrefsKey, _customOpenFor.name);
  }

  Future<void> _persistLastTab() async {
    final controller = _tabController;
    if (controller == null) return;
    final tab = _EmployeeTicketTab.values[controller.index];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastTabPrefsKey, tab.name);
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) return;
    _searchQuery = '';
    _searchController.clear();
  }

  void _onCustomFilterByChanged(_CustomFilterBy? value) {
    if (value == null || value == _customFilterBy) return;
    setState(() => _customFilterBy = value);
    _persistCustomFilterPrefs();
  }

  void _onCustomOpenForChanged(_CustomOpenForMoreThan? value) {
    if (value == null || value == _customOpenFor) return;
    setState(() => _customOpenFor = value);
    _persistCustomFilterPrefs();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    final tab = _EmployeeTicketTab.values[_tabController!.index];
    if (tab == _EmployeeTicketTab.custom) {
      _clearSearch();
    }
    setState(() {});
    _persistLastTab();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text);
  }

  Future<_TicketListData> _loadData() async {
    final tickets = await widget.apiClient.getTickets();
    if (!widget.isEmployeeView) {
      return _TicketListData(tickets: tickets);
    }

    final results = await Future.wait([
      widget.apiClient.getDepartments(),
      JwtPayload.currentUserId(),
    ]);
    final departments = results[0] as List<Department>;
    final userId = (results[1] as String?)?.trim() ?? '';
    final myDepartmentIds = <String>{
      for (final department in departments)
        if (userId.isNotEmpty &&
            department.users.any((user) => user.id == userId))
          department.id,
    };
    return _TicketListData(
      tickets: tickets,
      currentUserId: userId,
      myDepartmentIds: myDepartmentIds,
    );
  }

  Future<void> _refresh() {
    return _loader.reload(load: _loadData, setState: setState);
  }

  Future<void> _handleCreate() async {
    final saved = await widget.onCreate();
    if (!mounted || saved != true) return;
    final message = widget.createSuccessMessage;
    if (message != null) {
      showAppSnackBar(context, message: message, type: AppSnackBarType.success);
    }
    await _refresh();
  }

  bool _belongsToTab({
    required TicketSummary ticket,
    required _EmployeeTicketTab tab,
    required _TicketListData data,
  }) {
    final userId = data.currentUserId.trim();
    return switch (tab) {
      _EmployeeTicketTab.assignedToMe =>
        userId.isNotEmpty && ticket.assigneeAppUserId == userId,
      _EmployeeTicketTab.raisedByMe =>
        userId.isNotEmpty && ticket.createdBy == userId,
      _EmployeeTicketTab.myDepartment =>
        ticket.assignedDepartmentId.isNotEmpty &&
            data.myDepartmentIds.contains(ticket.assignedDepartmentId),
      _EmployeeTicketTab.all => true,
      _EmployeeTicketTab.custom =>
        _belongsToTab(
              ticket: ticket,
              tab: _customFilterBy.scopeTab,
              data: data,
            ) &&
            _matchesCustomOpenFor(ticket),
    };
  }

  bool _isStillOpen(TicketStatus status) {
    return switch (status) {
      TicketStatus.open ||
      TicketStatus.assigned ||
      TicketStatus.inProgress =>
        true,
      TicketStatus.resolved ||
      TicketStatus.invalid ||
      TicketStatus.closed =>
        false,
    };
  }

  bool _matchesCustomOpenFor(TicketSummary ticket) {
    if (!_isStillOpen(ticket.status)) return false;
    final createdAt = ticket.createdAt;
    if (createdAt == null) return false;
    final age = DateTime.now().difference(createdAt);
    return _customOpenFor.matchesAge(age);
  }

  List<TicketSummary> _visibleTickets(_TicketListData data) {
    final searched = data.tickets
        .where((ticket) => ticket.matchesSearch(_searchQuery))
        .toList();
    if (!widget.isEmployeeView || _tabController == null) {
      return searched;
    }
    final tab = _EmployeeTicketTab.values[_tabController!.index];
    return searched
        .where(
          (ticket) => _belongsToTab(ticket: ticket, tab: tab, data: data),
        )
        .toList();
  }

  int _tabCount(_EmployeeTicketTab tab, _TicketListData data) {
    return data.tickets
        .where((ticket) => _belongsToTab(ticket: ticket, tab: tab, data: data))
        .length;
  }

  String _tabTitle(_EmployeeTicketTab tab) {
    return switch (tab) {
      _EmployeeTicketTab.assignedToMe => 'Assigned to me',
      _EmployeeTicketTab.raisedByMe => 'Raised by me',
      _EmployeeTicketTab.myDepartment => 'My department',
      _EmployeeTicketTab.all => 'All tickets',
      _EmployeeTicketTab.custom => 'Custom',
    };
  }

  String _tabLabel(_EmployeeTicketTab tab, _TicketListData data) {
    return '${_tabTitle(tab)} (${_tabCount(tab, data)})';
  }

  Future<void> _openTicket(TicketSummary ticket) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(
          apiClient: widget.apiClient,
          ticketId: ticket.id,
          isEmployeeView: widget.isEmployeeView,
          onLoginAgain: widget.onLoginAgain,
        ),
      ),
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(title: Text(widget.title)),
        floatingActionButton: widget.createLabel == null
            ? null
            : FloatingActionButton.extended(
                onPressed: _handleCreate,
                icon: const Icon(Icons.add),
                label: Text(widget.createLabel!),
              ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSearchField(
                      controller: _searchController,
                      labelText: widget.isEmployeeView
                          ? 'Search tickets'
                          : 'Search complaints',
                      hintText: 'Ticket #, subject, status...',
                    ),
                    if (widget.isEmployeeView && _tabController != null) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<_TicketListData>(
                        key: ValueKey('tabs-${_loader.refreshToken}'),
                        future: _loader.future,
                        builder: (context, snapshot) {
                          final data = snapshot.data ?? _listData;
                          return _EmployeeTicketTabSelector(
                            controller: _tabController!,
                            primary: primary,
                            labels: [
                              for (final tab in _EmployeeTicketTab.values)
                                _tabLabel(tab, data),
                            ],
                          );
                        },
                      ),
                      AnimatedBuilder(
                        animation: _tabController!,
                        builder: (context, _) {
                          final isCustom =
                              _EmployeeTicketTab.values[_tabController!.index] ==
                              _EmployeeTicketTab.custom;
                          if (!isCustom) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _CustomTicketFilterForm(
                              filterBy: _customFilterBy,
                              openFor: _customOpenFor,
                              onFilterByChanged: _onCustomFilterByChanged,
                              onOpenForChanged: _onCustomOpenForChanged,
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<_TicketListData>(
                        key: ValueKey(_loader.refreshToken),
                        future: _loader.future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return AppLoadErrorState(
                              title: widget.isEmployeeView
                                  ? 'Failed to load Tickets'
                                  : 'Failed to load Complaints',
                              message: snapshot.error.toString(),
                              onRetry: _refresh,
                              onLoginAgain: widget.onLoginAgain,
                            );
                          }

                          final data =
                              snapshot.data ?? const _TicketListData.empty();
                          _listData = data;

                          final tickets = _visibleTickets(data);
                          if (tickets.isEmpty) {
                            return _TicketListMessage(
                              message: _emptyMessage(),
                            );
                          }
                          if (!widget.isEmployeeView) {
                            return _CustomerComplaintList(
                              tickets: tickets,
                              scrollController: _scrollController,
                              onOpenTicket: (ticket) => _openTicket(ticket),
                            );
                          }
                          return AppScrollbar(
                            controller: _scrollController,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(right: 20),
                              itemCount: tickets.length,
                              itemBuilder: (context, index) {
                                final ticket = tickets[index];
                                return _TicketSummaryCard(
                                  ticket: ticket,
                                  isEmployeeView: true,
                                  onTap: () => _openTicket(ticket),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _emptyMessage() {
    if (!widget.isEmployeeView) {
      return 'No complaints found for the last 90 days.';
    }
    final tab = _EmployeeTicketTab.values[_tabController?.index ?? 0];
    if (_searchQuery.trim().isNotEmpty) {
      final tabName = _tabTitle(tab);
      if (tab == _EmployeeTicketTab.all) {
        return 'No matches in the $tabName tab. Try clearing your search or using different keywords.';
      }
      return 'No matches in the $tabName tab. Try another tab, or check All tickets.';
    }
    return switch (tab) {
      _EmployeeTicketTab.assignedToMe => 'No tickets assigned to you.',
      _EmployeeTicketTab.raisedByMe => 'You have not raised any tickets.',
      _EmployeeTicketTab.myDepartment =>
        'No tickets in your department(s).',
      _EmployeeTicketTab.all => 'No tickets found for the last 90 days.',
      _EmployeeTicketTab.custom =>
        'No open tickets match your custom filters.',
    };
  }
}

class _TicketListData {
  const _TicketListData({
    required this.tickets,
    this.currentUserId = '',
    this.myDepartmentIds = const {},
  });

  const _TicketListData.empty()
      : tickets = const [],
        currentUserId = '',
        myDepartmentIds = const {};

  final List<TicketSummary> tickets;
  final String currentUserId;
  final Set<String> myDepartmentIds;
}

class _CustomTicketFilterForm extends StatelessWidget {
  const _CustomTicketFilterForm({
    required this.filterBy,
    required this.openFor,
    required this.onFilterByChanged,
    required this.onOpenForChanged,
  });

  final _CustomFilterBy filterBy;
  final _CustomOpenForMoreThan openFor;
  final ValueChanged<_CustomFilterBy?> onFilterByChanged;
  final ValueChanged<_CustomOpenForMoreThan?> onOpenForChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= 560;
        final filterField = DropdownButtonFormField<_CustomFilterBy>(
          key: ValueKey('custom-filter-by-${filterBy.name}'),
          initialValue: filterBy,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Filter by'),
          items: [
            for (final option in _CustomFilterBy.values)
              DropdownMenuItem(
                value: option,
                child: Text(option.label),
              ),
          ],
          onChanged: onFilterByChanged,
        );
        final openForField = DropdownButtonFormField<_CustomOpenForMoreThan>(
          key: ValueKey('custom-open-for-${openFor.name}'),
          initialValue: openFor,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Open for'),
          items: [
            for (final option in _CustomOpenForMoreThan.values)
              DropdownMenuItem(
                value: option,
                child: Text(option.label),
              ),
          ],
          onChanged: onOpenForChanged,
        );

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: filterField),
              const SizedBox(width: 12),
              Expanded(child: openForField),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            filterField,
            const SizedBox(height: 12),
            openForField,
          ],
        );
      },
    );
  }
}

class _EmployeeTicketTabSelector extends StatelessWidget {
  const _EmployeeTicketTabSelector({
    required this.controller,
    required this.primary,
    required this.labels,
  });

  final TabController controller;
  final Color primary;
  final List<String> labels;

  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= _wideBreakpoint;
            if (isWide) {
              return SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
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
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
                    splashFactory: NoSplash.splashFactory,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
                    tabs: [
                      for (final label in labels)
                        Tab(height: 36, text: label),
                    ],
                  ),
                ),
              );
            }

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < labels.length; index++)
                  _EmployeeTicketTabChip(
                    label: labels[index],
                    selected: controller.index == index,
                    primary: primary,
                    onTap: () => controller.animateTo(index),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EmployeeTicketTabChip extends StatelessWidget {
  const _EmployeeTicketTabChip({
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
      color: selected ? primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? primary : Colors.black26,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black54,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerComplaintList extends StatelessWidget {
  const _CustomerComplaintList({
    required this.tickets,
    required this.scrollController,
    required this.onOpenTicket,
  });

  final List<TicketSummary> tickets;
  final ScrollController scrollController;
  final ValueChanged<TicketSummary> onOpenTicket;

  @override
  Widget build(BuildContext context) {
    final myComplaints = tickets
        .where((ticket) => ticket.isRaisedByCustomer)
        .toList();
    final companyRaised = tickets
        .where((ticket) => !ticket.isRaisedByCustomer)
        .toList();

    return AppScrollbar(
      controller: scrollController,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(right: 20),
        children: [
          _ComplaintSection(
            title: 'My complaints',
            emptyMessage: 'You have not raised any complaints yet.',
            tickets: myComplaints,
            onOpenTicket: onOpenTicket,
          ),
          const SizedBox(height: 8),
          _ComplaintSection(
            title: 'Raised by Service Desk on your behalf',
            emptyMessage: 'No company-raised complaints yet.',
            tickets: companyRaised,
            onOpenTicket: onOpenTicket,
          ),
        ],
      ),
    );
  }
}

class _ComplaintSection extends StatelessWidget {
  const _ComplaintSection({
    required this.title,
    required this.emptyMessage,
    required this.tickets,
    required this.onOpenTicket,
  });

  final String title;
  final String emptyMessage;
  final List<TicketSummary> tickets;
  final ValueChanged<TicketSummary> onOpenTicket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        if (tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyMessage,
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          ...tickets.map(
            (ticket) => _TicketSummaryCard(
              ticket: ticket,
              isEmployeeView: false,
              onTap: () => onOpenTicket(ticket),
            ),
          ),
      ],
    );
  }
}

class _TicketSummaryCard extends StatelessWidget {
  const _TicketSummaryCard({
    required this.ticket,
    required this.isEmployeeView,
    required this.onTap,
  });

  final TicketSummary ticket;
  final bool isEmployeeView;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isHighPriority = ticket.priority == TicketPriority.high;
    final partyLabel = ticket.isCustomerTicket ? 'Customer' : 'Raised by';
    final partyName = ticket.isCustomerTicket
        ? ticket.customerFirmName.trim()
        : ticket.createdByName.trim();
    final assigneeName = ticket.assigneeName.trim();
    final departmentName = ticket.assignedDepartmentName.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                        '#${ticket.id} · ${ticket.subject.trim().isEmpty ? '—' : ticket.subject}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isHighPriority) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'High priority',
                        child: Icon(
                          Icons.priority_high_rounded,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    TicketStatusChip(status: ticket.status),
                  ],
                ),
                if (isEmployeeView) ...[
                  if (partyName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TicketCardMetaRow(
                      icon: ticket.isCustomerTicket
                          ? Icons.storefront_outlined
                          : Icons.person_outline,
                      label: partyLabel,
                      value: partyName,
                      color: primary,
                    ),
                  ],
                  if (assigneeName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _TicketCardMetaRow(
                      icon: Icons.badge_outlined,
                      label: 'Assignee',
                      value: assigneeName,
                      color: primary,
                    ),
                  ],
                  if (departmentName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _TicketCardMetaRow(
                      icon: Icons.apartment_outlined,
                      label: 'Dept',
                      value: departmentName,
                      color: primary,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketCardMetaRow extends StatelessWidget {
  const _TicketCardMetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label · ',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TicketListMessage extends StatelessWidget {
  const _TicketListMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}

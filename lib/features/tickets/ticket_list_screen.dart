import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import 'ticket_detail_screen.dart';
import 'ticket_models.dart';
import 'widgets/ticket_status_chip.dart';

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

class _TicketListScreenState extends State<TicketListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _loader = AppAsyncListLoader<List<TicketSummary>>();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loader.initialize(() => widget.apiClient.getTickets());
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return _loader.reload(
      load: () => widget.apiClient.getTickets(),
      setState: setState,
    );
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

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<TicketSummary>>(
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
                            return _TicketListMessage(
                              message: snapshot.error.toString(),
                              actionLabel: 'Retry',
                              onAction: _refresh,
                            );
                          }
                          final tickets =
                              (snapshot.data ?? const <TicketSummary>[])
                                  .where(
                                    (ticket) =>
                                        ticket.matchesSearch(_searchQuery),
                                  )
                                  .toList();
                          if (tickets.isEmpty) {
                            return _TicketListMessage(
                              message: widget.isEmployeeView
                                  ? 'No tickets found for the last 90 days.'
                                  : 'No complaints found for the last 90 days.',
                            );
                          }
                          if (!widget.isEmployeeView) {
                            return _CustomerComplaintList(
                              tickets: tickets,
                              scrollController: _scrollController,
                              onOpenTicket: (ticket) async {
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
                              },
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
                                  isEmployeeView: widget.isEmployeeView,
                                  onTap: () async {
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
                                  },
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
  const _TicketListMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

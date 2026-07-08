import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_scrollbar.dart';
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
    this.appBarActions,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final bool isEmployeeView;
  final String title;
  final Future<bool> Function() onCreate;
  final String? createLabel;
  final String? createSuccessMessage;
  final List<Widget>? appBarActions;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.appBarActions,
      ),
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
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return _TicketListMessage(
                            message: snapshot.error.toString(),
                            actionLabel: 'Retry',
                            onAction: _refresh,
                          );
                        }
                        final tickets = (snapshot.data ?? const <TicketSummary>[])
                            .where((ticket) => ticket.matchesSearch(_searchQuery))
                            .toList();
                        if (tickets.isEmpty) {
                          return _TicketListMessage(
                            message: widget.isEmployeeView
                                ? 'No tickets found for the last 90 days.'
                                : 'No complaints found for the last 90 days.',
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.primary),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '#${ticket.id} · ${ticket.subject}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TicketStatusChip(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 8),
                if (isEmployeeView)
                  Text(
                    '${ticket.priority.label} · ${ticket.ticketType.apiValue.replaceAll('_', ' ')}',
                    style: const TextStyle(color: Colors.black),
                  ),
                if (isEmployeeView &&
                    (ticket.assignedDepartmentName.isNotEmpty ||
                        ticket.assigneeName.isNotEmpty))
                  Text(
                    '${ticket.assignedDepartmentName} · ${ticket.assigneeName}',
                    style: const TextStyle(color: Colors.black),
                  ),
                if (isEmployeeView && ticket.customerFirmName.isNotEmpty)
                  Text(
                    ticket.customerFirmName,
                    style: const TextStyle(color: Colors.black),
                  ),
              ],
            ),
          ),
        ),
      ),
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

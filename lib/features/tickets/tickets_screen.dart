import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import 'create_complaint_screen.dart';
import 'create_employee_ticket_screen.dart';
import 'ticket_list_screen.dart';
import 'ticket_models.dart';

class TicketsScreen extends StatelessWidget {
  const TicketsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  Future<bool> _openCreateMenu(BuildContext context) async {
    final selection = await showModalBottomSheet<TicketType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('On behalf of customer'),
              onTap: () =>
                  Navigator.of(context).pop(TicketType.raisedForCustomer),
            ),
            ListTile(
              leading: const Icon(Icons.business_center_outlined),
              title: const Text('Internal ticket'),
              onTap: () => Navigator.of(context).pop(TicketType.internal),
            ),
          ],
        ),
      ),
    );
    if (selection == null || !context.mounted) return false;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateEmployeeTicketScreen(
          apiClient: apiClient,
          ticketType: selection,
          onLoginAgain: onLoginAgain,
        ),
      ),
    );
    return saved == true;
  }

  @override
  Widget build(BuildContext context) {
    return TicketListScreen(
      apiClient: apiClient,
      onLoginAgain: onLoginAgain,
      isEmployeeView: true,
      title: 'Tickets',
      createLabel: 'New ticket',
      createSuccessMessage: 'Ticket created successfully.',
      onCreate: () => _openCreateMenu(context),
    );
  }
}

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  Widget build(BuildContext context) {
    return TicketListScreen(
      apiClient: apiClient,
      onLoginAgain: onLoginAgain,
      isEmployeeView: false,
      title: 'Complaints',
      createLabel: 'New complaint',
      createSuccessMessage: 'Complaint submitted successfully.',
      onCreate: () async {
        final saved = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => CreateComplaintScreen(
              apiClient: apiClient,
              onLoginAgain: onLoginAgain,
            ),
          ),
        );
        return saved == true;
      },
    );
  }
}

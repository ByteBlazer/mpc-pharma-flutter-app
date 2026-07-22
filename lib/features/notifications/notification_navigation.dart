import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
import '../leave_requests/leave_requests_screen.dart';
import '../tickets/ticket_detail_screen.dart';
import 'notification_models.dart';

Future<void> openNotificationTarget({
  required BuildContext context,
  required ApiClient apiClient,
  required Future<void> Function() onLoginAgain,
  required AppNotification notification,
}) async {
  final module = notification.module.trim().toUpperCase();
  final referenceId = notification.referenceId.trim();

  if (referenceId.isEmpty) return;

  if (module == 'TICKET') {
    try {
      await apiClient.getTicket(ticketId: referenceId, isEmployeeView: true);
    } catch (error) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: 'Unable to open ticket $referenceId.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(
          apiClient: apiClient,
          ticketId: referenceId,
          isEmployeeView: true,
          onLoginAgain: onLoginAgain,
        ),
      ),
    );
    return;
  }

  if (module == 'LEAVE') {
    final leaveId = int.tryParse(referenceId);
    if (leaveId == null) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        message: 'Unable to open leave request $referenceId.',
        type: AppSnackBarType.error,
      );
      return;
    }

    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LeaveRequestsScreen(
          apiClient: apiClient,
          onLoginAgain: onLoginAgain,
          initialLeaveId: leaveId,
        ),
      ),
    );
  }
}

String formatNotificationTimestamp(DateTime dateTime) {
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

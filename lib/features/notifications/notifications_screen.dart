import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'notification_inbox_controller.dart';
import 'notification_models.dart';
import 'notification_navigation.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    this.inboxController,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final NotificationInboxController? inboxController;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationInboxController _controller;
  late final bool _ownsController;
  final _scrollController = ScrollController();
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    final shared = widget.inboxController;
    if (shared != null) {
      _controller = shared;
      _ownsController = false;
      _controller.addListener(_onInboxChanged);
      _controller.refresh();
    } else {
      _controller = NotificationInboxController(widget.apiClient);
      _ownsController = true;
      _controller.addListener(_onInboxChanged);
      _controller.refresh();
    }
  }

  void _onInboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.removeListener(_onInboxChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      await _controller.markAllRead();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _openNotification(AppNotification notification) async {
    try {
      if (!notification.isRead) {
        await _controller.markRead(notification.id);
      }
      if (!mounted) return;
      await openNotificationTarget(
        context: context,
        apiClient: widget.apiClient,
        onLoginAgain: widget.onLoginAgain,
        notification: notification,
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
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _isMarkingAll ? null : _markAllRead,
                    child: _isMarkingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark all as read'),
                  ),
                ),
              ),
              Expanded(child: _buildBody(primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color primary) {
    if (_controller.isLoading && !_controller.hasLoadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.hasError && _controller.items.isEmpty) {
      return AppLoadErrorState(
        title: 'Failed to load notifications',
        message: _controller.error.toString(),
        onRetry: () => _controller.refresh(),
        onLoginAgain: widget.onLoginAgain,
      );
    }

    if (_controller.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'You don’t have any notifications.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      child: AppScrollbar(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(24),
          itemCount: _controller.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final notification = _controller.items[index];
            return _NotificationListTile(
              notification: notification,
              primary: primary,
              onTap: () => _openNotification(notification),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationListTile extends StatelessWidget {
  const _NotificationListTile({
    required this.notification,
    required this.primary,
    required this.onTap,
  });

  final AppNotification notification;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canOpen = notification.canNavigate;
    final unread = !notification.isRead;
    final timestamp = notification.createdAt == null
        ? ''
        : formatNotificationTimestamp(notification.createdAt!);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpen ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: AppSurface(
          borderRadius: 16,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread
                        ? primary
                        : Colors.black.withValues(alpha: 0.18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.message,
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      if (timestamp.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          timestamp,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (!canOpen) ...[
                        const SizedBox(height: 6),
                        Text(
                          'This notification type isn’t available to open yet.',
                          style: TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (canOpen)
                  Icon(
                    Icons.chevron_right,
                    color: primary.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

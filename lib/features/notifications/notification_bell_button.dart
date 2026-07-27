import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
import 'notification_inbox_controller.dart';
import 'notification_models.dart';
import 'notification_navigation.dart';
import 'notifications_screen.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    required this.controller,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final NotificationInboxController controller;

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton>
    with SingleTickerProviderStateMixin {
  final GlobalKey _buttonKey = GlobalKey();
  bool _isMarkingAll = false;
  late final AnimationController _ringController;
  late final Animation<double> _ringAngle;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    // Zoom in → strong shake → zoom out → rest.
    _ringScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 2.0).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 3,
      ),
      TweenSequenceItem(tween: ConstantTween(2.0), weight: 8),
      TweenSequenceItem(
        tween: Tween(begin: 2.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 3,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 14),
    ]).animate(_ringController);
    _ringAngle = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 3),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.38), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.38, end: -0.38), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.38, end: 0.30), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.30, end: -0.24), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.24, end: 0.0), weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 17),
    ]).animate(_ringController);
    _syncRingAnimation();
  }

  @override
  void didUpdateWidget(covariant NotificationBellButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _syncRingAnimation();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _ringController.dispose();
    super.dispose();
  }

  void _onChanged() {
    _syncRingAnimation();
    if (mounted) setState(() {});
  }

  void _syncRingAnimation() {
    final hasUnread = widget.controller.unreadCount > 0;
    if (hasUnread) {
      if (!_ringController.isAnimating) {
        _ringController.repeat();
      }
    } else if (_ringController.isAnimating || _ringController.value != 0) {
      _ringController.stop();
      _ringController.value = 0;
    }
  }

  Future<void> _openPanel() async {
    final box = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final panelWidth = screenWidth < 420 ? screenWidth - 24.0 : 360.0;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Stack(
              children: [
                Positioned(
                  top: offset.dy + size.height + 6,
                  right: 12,
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: panelWidth,
                      child: _NotificationPanel(
                        controller: widget.controller,
                        isMarkingAll: _isMarkingAll,
                        onMarkAll: () async {
                          setDialogState(() => _isMarkingAll = true);
                          setState(() => _isMarkingAll = true);
                          try {
                            await widget.controller.markAllRead();
                          } catch (error) {
                            if (!dialogContext.mounted) return;
                            showAppSnackBar(
                              dialogContext,
                              message: error.toString(),
                              type: AppSnackBarType.error,
                            );
                          } finally {
                            if (mounted) {
                              setState(() => _isMarkingAll = false);
                            }
                            if (dialogContext.mounted) {
                              setDialogState(() => _isMarkingAll = false);
                            }
                          }
                        },
                        onViewAll: () {
                          Navigator.of(dialogContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => NotificationsScreen(
                                apiClient: widget.apiClient,
                                onLoginAgain: widget.onLoginAgain,
                                inboxController: widget.controller,
                              ),
                            ),
                          );
                        },
                        onOpenNotification: (notification) async {
                          Navigator.of(dialogContext).pop();
                          try {
                            if (!notification.isRead) {
                              await widget.controller.markRead(notification.id);
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
                        },
                        onRefresh: () => widget.controller.refresh(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Refresh after closing panel so badge stays current.
    await widget.controller.refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final unread = widget.controller.unreadCount;

    return IconButton(
      key: _buttonKey,
      tooltip: 'Notifications',
      onPressed: _openPanel,
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: Colors.white,
        label: Text(
          '$unread',
          style: TextStyle(
            color: primary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: AnimatedBuilder(
          animation: _ringController,
          builder: (context, child) {
            if (unread <= 0) return child!;
            return Transform.scale(
              scale: _ringScale.value,
              child: Transform.rotate(
                angle: _ringAngle.value,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
          child: const Icon(
            Icons.notifications_outlined,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({
    required this.controller,
    required this.isMarkingAll,
    required this.onMarkAll,
    required this.onViewAll,
    required this.onOpenNotification,
    required this.onRefresh,
  });

  final NotificationInboxController controller;
  final bool isMarkingAll;
  final Future<void> Function() onMarkAll;
  final VoidCallback onViewAll;
  final Future<void> Function(AppNotification notification) onOpenNotification;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: isMarkingAll ? null : onMarkAll,
                    child: isMarkingAll
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark all as read'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  if (controller.isLoading && !controller.hasLoadedOnce) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (controller.hasError && controller.items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Couldn’t load notifications.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: onRefresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final items = controller.panelItems;
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'You don’t have any notifications.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = items[index];
                      final canOpen = notification.canNavigate;
                      final unread = !notification.isRead;
                      return ListTile(
                        dense: true,
                        enabled: canOpen,
                        onTap: canOpen
                            ? () => onOpenNotification(notification)
                            : null,
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: unread
                              ? primary
                              : Colors.black.withValues(alpha: 0.2),
                        ),
                        title: Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight:
                                unread ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: notification.createdAt == null
                            ? null
                            : Text(
                                formatNotificationTimestamp(
                                  notification.createdAt!,
                                ),
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

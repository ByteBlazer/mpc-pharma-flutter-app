import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../widgets/app_load_error_state.dart';
import 'notification_models.dart';

class NotificationInboxController extends ChangeNotifier {
  NotificationInboxController(this.apiClient);

  final ApiClient apiClient;

  static const pollInterval = Duration(minutes: 1);
  static const panelPreviewLimit = 8;

  List<AppNotification> _items = const [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  Object? _error;
  Timer? _pollTimer;

  List<AppNotification> get items => _items;
  List<AppNotification> get panelItems =>
      _items.take(panelPreviewLimit).toList(growable: false);
  int get unreadCount => _items.where((item) => !item.isRead).length;
  bool get isLoading => _isLoading;
  bool get hasLoadedOnce => _hasLoadedOnce;
  Object? get error => _error;
  bool get isAuthError => isAuthErrorMessage(_error);
  bool get hasError => _error != null;

  void startPolling() {
    _pollTimer?.cancel();
    unawaited(refresh());
    _pollTimer = Timer.periodic(pollInterval, (_) {
      unawaited(refresh(silent: true));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final next = await apiClient.getNotifications();
      _items = next;
      _error = null;
      _hasLoadedOnce = true;
    } catch (error) {
      _error = error;
      _hasLoadedOnce = true;
      if (!silent) {
        // Keep previous items if we already had a successful load.
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(String notificationId) async {
    await apiClient.markNotificationRead(notificationId: notificationId);
    await refresh(silent: true);
  }

  Future<void> markAllRead() async {
    await apiClient.markAllNotificationsRead();
    await refresh(silent: true);
  }
}

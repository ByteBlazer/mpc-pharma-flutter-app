// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

void configureBrowserHistorySync() {
  // Take ownership of history so Flutter's SingleEntryBrowserHistory does not
  // fight Chrome's history-manipulation intervention on Android.
  setUrlStrategy(null);
}

NavigatorObserver createBrowserHistorySyncObserver() {
  return _BrowserHistorySyncObserver();
}

class _BrowserHistorySyncObserver extends NavigatorObserver {
  _BrowserHistorySyncObserver() {
    // Kept for the lifetime of the app (single MaterialApp observer).
    html.window.onPopState.listen(_onPopState);
  }

  bool _handlingBrowserPop = false;
  int _pendingHistoryBacks = 0;
  bool _ignoreNextPopState = false;
  bool _microtaskScheduled = false;

  void _onPopState(html.PopStateEvent _) {
    if (_ignoreNextPopState) {
      _ignoreNextPopState = false;
      return;
    }
    final nav = navigator;
    if (nav == null || !nav.canPop()) {
      return;
    }
    _handlingBrowserPop = true;
    nav.pop();
    _handlingBrowserPop = false;
  }

  void _pushHistoryEntry() {
    html.window.history.pushState(
      <String, Object?>{'flutter_nav': true},
      html.document.title,
      html.window.location.href,
    );
  }

  void _scheduleHistoryBack() {
    _pendingHistoryBacks += 1;
    if (_microtaskScheduled) return;
    _microtaskScheduled = true;
    scheduleMicrotask(() {
      _microtaskScheduled = false;
      final count = _pendingHistoryBacks;
      _pendingHistoryBacks = 0;
      if (count <= 0) return;
      _ignoreNextPopState = true;
      html.window.history.go(-count);
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    _pushHistoryEntry();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_handlingBrowserPop) return;
    _scheduleHistoryBack();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_handlingBrowserPop) return;
    // pushAndRemoveUntil / removeRoute use didRemove instead of didPop.
    if (previousRoute != null) {
      _scheduleHistoryBack();
    }
  }
}

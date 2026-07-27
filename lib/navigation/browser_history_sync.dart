import 'package:flutter/widgets.dart';

import 'browser_history_sync_stub.dart'
    if (dart.library.html) 'browser_history_sync_web.dart'
    as impl;

/// Disables Flutter's default single-entry browser history on web.
///
/// Call once from [main] before [runApp]. Without this, Android Chrome can
/// skip history entries re-created during `popstate` and exit the tab instead
/// of popping nested [Navigator] routes.
void configureBrowserHistorySync() => impl.configureBrowserHistorySync();

/// Keeps browser history in sync with imperative [Navigator.push]/[Navigator.pop].
///
/// Each pushed route creates a history entry during the user gesture (so
/// Chrome does not mark it skippable). Device / browser back pops the
/// [Navigator]; AppBar / programmatic pops call `history.go` to match.
NavigatorObserver createBrowserHistorySyncObserver() {
  return impl.createBrowserHistorySyncObserver();
}

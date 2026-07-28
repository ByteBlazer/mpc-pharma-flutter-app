import 'package:flutter/material.dart';

import '../../navigation/initial_app_screen.dart';
import '../../services/force_update_service.dart';
import 'force_update_screen.dart';

/// Blocks Android/iOS app use when the installed version is below the server
/// minimum, or when the version check cannot be completed (fail closed).
///
/// Public tracking (`/track`) and web are exempt.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate>
    with WidgetsBindingObserver {
  ForceUpdateEvaluation? _evaluation;
  var _checking = false;
  var _isUpdating = false;
  var _blockingCheckInProgress = false;

  bool get _shouldEnforce =>
      ForceUpdateService.appliesToCurrentPlatform && !isPublicTrackingLaunch;

  bool get _isBlocked => _evaluation?.isBlocked ?? false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_shouldEnforce) {
      _checkForUpdate(blocking: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldEnforce) {
      // Re-check silently when returning from background so the app tree
      // (and shared ApiClient) stays mounted while requests are in flight.
      _checkForUpdate(blocking: false);
    }
  }

  Future<void> _checkForUpdate({required bool blocking}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _blockingCheckInProgress = blocking;
      if (blocking && !_isBlocked) {
        _evaluation = null;
      }
    });

    final evaluation = await ForceUpdateService.evaluate();

    if (!mounted) return;
    setState(() {
      _checking = false;
      _blockingCheckInProgress = false;
      if (evaluation.result == ForceUpdateCheckResult.notApplicable ||
          evaluation.result == ForceUpdateCheckResult.upToDate) {
        _evaluation = null;
        _isUpdating = false;
        return;
      }
      _evaluation = evaluation;
      _isUpdating = false;
    });
  }

  Future<void> _handleUpdate() async {
    final evaluation = _evaluation;
    if (evaluation == null) return;

    setState(() => _isUpdating = true);
    await ForceUpdateService.startUpdateFlow(evaluation);
    if (!mounted) return;
    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldEnforce) {
      return widget.child;
    }

    if (_checking && _blockingCheckInProgress && !_isBlocked) {
      return const ForceUpdateCheckingScreen();
    }

    final evaluation = _evaluation;
    if (evaluation != null && evaluation.isBlocked) {
      return ForceUpdateScreen(
        evaluation: evaluation,
        onUpdate: _handleUpdate,
        onRetry: () => _checkForUpdate(blocking: true),
        isUpdating: _isUpdating,
        isRetrying: _checking,
      );
    }

    return widget.child;
  }
}

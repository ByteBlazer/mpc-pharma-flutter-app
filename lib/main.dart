import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'app_theme.dart';
import 'features/force_update/force_update_gate.dart';
import 'navigation/browser_history_sync.dart';
import 'navigation/initial_app_screen.dart';
import 'services/trip_heartbeat_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureBrowserHistorySync();
  await AppEnvironment.load();
  TripHeartbeatService.initForegroundTask();
  runApp(const MpcPharmaApp());
}

class MpcPharmaApp extends StatelessWidget {
  const MpcPharmaApp({super.key});

  static final NavigatorObserver _browserHistoryObserver =
      createBrowserHistorySyncObserver();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPC Pharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      navigatorObservers: [_browserHistoryObserver],
      home: ForceUpdateGate(child: buildInitialAppScreen()),
    );
  }
}

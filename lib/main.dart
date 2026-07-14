import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'app_theme.dart';
import 'features/auth/login_screen.dart';
import 'navigation/browser_history_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureBrowserHistorySync();
  await AppEnvironment.load();
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
      home: const LoginScreen(),
    );
  }
}

import 'package:flutter/material.dart';

import 'app_environment.dart';
import 'app_theme.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppEnvironment.load();
  runApp(const MpcPharmaApp());
}

class MpcPharmaApp extends StatelessWidget {
  const MpcPharmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MPC Pharma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoginScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/location_tracking_service.dart';
import 'core/utils/platform_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supportsNativeLocationService) {
    await LocationTrackingService.initialize();
  }
  runApp(const ProviderScope(child: MpcPharmaApp()));
}

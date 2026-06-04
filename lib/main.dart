import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/services/location_tracking_service.dart';
import 'core/utils/platform_utils.dart';
import 'routing/track_url.dart';
import 'track_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN');
  if (supportsNativeLocationService) {
    await LocationTrackingService.initialize();
  }

  if (kIsWeb && TrackUrl.isTrackLaunch(Uri.base)) {
    runApp(
      ProviderScope(
        child: TrackApp(token: TrackUrl.parseToken(Uri.base)),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: MpcPharmaApp()));
}

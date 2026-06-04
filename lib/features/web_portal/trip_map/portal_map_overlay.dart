import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Ensures taps reach Flutter widgets rendered above Google Maps on web.
class PortalMapOverlay extends StatelessWidget {
  const PortalMapOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return PointerInterceptor(child: child);
    }
    return child;
  }
}

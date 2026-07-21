// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

bool isMobileWebViewportImpl() => (html.window.innerWidth ?? 1024) < 600;

Stream<bool> webTabVisibilityStreamImpl() {
  final controller = StreamController<bool>.broadcast();

  void emit() {
    if (controller.isClosed) return;
    controller.add(!(html.document.hidden ?? false));
  }

  emit();
  html.document.onVisibilityChange.listen((_) => emit());

  return controller.stream;
}

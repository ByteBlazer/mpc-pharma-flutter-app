// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

/// True when the browser user agent looks like Android or iOS.
bool get isMobileWebBrowser {
  final userAgent = html.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('android') ||
      userAgent.contains('iphone') ||
      userAgent.contains('ipad') ||
      userAgent.contains('ipod');
}

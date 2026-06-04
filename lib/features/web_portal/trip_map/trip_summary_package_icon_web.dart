import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

const _viewType = 'trip-summary-package-icon';
const _packageIconUrl =
    'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4e6.png';

bool _viewFactoryRegistered = false;

/// Web — DOM `<img>` (same technique as [platformSignatureImage]); Flutter
/// [Image] widgets often paint blank above Google Maps.
Widget tripSummaryPackageIcon(double size) {
  _registerViewFactoryOnce();

  return SizedBox(
    width: size,
    height: size,
    child: HtmlElementView(viewType: _viewType),
  );
}

void _registerViewFactoryOnce() {
  if (_viewFactoryRegistered) return;
  _viewFactoryRegistered = true;

  ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
    final img = web.document.createElement('img') as web.HTMLImageElement;
    img.src = _packageIconUrl;
    img.style.width = '16px';
    img.style.height = '16px';
    img.style.objectFit = 'contain';
    img.style.display = 'block';
    img.style.border = 'none';
    return img;
  });
}

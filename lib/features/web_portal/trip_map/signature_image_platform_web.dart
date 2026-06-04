import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final _registeredViewTypes = <String>{};

/// Inset inside the preview box (React MUI `p: 2` + safe margin so strokes aren't clipped).
const _previewInsetPx = 16;

/// Web signature rendering via DOM `<img>` (same approach as React).
Widget platformSignatureImage(
  String? base64Signature,
  String dataUri, {
  double? width,
  double? height,
  double maxHeight = 400,
  bool fillContainer = false,
}) {
  final viewType =
      'portal-sig-v2-${dataUri.hashCode}-${width ?? 0}-${height ?? 0}-$maxHeight-$fillContainer';

  if (!_registeredViewTypes.contains(viewType)) {
    _registeredViewTypes.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final wrapper = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.boxSizing = 'border-box'
        ..style.overflow = 'visible'
        ..style.background = '#ffffff';

      final img = web.document.createElement('img') as web.HTMLImageElement;
      img.src = dataUri;
      img.alt = 'Signature';
      img.style.objectFit = 'contain';
      img.style.display = 'block';
      img.style.border = 'none';

      if (fillContainer) {
        wrapper.style.padding = '${_previewInsetPx}px';
        // Fill padded area; object-fit contain scales up/down without cropping (React parity).
        img.style.width = '100%';
        img.style.height = '100%';
        img.style.maxWidth = '100%';
        img.style.maxHeight = '100%';
      } else {
        img.style.width = '${width ?? 110}px';
        img.style.height = '${height ?? 70}px';
        img.style.maxWidth = '100%';
        img.style.maxHeight = '100%';
      }

      wrapper.append(img);
      return wrapper;
    });
  }

  return SizedBox(
    width: width ?? (fillContainer ? double.infinity : 110),
    height: height ?? (fillContainer ? maxHeight : 70),
    child: HtmlElementView(viewType: viewType),
  );
}

import 'package:flutter/material.dart';

/// Positions a menu panel below an anchor widget — works on web and mobile.
abstract final class WebPortalOverlayDropdown {
  static OverlayEntry? _entry;

  static bool get isOpen => _entry != null;

  static void dismiss() {
    _entry?.remove();
    _entry = null;
  }

  static void show({
    required BuildContext context,
    required GlobalKey anchorKey,
    required Widget Function(BuildContext menuContext, VoidCallback close)
        buildMenu,
    Offset offset = const Offset(0, 4),
    VoidCallback? onDismiss,
  }) {
    dismiss();

    final anchorBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) return;

    final anchorOrigin = anchorBox.localToGlobal(Offset.zero);
    final anchorSize = anchorBox.size;

    void close() {
      FocusManager.instance.primaryFocus?.unfocus();
      dismiss();
      onDismiss?.call();
    }

    _entry = OverlayEntry(
      builder: (menuContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: close,
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: anchorOrigin.dx,
            top: anchorOrigin.dy + anchorSize.height + offset.dy,
            width: anchorSize.width,
            child: Material(
              color: Colors.white,
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(4),
              clipBehavior: Clip.antiAlias,
              child: buildMenu(menuContext, close),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }
}

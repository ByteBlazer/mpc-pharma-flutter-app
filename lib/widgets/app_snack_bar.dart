import 'package:flutter/material.dart';

enum AppSnackBarType { success, error, warning }

OverlayEntry? _activeSnackBar;

void showAppSnackBar(
  BuildContext context, {
  required String message,
  required AppSnackBarType type,
}) {
  _activeSnackBar?.remove();
  _activeSnackBar = null;

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _AppSnackBarOverlay(
      message: message,
      type: type,
      onDismissed: () {
        if (_activeSnackBar == entry) {
          _activeSnackBar = null;
        }
        entry.remove();
      },
    ),
  );

  _activeSnackBar = entry;
  overlay.insert(entry);
}

class _AppSnackBarOverlay extends StatefulWidget {
  const _AppSnackBarOverlay({
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  final String message;
  final AppSnackBarType type;
  final VoidCallback onDismissed;

  @override
  State<_AppSnackBarOverlay> createState() => _AppSnackBarOverlayState();
}

class _AppSnackBarOverlayState extends State<_AppSnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      reverseDuration: const Duration(milliseconds: 550),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _showAndDismiss();
  }

  Future<void> _showAndDismiss() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 3200));
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = HSLColor.fromColor(
      theme.colorScheme.primary,
    ).withSaturation(0.35).withLightness(0.92).toColor();

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.primary),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(_icon, color: _iconColor, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 34),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _icon {
    return switch (widget.type) {
      AppSnackBarType.success => Icons.check_circle_outline,
      AppSnackBarType.error => Icons.error_outline,
      AppSnackBarType.warning => Icons.warning_amber_outlined,
    };
  }

  Color get _iconColor {
    return switch (widget.type) {
      AppSnackBarType.success => const Color(0xFF2E7D32),
      AppSnackBarType.error => Colors.red,
      AppSnackBarType.warning => const Color(0xFFB26A00),
    };
  }
}

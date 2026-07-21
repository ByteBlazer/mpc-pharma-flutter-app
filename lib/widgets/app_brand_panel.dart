import 'package:flutter/material.dart';

/// Info panel with solid brand ([ColorScheme.primary]) background and white text.
///
/// Use whenever copy sits on the brand color — not on pale tints (alpha &lt; ~0.2).
class AppBrandPanel extends StatelessWidget {
  const AppBrandPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 8,
    this.textAlign,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onPrimary;
    const panelTextStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      decoration: TextDecoration.none,
    );

    return DefaultTextStyle(
      style: panelTextStyle.copyWith(color: foreground),
      textAlign: textAlign,
      child: IconTheme(
        data: IconThemeData(color: foreground, size: 18),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: child,
        ),
      ),
    );
  }
}

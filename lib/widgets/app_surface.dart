import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Branded panel surface for list items, forms, and cards on gradient pages.
class AppSurface extends StatelessWidget {
  const AppSurface({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.clip = false,
  });

  final Widget child;
  final double borderRadius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final content = clip
        ? ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: child,
          )
        : child;

    return DecoratedBox(
      decoration: AppTheme.gradientPageSurface(
        primary,
        borderRadius: borderRadius,
      ),
      child: content,
    );
  }
}

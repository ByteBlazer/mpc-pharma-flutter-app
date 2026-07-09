import 'package:flutter/material.dart';

/// Brand-tinted page background used across the app.
///
/// [showDecorCircles] is enabled on the home screen only.
class AppBrandPageBackground extends StatelessWidget {
  const AppBrandPageBackground({super.key, this.showDecorCircles = false});

  final bool showDecorCircles;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final size = MediaQuery.sizeOf(context);

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [primary.withValues(alpha: 0.01), Colors.white],
                ),
              ),
            ),
          ),
          if (showDecorCircles)
            ..._bottomCircles(
              width: size.width,
              height: size.height,
              primary: primary,
            ),
        ],
      ),
    );
  }

  List<Widget> _bottomCircles({
    required double width,
    required double height,
    required Color primary,
  }) {
    final compact = width < 400;
    final largeSize = height * (compact ? 0.22 : 0.24);
    final mediumSize = height * (compact ? 0.16 : 0.175);
    final smallSize = height * (compact ? 0.12 : 0.13);
    final sideInset = width * 0.045;

    final largeBottom = -largeSize * 0.20;
    final largeLeft = -largeSize * 0.40;
    final mediumBottom = height * 0.08;
    final smallBottom = height * 0.30;
    final smallLeft = width * 0.20;

    return [
      Positioned(
        left: largeLeft,
        bottom: largeBottom,
        child: _DecorCircle(
          size: largeSize,
          color: primary.withValues(alpha: 0.08),
        ),
      ),
      Positioned(
        left: width - sideInset - mediumSize,
        bottom: mediumBottom,
        child: _DecorCircle(
          size: mediumSize,
          color: primary.withValues(alpha: 0.065),
        ),
      ),
      Positioned(
        left: smallLeft,
        bottom: smallBottom,
        child: _DecorCircle(
          size: smallSize,
          color: primary.withValues(alpha: 0.05),
        ),
      ),
    ];
  }
}

/// Wraps scaffold body content on top of the shared brand gradient.
class AppGradientScaffoldBody extends StatelessWidget {
  const AppGradientScaffoldBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: AppBrandPageBackground()),
        child,
      ],
    );
  }
}

class _DecorCircle extends StatelessWidget {
  const _DecorCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

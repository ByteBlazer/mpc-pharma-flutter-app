import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Speech-balloon guidance shown above the first ongoing trip card (React Popover).
class TripDashboardGuidance extends StatelessWidget {
  const TripDashboardGuidance({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primary,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '👋 The map is now showing all driver locations. '
              'Click on a trip card to view that trip\'s details alone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        ),
        CustomPaint(
          size: const Size(16, 8),
          painter: _SpeechTailPainter(color: AppColors.primary),
        ),
      ],
    );
  }
}

class _SpeechTailPainter extends CustomPainter {
  _SpeechTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpeechTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

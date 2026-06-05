import 'package:flutter/material.dart';

/// MPC Pharma pill logo — drawn in Flutter (no SVG parser; avoids web console noise).
class MpcPharmaLogo extends StatelessWidget {
  const MpcPharmaLogo({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MpcPharmaLogoPainter(),
      ),
    );
  }
}

class _MpcPharmaLogoPainter extends CustomPainter {
  static const _red = [Color(0xFFF87171), Color(0xFFDC2626), Color(0xFF991B1B)];
  static const _blue = [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1D4ED8)];
  static const _line = [Color(0xFFFFFFFF), Color(0xFFE5E7EB), Color(0xFFD1D5DB)];

  Path _halfPath(double s, {required bool top}) {
    final path = Path();
    if (top) {
      path
        ..moveTo(35 * s, 50 * s)
        ..lineTo(35 * s, 30 * s)
        ..quadraticBezierTo(35 * s, 15 * s, 50 * s, 15 * s)
        ..quadraticBezierTo(65 * s, 15 * s, 65 * s, 30 * s)
        ..lineTo(65 * s, 50 * s)
        ..close();
    } else {
      path
        ..moveTo(35 * s, 50 * s)
        ..lineTo(35 * s, 70 * s)
        ..quadraticBezierTo(35 * s, 85 * s, 50 * s, 85 * s)
        ..quadraticBezierTo(65 * s, 85 * s, 65 * s, 70 * s)
        ..lineTo(65 * s, 50 * s)
        ..close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    final bounds = Rect.fromLTWH(0, 0, size.width, size.height);

    final shadowPaint = Paint()..color = const Color(0x1F000000);
    for (final top in [true, false]) {
      final shadow = _halfPath(s, top: top).shift(const Offset(2, 2));
      canvas.drawPath(shadow, shadowPaint);
    }

    final redPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _red,
        stops: const [0, 0.5, 1],
      ).createShader(bounds);
    canvas.drawPath(_halfPath(s, top: true), redPaint);

    final bluePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _blue,
        stops: const [0, 0.5, 1],
      ).createShader(bounds);
    canvas.drawPath(_halfPath(s, top: false), bluePaint);

    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _line,
        stops: const [0, 0.5, 1],
      ).createShader(bounds)
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(35 * s, 50 * s), Offset(65 * s, 50 * s), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

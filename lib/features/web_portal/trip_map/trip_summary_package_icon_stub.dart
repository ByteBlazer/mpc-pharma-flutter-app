import 'package:flutter/material.dart';

const _assetPath = 'assets/images/package_emoji.png';
const _fallbackBrown = Color(0xFF8B6914);

/// Native/mobile — bundled Twemoji PNG.
Widget tripSummaryPackageIcon(double size) {
  return SizedBox(
    width: size,
    height: size,
    child: Image.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => Icon(
        Icons.inventory_2,
        size: size,
        color: _fallbackBrown,
      ),
    ),
  );
}

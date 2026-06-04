import 'package:flutter/material.dart';

import 'portal_map_utils.dart';

/// Native (mobile/desktop) signature rendering via [Image.memory].
Widget platformSignatureImage(
  String? base64Signature,
  String dataUri, {
  double? width,
  double? height,
  double maxHeight = 400,
  bool fillContainer = false,
}) {
  final bytes = decodePortalBase64Image(base64Signature);
  final h = height ?? (fillContainer ? maxHeight : 70);
  final w = width ?? 110;
  if (bytes == null) {
    return _SignatureError(width: w, height: h);
  }

  if (fillContainer && width != null && height != null) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, error, stackTrace) {
            debugPrint('Signature Image.memory failed: $error');
            return _SignatureError(width: w, height: h);
          },
        ),
      ),
    );
  }

  return Image.memory(
    bytes,
    width: width,
    height: h,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    errorBuilder: (_, error, stackTrace) {
      debugPrint('Signature Image.memory failed: $error');
      return _SignatureError(width: w, height: h);
    },
  );
}

class _SignatureError extends StatelessWidget {
  const _SignatureError({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: Text(
          'Signature unavailable',
          style: TextStyle(fontSize: 10, color: Color(0xFF999999)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

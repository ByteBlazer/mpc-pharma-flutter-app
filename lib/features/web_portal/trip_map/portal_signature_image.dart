import 'package:flutter/material.dart';

import 'portal_map_utils.dart';
import 'signature_image_platform_stub.dart'
    if (dart.library.html) 'signature_image_platform_web.dart';

/// Renders a delivery signature (React uses `data:image/png;base64,...`).
class PortalSignatureImage extends StatelessWidget {
  const PortalSignatureImage({
    super.key,
    required this.base64Signature,
    this.width = 110,
    this.height = 70,
    this.maxHeight = 400,
    this.showLabel = true,
    this.fillContainer = false,
  });

  final String? base64Signature;
  final double? width;
  final double? height;
  final double maxHeight;
  final bool showLabel;
  final bool fillContainer;

  @override
  Widget build(BuildContext context) {
    final dataUri = portalSignatureDataUri(base64Signature);
    if (dataUri == null) return const SizedBox.shrink();

    final image = platformSignatureImage(
      base64Signature,
      dataUri,
      width: width,
      height: height,
      maxHeight: maxHeight,
      fillContainer: fillContainer,
    );

    if (!showLabel) return image;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Delivery Signature:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: image,
        ),
      ],
    );
  }
}

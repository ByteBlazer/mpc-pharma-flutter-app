import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Longest edge cap for ticket photo attachments.
const ticketAttachmentImageMaxSide = 1600;

/// JPEG quality for ticket photo attachments (0–100).
const ticketAttachmentImageJpegQuality = 72;

class PreparedTicketImage {
  const PreparedTicketImage({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

bool isTicketAttachmentImageMime(String mimeType) {
  final normalized = mimeType.trim().toLowerCase();
  return normalized == 'image/jpeg' ||
      normalized == 'image/jpg' ||
      normalized == 'image/png' ||
      normalized == 'image/webp' ||
      normalized == 'image/gif';
}

bool isTicketAttachmentImageFileName(String fileName) {
  final extension = _extensionFromFileName(fileName);
  return switch (extension) {
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' => true,
    _ => false,
  };
}

/// Downscales and re-encodes ticket photos as JPEG. Returns [null] when the
/// input is not a decodable raster image.
PreparedTicketImage? compressTicketAttachmentImage({
  required List<int> bytes,
  required String fileName,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(bytes));
  if (decoded == null) return null;

  final resized = _resizeToMaxSide(decoded, ticketAttachmentImageMaxSide);
  final encoded = img.encodeJpg(
    resized,
    quality: ticketAttachmentImageJpegQuality,
  );

  return PreparedTicketImage(
    bytes: encoded,
    fileName: _jpegFileName(fileName),
    mimeType: 'image/jpeg',
  );
}

img.Image _resizeToMaxSide(img.Image source, int maxSide) {
  final width = source.width;
  final height = source.height;
  if (width <= maxSide && height <= maxSide) return source;

  late int targetWidth;
  late int targetHeight;
  if (width >= height) {
    targetWidth = maxSide;
    targetHeight = (height * maxSide / width).round();
  } else {
    targetHeight = maxSide;
    targetWidth = (width * maxSide / height).round();
  }

  return img.copyResize(
    source,
    width: targetWidth,
    height: targetHeight,
    interpolation: img.Interpolation.linear,
  );
}

String _jpegFileName(String fileName) {
  final trimmed = fileName.trim();
  if (trimmed.isEmpty) {
    return 'photo-${DateTime.now().millisecondsSinceEpoch}.jpg';
  }
  final dot = trimmed.lastIndexOf('.');
  final base = dot > 0 ? trimmed.substring(0, dot) : trimmed;
  return '$base.jpg';
}

String _extensionFromFileName(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

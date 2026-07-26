import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Decodes API signature field (raw base64, optional data-URI prefix).
Uint8List? decodeSignatureBase64(String raw) {
  var value = raw.trim();
  if (value.isEmpty) return null;

  const dataPrefix = 'data:image/png;base64,';
  if (value.toLowerCase().startsWith(dataPrefix)) {
    value = value.substring(dataPrefix.length);
  }

  value = value.replaceAll(RegExp(r'\s'), '');
  if (value.isEmpty) return null;

  // Pad to a multiple of 4 — some payloads omit trailing "=".
  final remainder = value.length % 4;
  if (remainder != 0) {
    value = value.padRight(value.length + (4 - remainder), '=');
  }

  try {
    final bytes = base64Decode(value);
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }
}

/// Inline preview for delivery signatures returned by the API.
class SignatureImagePreview extends StatelessWidget {
  const SignatureImagePreview({
    super.key,
    required this.signatureBase64,
    this.height = 88,
    this.maxWidth,
    this.adaptToImageSize = false,
  });

  final String signatureBase64;
  final double height;
  final double? maxWidth;

  /// Sizes the preview box to the decoded image aspect ratio (up to [maxWidth]).
  final bool adaptToImageSize;

  @override
  Widget build(BuildContext context) {
    if (adaptToImageSize) {
      return _AdaptiveSignatureImagePreview(
        signatureBase64: signatureBase64,
        maxWidth: maxWidth ?? 560,
      );
    }

    final bytes = decodeSignatureBase64(signatureBase64);

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: bytes == null
          ? const Text(
              'No signature available',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          : Padding(
              padding: const EdgeInsets.all(4),
              child: _SignatureImageBytes(bytes: bytes),
            ),
    );
  }
}

class _AdaptiveSignatureImagePreview extends StatefulWidget {
  const _AdaptiveSignatureImagePreview({
    required this.signatureBase64,
    required this.maxWidth,
  });

  final String signatureBase64;
  final double maxWidth;

  @override
  State<_AdaptiveSignatureImagePreview> createState() =>
      _AdaptiveSignatureImagePreviewState();
}

class _AdaptiveSignatureImagePreviewState
    extends State<_AdaptiveSignatureImagePreview> {
  static const _maxHeight = 480.0;
  static const _minHeight = 88.0;

  Size? _imageSize;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant _AdaptiveSignatureImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signatureBase64 != widget.signatureBase64) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final bytes = decodeSignatureBase64(widget.signatureBase64);
    if (bytes == null) {
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _imageSize = null;
      });
      return;
    }

    Size? imageSize;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
    } catch (_) {
      imageSize = null;
    }

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _imageSize = imageSize;
    });
  }

  Size _displaySize(Size imageSize) {
    var width = widget.maxWidth;
    var height = width * imageSize.height / imageSize.width;

    if (height > _maxHeight) {
      height = _maxHeight;
      width = height * imageSize.width / imageSize.height;
    }
    if (height < _minHeight) {
      height = _minHeight;
      width = height * imageSize.width / imageSize.height;
    }

    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    final imageSize = _imageSize;

    if (bytes == null) {
      return _signatureFrame(
        height: _minHeight,
        width: widget.maxWidth,
        child: const Text(
          'No signature available',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );
    }

    if (imageSize == null) {
      return _signatureFrame(
        height: _minHeight,
        width: widget.maxWidth,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final displaySize = _displaySize(imageSize);
    return _signatureFrame(
      height: displaySize.height,
      width: displaySize.width,
      child: _SignatureImageBytes(bytes: bytes),
    );
  }

  Widget _signatureFrame({
    required double height,
    required double width,
    required Widget child,
  }) {
    return Container(
      height: height,
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: child,
      ),
    );
  }
}

class _SignatureImageBytes extends StatelessWidget {
  const _SignatureImageBytes({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    // Flutter web renders data-URI network images more reliably than
    // Image.memory for some PNG payloads from the API.
    if (kIsWeb) {
      final dataUri = 'data:image/png;base64,${base64Encode(bytes)}';
      return Image.network(
        dataUri,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (context, error, stackTrace) =>
            const _SignatureErrorMessage(),
      );
    }

    return Image(
      image: MemoryImage(bytes),
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) =>
          const _SignatureErrorMessage(),
    );
  }
}

class _SignatureErrorMessage extends StatelessWidget {
  const _SignatureErrorMessage();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Unable to display signature',
      style: TextStyle(fontSize: 12, color: Colors.black54),
    );
  }
}

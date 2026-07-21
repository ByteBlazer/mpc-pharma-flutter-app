import 'dart:convert';

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
  });

  final String signatureBase64;
  final double height;

  @override
  Widget build(BuildContext context) {
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

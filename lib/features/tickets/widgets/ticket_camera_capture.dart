import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ticket_camera_availability_stub.dart'
    if (dart.library.html) 'ticket_camera_availability_web.dart';

final ImagePicker _ticketImagePicker = ImagePicker();
Future<bool>? _ticketCameraAvailableFuture;

/// Whether this device/platform can capture photos via [captureTicketPhoto].
Future<bool> checkTicketCameraAvailable() {
  return _ticketCameraAvailableFuture ??=
      probeTicketCameraAvailable(_ticketImagePicker);
}

class TicketCameraCaptureResult {
  const TicketCameraCaptureResult({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
}

/// Opens the device camera, returns `null` if the user cancels.
/// Throws a user-facing [Exception] when the camera cannot be used.
Future<TicketCameraCaptureResult?> captureTicketPhoto() async {
  if (!kIsWeb) {
    var status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      throw Exception(
        'Camera access is denied. Open app settings to allow camera access.',
      );
    }
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception(
          status.isPermanentlyDenied
              ? 'Camera access is denied. Open app settings to allow camera access.'
              : 'Camera permission is required to take a photo.',
        );
      }
    }
  }

  final picker = ImagePicker();
  XFile? photo;
  try {
    photo = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
  } on PlatformException catch (error) {
    throw Exception(_messageForPlatformError(error));
  } catch (error) {
    throw Exception(_messageForGenericError(error));
  }

  if (photo == null) return null;

  final bytes = await photo.readAsBytes();
  final mimeType = _resolveMimeType(photo);
  final fileName = _resolveFileName(photo, mimeType);

  return TicketCameraCaptureResult(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );
}

String _messageForPlatformError(PlatformException error) {
  final code = error.code.toLowerCase();
  final message = (error.message ?? '').toLowerCase();

  if (code.contains('camera') && code.contains('access')) {
    return 'Camera permission is required to take a photo.';
  }
  if (code.contains('permission') ||
      message.contains('permission') ||
      message.contains('denied')) {
    return kIsWeb
        ? 'Camera permission was denied. Allow camera access for this site in your browser settings.'
        : 'Camera permission is required to take a photo.';
  }
  if (code.contains('camera') ||
      message.contains('no camera') ||
      message.contains('not available') ||
      message.contains('unavailable')) {
    return 'No camera is available on this device.';
  }
  return 'Could not open the camera. Please try again.';
}

String _messageForGenericError(Object error) {
  final text = error.toString().toLowerCase();
  if (text.contains('permission') || text.contains('denied')) {
    return kIsWeb
        ? 'Camera permission was denied. Allow camera access for this site in your browser settings.'
        : 'Camera permission is required to take a photo.';
  }
  if (text.contains('camera') &&
      (text.contains('not available') ||
          text.contains('unavailable') ||
          text.contains('no camera'))) {
    return 'No camera is available on this device.';
  }
  return 'Could not open the camera. Please try again.';
}

String _resolveMimeType(XFile photo) {
  final mime = photo.mimeType?.trim();
  if (mime != null && mime.isNotEmpty) return mime;

  final extension = _extensionFromPath(photo.path);
  return switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}

String _resolveFileName(XFile photo, String mimeType) {
  final baseName = photo.name.trim();
  if (baseName.isNotEmpty) return baseName;

  final fromPath = _fileNameFromPath(photo.path);
  if (fromPath.isNotEmpty) return fromPath;

  final extension = switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/gif' => 'gif',
    _ => 'jpg',
  };
  return 'photo-${DateTime.now().millisecondsSinceEpoch}.$extension';
}

String _fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final segments = normalized.split('/');
  return segments.isEmpty ? '' : segments.last;
}

String _extensionFromPath(String path) {
  final fileName = _fileNameFromPath(path);
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:image_picker/image_picker.dart';

Future<bool> probeTicketCameraAvailable(ImagePicker picker) async {
  try {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) return false;

    final devices = await mediaDevices.enumerateDevices();
    return devices.any((device) => device.kind == 'videoinput');
  } catch (_) {
    return false;
  }
}

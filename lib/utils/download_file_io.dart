import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> downloadFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final extension = _fileExtension(fileName);
  await FilePicker.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
    type: extension != null ? FileType.custom : FileType.any,
    allowedExtensions: extension != null ? [extension] : null,
    bytes: Uint8List.fromList(bytes),
  );
}

String? _fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot >= fileName.length - 1) return null;
  return fileName.substring(dot + 1).toLowerCase();
}

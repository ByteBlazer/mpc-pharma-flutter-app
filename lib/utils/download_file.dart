import 'download_file_stub.dart'
    if (dart.library.html) 'download_file_web.dart';

Future<void> downloadFile({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) {
  return downloadFileImpl(fileName: fileName, bytes: bytes, mimeType: mimeType);
}

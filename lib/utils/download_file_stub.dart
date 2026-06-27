Future<void> downloadFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  throw UnsupportedError('File download is currently available on web only.');
}

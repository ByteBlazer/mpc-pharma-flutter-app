// Stub for conditional dart:io import on web.
class File {
  File(this.path);
  final String path;
  Future<List<int>> readAsBytes() {
    throw UnsupportedError('File IO is not available on web.');
  }
}

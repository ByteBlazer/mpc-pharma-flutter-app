import 'package:file_picker/file_picker.dart';

import '../../api/api_client.dart';
import 'ticket_models.dart';

class TicketAttachmentLimits {
  static const maxFileSize = 10 * 1024 * 1024;
  static const maxFilesPerTicket = 10;
  static const maxTotalSizePerTicket = 50 * 1024 * 1024;
  static const maxRecordingSeconds = 60;
}

class TicketAttachmentManager {
  TicketAttachmentManager(
    this.apiClient, {
    int existingFileCount = 0,
    int existingTotalSize = 0,
  }) : _existingFileCount = existingFileCount,
       _existingTotalSize = existingTotalSize;

  final ApiClient apiClient;
  final List<PendingTicketAttachment> _attachments = [];
  int _existingFileCount;
  int _existingTotalSize;

  List<PendingTicketAttachment> get attachments =>
      List<PendingTicketAttachment>.unmodifiable(_attachments);

  List<String> get attachmentIds =>
      _attachments.map((attachment) => attachment.attachmentId).toList();

  int get pendingTotalSize =>
      _attachments.fold(0, (sum, attachment) => sum + attachment.fileSize);

  int get totalSize => pendingTotalSize + _existingTotalSize;

  int get totalFileCount => _attachments.length + _existingFileCount;

  bool get canAddMore =>
      totalFileCount < TicketAttachmentLimits.maxFilesPerTicket;

  /// Account for files already linked to the ticket when validating new uploads.
  void setExistingTicketUsage({
    required int fileCount,
    required int totalSize,
  }) {
    _existingFileCount = fileCount < 0 ? 0 : fileCount;
    _existingTotalSize = totalSize < 0 ? 0 : totalSize;
  }

  void setExistingAttachments(Iterable<TicketAttachment> existing) {
    var count = 0;
    var size = 0;
    for (final attachment in existing) {
      count += 1;
      size += attachment.fileSize;
    }
    setExistingTicketUsage(fileCount: count, totalSize: size);
  }

  void validateCanAdd(int fileSize) {
    if (fileSize > TicketAttachmentLimits.maxFileSize) {
      throw Exception('Each file must be under 10 MB.');
    }
    if (!canAddMore) {
      throw Exception('A ticket can have at most 10 attachments.');
    }
    if (totalSize + fileSize > TicketAttachmentLimits.maxTotalSizePerTicket) {
      throw Exception('Total attachment size for a ticket cannot exceed 50 MB.');
    }
  }

  Future<PendingTicketAttachment> uploadBytes({
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    bool isAudio = false,
  }) async {
    validateCanAdd(bytes.length);
    final init = await apiClient.initiateTicketAttachmentUpload(
      fileName: fileName,
      mimeType: mimeType,
      fileSize: bytes.length,
    );
    await apiClient.uploadBytesToPresignedUrl(
      uploadUrl: init.uploadUrl,
      bytes: bytes,
      mimeType: mimeType,
    );
    await apiClient.markTicketAttachmentUploaded(
      attachmentId: init.attachmentId,
    );
    final pending = PendingTicketAttachment(
      attachmentId: init.attachmentId,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: bytes.length,
      isAudio: isAudio,
    );
    _attachments.add(pending);
    return pending;
  }

  Future<PendingTicketAttachment> uploadPlatformFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('Could not read ${file.name}.');
    }
    return uploadBytes(
      fileName: file.name,
      mimeType: _mimeTypeForFile(file),
      bytes: bytes,
    );
  }

  Future<void> removeUnlinked(String attachmentId) async {
    await apiClient.deleteUnlinkedTicketAttachment(attachmentId: attachmentId);
    _attachments.removeWhere((attachment) => attachment.attachmentId == attachmentId);
  }

  void clear() => _attachments.clear();

  static String _mimeTypeForFile(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'wav' => 'audio/wav',
      'webm' => 'audio/webm',
      _ => 'application/octet-stream',
    };
  }
}

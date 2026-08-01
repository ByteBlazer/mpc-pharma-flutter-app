import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app_theme.dart';
import '../ticket_attachment_manager.dart';
import '../ticket_models.dart';
import 'ticket_audio_recorder_button.dart';
import 'ticket_camera_capture.dart';

const kVoiceClipAttachedMarker = '[Voice Clip Attached]';

void applyVoiceClipAttachedMarker(TextEditingController controller) {
  final text = controller.text;
  if (text.contains(kVoiceClipAttachedMarker)) return;
  controller.text = text.isEmpty
      ? kVoiceClipAttachedMarker
      : '$kVoiceClipAttachedMarker$text';
}

void removeVoiceClipAttachedMarker(TextEditingController controller) {
  if (!controller.text.contains(kVoiceClipAttachedMarker)) return;
  controller.text = controller.text.replaceAll(kVoiceClipAttachedMarker, '');
}

class TicketDescriptionField extends StatelessWidget {
  const TicketDescriptionField({
    super.key,
    required this.controller,
    required this.attachmentManager,
    required this.onAttachmentsChanged,
    this.labelText = 'Description',
    this.hintText =
        'Write a description or record a voice message by clicking the microphone icon below…..',
    this.minLines = 4,
    this.maxLines = 12,
    this.enabled = true,
    this.isSubmitting = false,
    this.autofocus = false,
    this.showAudioRecorder = true,
    this.onSubmit,
    this.onCancel,
    this.submitTooltip = 'Save description',
  });

  final TextEditingController controller;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback onAttachmentsChanged;
  final String labelText;
  final String hintText;
  final int minLines;
  final int maxLines;
  final bool enabled;
  final bool isSubmitting;
  final bool autofocus;
  final bool showAudioRecorder;
  final VoidCallback? onSubmit;
  final Future<void> Function()? onCancel;
  final String submitTooltip;

  @override
  Widget build(BuildContext context) {
    final field = TicketComposerField(
      controller: controller,
      attachmentManager: attachmentManager,
      onAttachmentsChanged: onAttachmentsChanged,
      hintText: hintText,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      isSubmitting: isSubmitting,
      autofocus: autofocus,
      showAudioRecorder: showAudioRecorder,
      onSubmit: onSubmit,
      onCancel: onCancel,
      submitTooltip: submitTooltip,
      submitIcon: Icons.check_rounded,
    );

    if (labelText.isEmpty) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          labelText,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        field,
      ],
    );
  }
}

class TicketAttachmentPicker extends StatelessWidget {
  const TicketAttachmentPicker({
    super.key,
    required this.attachmentManager,
    required this.onChanged,
    required this.enabled,
  });

  final TicketAttachmentManager attachmentManager;
  final VoidCallback onChanged;
  final bool enabled;

  Future<void> _pickFiles(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      for (final file in result.files) {
        await attachmentManager.uploadPlatformFile(file);
      }
      onChanged();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: !enabled || !attachmentManager.canAddMore
            ? null
            : () => _pickFiles(context),
        icon: const Icon(Icons.attach_file),
        label: const Text('Add attachment'),
      ),
    );
  }
}

class TicketAttachmentList extends StatelessWidget {
  const TicketAttachmentList({
    super.key,
    required this.attachments,
    required this.attachmentManager,
    this.onRemove,
  });

  final List<PendingTicketAttachment> attachments;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: attachments.map((attachment) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            attachment.isAudio ? Icons.mic : Icons.insert_drive_file_outlined,
          ),
          title: Text(
            attachment.fileName,
            style: const TextStyle(color: Colors.black),
          ),
          subtitle: Text(
            '${(attachment.fileSize / 1024).toStringAsFixed(1)} KB',
            style: const TextStyle(color: Colors.black),
          ),
          trailing: onRemove == null
              ? null
              : IconButton(
                  tooltip: 'Remove attachment',
                  onPressed: () async {
                    await attachmentManager.removeUnlinked(
                      attachment.attachmentId,
                    );
                    onRemove?.call();
                  },
                  icon: const Icon(Icons.close),
                ),
        );
      }).toList(),
    );
  }
}

class TicketCommentField extends StatelessWidget {
  const TicketCommentField({
    super.key,
    required this.controller,
    required this.attachmentManager,
    required this.onAttachmentsChanged,
    this.enabled = true,
    this.isSubmitting = false,
    this.onSubmit,
    this.onCancel,
  });

  final TextEditingController controller;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback onAttachmentsChanged;
  final bool enabled;
  final bool isSubmitting;
  final VoidCallback? onSubmit;
  final Future<void> Function()? onCancel;

  @override
  Widget build(BuildContext context) {
    return TicketComposerField(
      controller: controller,
      attachmentManager: attachmentManager,
      onAttachmentsChanged: onAttachmentsChanged,
      enabled: enabled,
      isSubmitting: isSubmitting,
      onSubmit: onSubmit,
      onCancel: onCancel,
      hintText: 'Write a comment…',
      submitTooltip: 'Add comment',
      submitIcon: Icons.send,
      autofocus: true,
      minLines: 3,
      maxLines: 8,
    );
  }
}

class TicketComposerField extends StatefulWidget {
  const TicketComposerField({
    super.key,
    this.controller,
    required this.attachmentManager,
    required this.onAttachmentsChanged,
    this.hintText = '',
    this.enabled = true,
    this.isSubmitting = false,
    this.autofocus = false,
    this.showAudioRecorder = true,
    this.showTextField = true,
    this.minLines = 3,
    this.maxLines = 8,
    this.onSubmit,
    this.onCancel,
    this.submitTooltip = 'Submit',
    this.submitLabel,
    this.submitIcon = Icons.send,
  }) : assert(!showTextField || controller != null);

  final TextEditingController? controller;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback onAttachmentsChanged;
  final String hintText;
  final bool enabled;
  final bool isSubmitting;
  final bool autofocus;
  final bool showAudioRecorder;
  final bool showTextField;
  final int minLines;
  final int maxLines;
  final VoidCallback? onSubmit;
  final Future<void> Function()? onCancel;
  final String submitTooltip;
  final String? submitLabel;
  final IconData submitIcon;

  @override
  State<TicketComposerField> createState() => _TicketComposerFieldState();
}

class _TicketComposerFieldState extends State<TicketComposerField> {
  final List<_ComposerUploadPlaceholder> _uploading = [];
  final Set<String> _removingIds = {};
  final GlobalKey<TicketAudioRecorderButtonState> _audioRecorderKey =
      GlobalKey<TicketAudioRecorderButtonState>();
  bool _showCameraButton = false;
  bool _readingAttachment = false;

  bool get _canEdit => widget.enabled && !widget.isSubmitting;

  TextEditingController? get _textController => widget.controller;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCameraAvailability());
  }

  Future<void> _loadCameraAvailability() async {
    final available = await checkTicketCameraAvailable();
    if (mounted) setState(() => _showCameraButton = available);
  }

  void _syncVoiceClipMarker({required bool voiceSaved}) {
    final controller = _textController;
    if (controller == null) return;
    if (voiceSaved) {
      applyVoiceClipAttachedMarker(controller);
    } else {
      removeVoiceClipAttachedMarker(controller);
    }
  }

  void _handleVoiceRecordingChanged({required bool voiceSaved}) {
    _syncVoiceClipMarker(voiceSaved: voiceSaved);
    widget.onAttachmentsChanged();
  }

  Future<void> _pickFiles() async {
    try {
      if (mounted) setState(() => _readingAttachment = true);
      await Future<void>.delayed(Duration.zero);
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null || !mounted) {
        if (mounted) setState(() => _readingAttachment = false);
        return;
      }

      for (final file in result.files) {
        await _uploadWithPlaceholder(
          fileName: file.name,
          upload: () => widget.attachmentManager.uploadPlatformFile(file),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _readingAttachment = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _capturePhoto() async {
    try {
      if (mounted) setState(() => _readingAttachment = true);
      await Future<void>.delayed(Duration.zero);
      final capture = await captureTicketPhoto();
      if (capture == null || !mounted) {
        if (mounted) setState(() => _readingAttachment = false);
        return;
      }

      await _uploadWithPlaceholder(
        fileName: capture.fileName,
        upload: () => widget.attachmentManager.uploadBytes(
          fileName: capture.fileName,
          mimeType: capture.mimeType,
          bytes: capture.bytes,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _readingAttachment = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _uploadWithPlaceholder({
    required String fileName,
    required Future<void> Function() upload,
  }) async {
    final placeholder = _ComposerUploadPlaceholder(
      id: UniqueKey(),
      fileName: fileName,
    );
    setState(() {
      _uploading.add(placeholder);
      _readingAttachment = false;
    });

    try {
      await upload();
      widget.onAttachmentsChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _uploading.removeWhere((item) => item.id == placeholder.id);
        });
      }
    }
  }

  Future<void> _removeAttachment(PendingTicketAttachment attachment) async {
    if (_removingIds.contains(attachment.attachmentId)) return;

    final wasAudio = attachment.isAudio;
    setState(() => _removingIds.add(attachment.attachmentId));
    try {
      await widget.attachmentManager.removeUnlinked(attachment.attachmentId);
      if (wasAudio) {
        final controller = _textController;
        if (controller != null) removeVoiceClipAttachedMarker(controller);
      }
      widget.onAttachmentsChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _removingIds.remove(attachment.attachmentId));
      }
    }
  }

  Future<void> _openDraftAttachment(PendingTicketAttachment attachment) async {
    if (attachment.isAudio && widget.showAudioRecorder && _canEdit) {
      await _audioRecorderKey.currentState?.openForVoiceClip(attachment);
      return;
    }

    try {
      final download = await widget.attachmentManager.apiClient
          .getTicketAttachmentDownload(attachmentId: attachment.attachmentId);
      final uri = Uri.parse(download.downloadUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not open ${attachment.fileName}.');
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleCancel() async {
    final onCancel = widget.onCancel;
    if (onCancel == null) return;
    await onCancel();
    if (mounted) {
      setState(() {
        _uploading.clear();
        _removingIds.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = AppTheme.primaryAccentText(primary);
    final pending = widget.attachmentManager.attachments;
    final hasAttachmentTiles = pending.isNotEmpty || _uploading.isNotEmpty;
    final isBusyUploading = _uploading.isNotEmpty;
    final isBusyRemoving = _removingIds.isNotEmpty;
    final isBusy = isBusyUploading || isBusyRemoving;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showTextField)
            TextField(
              controller: widget.controller,
              enabled: _canEdit,
              autofocus: widget.autofocus,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              ),
            ),
          if (hasAttachmentTiles) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                widget.showTextField ? 0 : 12,
                12,
                8,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._uploading.map(
                    (item) => _ComposerAttachmentTile(
                      fileName: item.fileName,
                      isBusy: true,
                      busyTooltip: 'Uploading ${item.fileName}…',
                    ),
                  ),
                  ...pending.map((attachment) {
                    final isRemoving = _removingIds.contains(
                      attachment.attachmentId,
                    );
                    final canOpen = !isBusy && !isRemoving;
                    return _ComposerAttachmentTile(
                      fileName: attachment.fileName,
                      mimeType: attachment.mimeType,
                      isBusy: isRemoving,
                      busyTooltip: 'Removing ${attachment.fileName}…',
                      openTooltip: attachment.isAudio
                          ? 'Review voice message'
                          : 'Open ${attachment.fileName}',
                      enabled: _canEdit && !isBusy,
                      onOpen: canOpen
                          ? () => _openDraftAttachment(attachment)
                          : null,
                      onRemove: isRemoving
                          ? null
                          : () => _removeAttachment(attachment),
                    );
                  }),
                ],
              ),
            ),
          ],
          Divider(height: 1, color: primary.withValues(alpha: 0.18)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                if (_showCameraButton)
                  IconButton(
                    tooltip: 'Take photo',
                    onPressed:
                        !_canEdit ||
                            isBusy ||
                            !widget.attachmentManager.canAddMore
                        ? null
                        : _capturePhoto,
                    icon: Icon(Icons.photo_camera_outlined, color: accent),
                  ),
                IconButton(
                  tooltip: 'Add attachment',
                  onPressed:
                      !_canEdit ||
                          isBusy ||
                          !widget.attachmentManager.canAddMore
                      ? null
                      : _pickFiles,
                  icon: Icon(Icons.attach_file, color: accent),
                ),
                if (widget.showAudioRecorder)
                  TicketAudioRecorderButton(
                    key: _audioRecorderKey,
                    attachmentManager: widget.attachmentManager,
                    onChanged: _handleVoiceRecordingChanged,
                    enabled: _canEdit && !isBusy,
                    compact: true,
                  ),
                if (_readingAttachment) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Processing file…',
                    style: TextStyle(
                      fontSize: 12,
                      color: accent.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.onCancel != null)
                  IconButton(
                    tooltip: 'Discard',
                    onPressed: widget.isSubmitting || isBusy
                        ? null
                        : _handleCancel,
                    icon: const Icon(Icons.close, color: Colors.black54),
                  ),
                if (widget.onSubmit != null)
                  widget.submitLabel == null
                      ? IconButton(
                          tooltip: widget.submitTooltip,
                          onPressed: widget.isSubmitting || isBusy
                              ? null
                              : widget.onSubmit,
                          icon: widget.isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(widget.submitIcon, color: accent),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: FilledButton(
                            onPressed: widget.isSubmitting || isBusy
                                ? null
                                : widget.onSubmit,
                            child: widget.isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(widget.submitLabel!),
                          ),
                        ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerUploadPlaceholder {
  const _ComposerUploadPlaceholder({required this.id, required this.fileName});

  final Key id;
  final String fileName;
}

class _ComposerAttachmentTile extends StatelessWidget {
  const _ComposerAttachmentTile({
    required this.fileName,
    this.mimeType,
    this.isBusy = false,
    this.busyTooltip,
    this.openTooltip,
    this.enabled = false,
    this.onOpen,
    this.onRemove,
  });

  final String fileName;
  final String? mimeType;
  final bool isBusy;
  final String? busyTooltip;
  final String? openTooltip;
  final bool enabled;
  final VoidCallback? onOpen;
  final Future<void> Function()? onRemove;

  IconData get _icon {
    final mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('audio/')) return Icons.mic;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.contains('sheet') ||
        mime.contains('excel') ||
        mime.contains('csv')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('word') || mime.contains('document')) {
      return Icons.description_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = AppTheme.primaryAccentText(primary);
    final canOpen = !isBusy && onOpen != null;

    return Tooltip(
      message: isBusy
          ? (busyTooltip ?? fileName)
          : canOpen
          ? (openTooltip ?? fileName)
          : fileName,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: canOpen ? onOpen : null,
                  borderRadius: BorderRadius.circular(10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                      child: Column(
                        children: [
                          if (isBusy)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          else
                            Icon(_icon, size: 20, color: accent),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Text(
                              fileName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                height: 1.15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isBusy && enabled && onRemove != null)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 1,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove!(),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.cancel,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

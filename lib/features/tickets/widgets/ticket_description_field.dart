import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../ticket_attachment_manager.dart';
import '../ticket_models.dart';
import 'ticket_audio_recorder_button.dart';

class TicketDescriptionField extends StatelessWidget {
  const TicketDescriptionField({
    super.key,
    required this.controller,
    required this.attachmentManager,
    required this.onAttachmentsChanged,
    this.labelText = 'Description',
    this.minLines = 4,
    this.enabled = true,
    this.showAudioRecorder = true,
  });

  final TextEditingController controller;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback onAttachmentsChanged;
  final String labelText;
  final int minLines;
  final bool enabled;
  final bool showAudioRecorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: null,
          decoration: InputDecoration(
            labelText: labelText,
            suffixIcon: showAudioRecorder
                ? Icon(Icons.mic_none, color: Theme.of(context).colorScheme.primary)
                : null,
          ),
        ),
        if (showAudioRecorder) ...[
          const SizedBox(height: 8),
          TicketAudioRecorderButton(
            attachmentManager: attachmentManager,
            onChanged: onAttachmentsChanged,
            enabled: enabled,
          ),
        ],
        const SizedBox(height: 12),
        TicketAttachmentPicker(
          attachmentManager: attachmentManager,
          onChanged: onAttachmentsChanged,
          enabled: enabled,
        ),
        if (attachmentManager.attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          TicketAttachmentList(
            attachments: attachmentManager.attachments,
            onRemove: enabled ? onAttachmentsChanged : null,
            attachmentManager: attachmentManager,
          ),
        ],
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
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
                    await attachmentManager.removeUnlinked(attachment.attachmentId);
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
  });

  final TextEditingController controller;
  final TicketAttachmentManager attachmentManager;
  final VoidCallback onAttachmentsChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TicketDescriptionField(
      controller: controller,
      attachmentManager: attachmentManager,
      onAttachmentsChanged: onAttachmentsChanged,
      labelText: 'Comment',
      minLines: 3,
      enabled: enabled,
      showAudioRecorder: true,
    );
  }
}

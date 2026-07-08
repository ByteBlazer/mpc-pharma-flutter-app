import 'dart:async';
import 'dart:io' if (dart.library.html) 'ticket_audio_recorder_web_io.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../ticket_attachment_manager.dart';
import '../ticket_models.dart';

class TicketAudioRecorderButton extends StatefulWidget {
  const TicketAudioRecorderButton({
    super.key,
    required this.attachmentManager,
    required this.onChanged,
    this.enabled = true,
  });

  final TicketAttachmentManager attachmentManager;
  final VoidCallback onChanged;
  final bool enabled;

  @override
  State<TicketAudioRecorderButton> createState() =>
      _TicketAudioRecorderButtonState();
}

class _TicketAudioRecorderButtonState extends State<TicketAudioRecorderButton> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _localPath;
  PendingTicketAttachment? _uploadedAttachment;
  String? _errorMessage;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _isUploading) return;
    if (!await _recorder.hasPermission()) {
      setState(() => _errorMessage = 'Microphone permission is required.');
      return;
    }

    if (_uploadedAttachment != null) {
      await widget.attachmentManager.removeUnlinked(
        _uploadedAttachment!.attachmentId,
      );
    }

    final path = await _recordingPath();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      _errorMessage = null;
      _isRecording = true;
      _elapsedSeconds = 0;
      _localPath = path;
      _uploadedAttachment = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_elapsedSeconds >= TicketAttachmentLimits.maxRecordingSeconds) {
        unawaited(_stopRecording());
        return;
      }
      setState(() => _elapsedSeconds++);
    });
  }

  Future<String> _recordingPath() async {
    final fileName = 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (kIsWeb) return fileName;
    final directory = await getTemporaryDirectory();
    return '${directory.path}/$fileName';
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _localPath = path ?? _localPath;
    });
    await _uploadCurrentRecording();
  }

  Future<List<int>> _readBytes(String path) async {
    if (kIsWeb) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }
      throw Exception('Could not read the recorded audio.');
    }
    return File(path).readAsBytes();
  }

  Future<void> _uploadCurrentRecording() async {
    final path = _localPath;
    if (path == null) return;
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    try {
      final bytes = await _readBytes(path);
      final attachment = await widget.attachmentManager.uploadBytes(
        fileName: 'voice-message.m4a',
        mimeType: 'audio/mp4',
        bytes: bytes,
        isAudio: true,
      );
      if (!mounted) return;
      setState(() => _uploadedAttachment = attachment);
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _playRecording() async {
    final path = _localPath;
    if (path == null) return;
    await _player.stop();
    if (kIsWeb) {
      await _player.play(UrlSource(path));
    } else {
      await _player.play(DeviceFileSource(path));
    }
  }

  Future<void> _discardRecording() async {
    _timer?.cancel();
    if (_isRecording) {
      await _recorder.stop();
    }
    await _player.stop();
    if (_uploadedAttachment != null) {
      await widget.attachmentManager.removeUnlinked(
        _uploadedAttachment!.attachmentId,
      );
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _elapsedSeconds = 0;
      _localPath = null;
      _uploadedAttachment = null;
      _errorMessage = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _localPath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              tooltip: _isRecording ? 'Stop recording' : 'Record voice message',
              onPressed: !widget.enabled || _isUploading
                  ? null
                  : _isRecording
                  ? _stopRecording
                  : _startRecording,
              icon: Icon(
                _isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
              ),
            ),
            if (_isRecording)
              Text(
                '${_elapsedSeconds}s / ${TicketAttachmentLimits.maxRecordingSeconds}s',
                style: const TextStyle(color: Colors.black),
              ),
            if (hasRecording && !_isRecording) ...[
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _playRecording,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _discardRecording,
                icon: const Icon(Icons.refresh),
                label: const Text('Re-record'),
              ),
              if (_isUploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_uploadedAttachment != null)
                const Text(
                  'Voice message attached',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(_errorMessage!, style: const TextStyle(color: Colors.black)),
        ],
      ],
    );
  }
}

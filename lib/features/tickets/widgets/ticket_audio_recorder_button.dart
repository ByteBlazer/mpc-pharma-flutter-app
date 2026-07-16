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
    this.compact = false,
  });

  final TicketAttachmentManager attachmentManager;
  final VoidCallback onChanged;
  final bool enabled;
  final bool compact;

  @override
  State<TicketAudioRecorderButton> createState() =>
      _TicketAudioRecorderButtonState();
}

class _TicketAudioRecorderButtonState extends State<TicketAudioRecorderButton> {
  /// Prefer AAC when available (Safari / native); Opus on Chrome/Firefox; WAV last.
  static const List<AudioEncoder> _encoderPreference = [
    AudioEncoder.aacLc,
    AudioEncoder.opus,
    AudioEncoder.wav,
  ];

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRecording = false;
  bool _isUploading = false;
  String? _localPath;
  AudioEncoder? _activeEncoder;
  PendingTicketAttachment? _uploadedAttachment;
  String? _errorMessage;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<AudioEncoder?> _selectEncoder() async {
    for (final encoder in _encoderPreference) {
      if (await _recorder.isEncoderSupported(encoder)) {
        return encoder;
      }
    }
    return null;
  }

  String _extensionFor(AudioEncoder encoder) {
    return switch (encoder) {
      AudioEncoder.aacLc ||
      AudioEncoder.aacEld ||
      AudioEncoder.aacHe =>
        'm4a',
      AudioEncoder.opus => 'webm',
      AudioEncoder.wav || AudioEncoder.pcm16bits => 'wav',
      AudioEncoder.flac => 'flac',
      AudioEncoder.amrNb || AudioEncoder.amrWb => 'amr',
    };
  }

  String _mimeTypeFor(AudioEncoder encoder) {
    return switch (encoder) {
      AudioEncoder.aacLc ||
      AudioEncoder.aacEld ||
      AudioEncoder.aacHe =>
        'audio/mp4',
      AudioEncoder.opus => 'audio/webm',
      AudioEncoder.wav || AudioEncoder.pcm16bits => 'audio/wav',
      AudioEncoder.flac => 'audio/flac',
      AudioEncoder.amrNb => 'audio/AMR',
      AudioEncoder.amrWb => 'audio/AMR-WB',
    };
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || _isUploading) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        setState(() => _errorMessage = 'Microphone permission is required.');
        return;
      }

      final encoder = await _selectEncoder();
      if (encoder == null) {
        if (!mounted) return;
        setState(
          () => _errorMessage =
              'Voice recording is not supported in this browser.',
        );
        return;
      }

      if (_uploadedAttachment != null) {
        await widget.attachmentManager.removeUnlinked(
          _uploadedAttachment!.attachmentId,
        );
      }

      final path = await _recordingPath(encoder);
      await _recorder.start(
        RecordConfig(encoder: encoder),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _isRecording = true;
        _elapsedSeconds = 0;
        _localPath = path;
        _activeEncoder = encoder;
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _errorMessage =
            'Could not start recording. Try another browser or device mic.';
      });
    }
  }

  Future<String> _recordingPath(AudioEncoder encoder) async {
    final fileName =
        'voice-${DateTime.now().millisecondsSinceEpoch}.${_extensionFor(encoder)}';
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
    final encoder = _activeEncoder ?? AudioEncoder.aacLc;
    if (path == null) return;
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });
    try {
      final bytes = await _readBytes(path);
      final extension = _extensionFor(encoder);
      final attachment = await widget.attachmentManager.uploadBytes(
        fileName: 'voice-message.$extension',
        mimeType: _mimeTypeFor(encoder),
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
      _activeEncoder = null;
      _uploadedAttachment = null;
      _errorMessage = null;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _localPath != null;
    final primary = Theme.of(context).colorScheme.primary;

    final micButton = IconButton(
      tooltip: _isRecording ? 'Stop recording' : 'Record voice message',
      onPressed: !widget.enabled || _isUploading
          ? null
          : _isRecording
          ? _stopRecording
          : _startRecording,
      icon: Icon(
        _isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
        color: _isRecording ? Colors.red : primary,
      ),
    );

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          micButton,
          if (_isRecording)
            Text(
              '$_elapsedSeconds s',
              style: const TextStyle(color: Colors.black, fontSize: 12),
            ),
          if (hasRecording && !_isRecording) ...[
            IconButton(
              tooltip: 'Play recording',
              onPressed: _isUploading ? null : _playRecording,
              icon: const Icon(Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Re-record',
              onPressed: _isUploading ? null : _discardRecording,
              icon: const Icon(Icons.refresh),
            ),
            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            micButton,
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

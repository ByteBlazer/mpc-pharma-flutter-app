import 'dart:async';
import 'dart:io' if (dart.library.html) 'ticket_audio_recorder_web_io.dart';
import 'dart:math' as math;

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

  /// Unused; kept for call-site compatibility.
  final bool compact;

  @override
  State<TicketAudioRecorderButton> createState() =>
      _TicketAudioRecorderButtonState();
}

class _TicketAudioRecorderButtonState extends State<TicketAudioRecorderButton> {
  PendingTicketAttachment? _uploadedAttachment;
  String? _localPath;
  AudioEncoder? _activeEncoder;
  Duration _voiceDuration = Duration.zero;

  bool get _hasVoiceInManager {
    final current = _uploadedAttachment;
    if (current == null) return false;
    return widget.attachmentManager.attachments.any(
      (attachment) => attachment.attachmentId == current.attachmentId,
    );
  }

  bool get _hasVoice => _hasVoiceInManager;

  /// Chip X removes the file from the manager; clear our local review state too.
  void _syncWithAttachmentManager() {
    if (_uploadedAttachment == null) return;
    if (_hasVoiceInManager) return;
    _uploadedAttachment = null;
    _localPath = null;
    _activeEncoder = null;
    _voiceDuration = Duration.zero;
  }

  Future<void> _openModal() async {
    if (!widget.enabled) return;
    _syncWithAttachmentManager();

    final result = await showDialog<_VoiceSessionResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _TicketVoiceRecordingDialog(
        attachmentManager: widget.attachmentManager,
        existingAttachment: _uploadedAttachment,
        existingLocalPath: _localPath,
        existingEncoder: _activeEncoder,
        existingDuration: _voiceDuration,
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _uploadedAttachment = result.attachment;
      _localPath = result.localPath;
      _activeEncoder = result.encoder;
      _voiceDuration = result.duration;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // Keep badge in sync when the attachment chip was removed elsewhere.
    final hadStaleLocalState =
        _uploadedAttachment != null && !_hasVoiceInManager;
    if (hadStaleLocalState) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_syncWithAttachmentManager);
      });
    }

    final primary = Theme.of(context).colorScheme.primary;

    return IconButton(
      tooltip: _hasVoice ? 'Review voice message' : 'Record voice message',
      onPressed: widget.enabled ? _openModal : null,
      icon: Badge(
        isLabelVisible: _hasVoice,
        smallSize: 8,
        backgroundColor: primary,
        child: Icon(Icons.mic_none, color: primary),
      ),
    );
  }
}

class _VoiceSessionResult {
  const _VoiceSessionResult({
    this.attachment,
    this.localPath,
    this.encoder,
    this.duration = Duration.zero,
  });

  final PendingTicketAttachment? attachment;
  final String? localPath;
  final AudioEncoder? encoder;
  final Duration duration;
}

enum _VoiceModalPhase { recording, uploading, saved, review, error }

class _TicketVoiceRecordingDialog extends StatefulWidget {
  const _TicketVoiceRecordingDialog({
    required this.attachmentManager,
    this.existingAttachment,
    this.existingLocalPath,
    this.existingEncoder,
    this.existingDuration = Duration.zero,
  });

  final TicketAttachmentManager attachmentManager;
  final PendingTicketAttachment? existingAttachment;
  final String? existingLocalPath;
  final AudioEncoder? existingEncoder;
  final Duration existingDuration;

  @override
  State<_TicketVoiceRecordingDialog> createState() =>
      _TicketVoiceRecordingDialogState();
}

class _TicketVoiceRecordingDialogState extends State<_TicketVoiceRecordingDialog> {
  static const List<AudioEncoder> _encoderPreference = [
    AudioEncoder.aacLc,
    AudioEncoder.opus,
    AudioEncoder.wav,
  ];
  static const int _waveformBarCount = 18;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Amplitude>? _amplitudeSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  Timer? _timer;
  int _elapsedSeconds = 0;
  /// Instant mic level (0..1) for the live waveform.
  double _liveLevel = 0.08;
  /// Rolling peak (dBFS) so quiet mics still fill the waveform.
  double _amplitudePeakDb = -45;

  late _VoiceModalPhase _phase;
  String? _localPath;
  AudioEncoder? _activeEncoder;
  PendingTicketAttachment? _uploadedAttachment;
  String? _errorMessage;
  bool _isClosing = false;
  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _listenPlayer();

    final hasExisting = widget.existingAttachment != null;
    if (hasExisting) {
      _phase = _VoiceModalPhase.review;
      _uploadedAttachment = widget.existingAttachment;
      _localPath = widget.existingLocalPath;
      _activeEncoder = widget.existingEncoder;
      _playbackDuration = widget.existingDuration;
    } else {
      _phase = _VoiceModalPhase.recording;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startRecording());
      });
    }
  }

  void _listenPlayer() {
    _positionSub = _player.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _playbackPosition = position);
    });
    _durationSub = _player.onDurationChanged.listen((duration) {
      if (!mounted || duration <= Duration.zero) return;
      setState(() => _playbackDuration = duration);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playbackPosition = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_amplitudeSub?.cancel() ?? Future<void>.value());
    unawaited(_positionSub?.cancel() ?? Future<void>.value());
    unawaited(_durationSub?.cancel() ?? Future<void>.value());
    unawaited(_completeSub?.cancel() ?? Future<void>.value());
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  void _resetWaveform() {
    _liveLevel = 0.08;
    _amplitudePeakDb = -45;
  }

  void _updateLiveLevel(double level) {
    setState(() => _liveLevel = level.clamp(0.08, 1.0));
  }

  /// Map analyser dBFS (~-160..0) into a punchy 0..1 UI level.
  double _normalizeAmplitude(double db) {
    // Browser analyser speech is often around -70..-25, not near 0.
    const noiseFloorDb = -90.0;
    const loudDb = -20.0;

    if (db > _amplitudePeakDb) {
      _amplitudePeakDb = db;
    } else {
      // Slow decay so a shout doesn't permanently flatten quieter speech.
      _amplitudePeakDb = (_amplitudePeakDb * 0.97) + (db * 0.03);
    }

    final peakCeiling = math.max(_amplitudePeakDb, loudDb);
    final span = math.max(peakCeiling - noiseFloorDb, 25.0);
    final linear = ((db - noiseFloorDb) / span).clamp(0.0, 1.0);

    // Expand mid levels so normal speech is clearly visible.
    final boosted = math.pow(linear, 0.45).toDouble();
    return boosted.clamp(0.08, 1.0);
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

  Future<String> _recordingPath(AudioEncoder encoder) async {
    final fileName =
        'voice-${DateTime.now().millisecondsSinceEpoch}.${_extensionFor(encoder)}';
    if (kIsWeb) return fileName;
    final directory = await getTemporaryDirectory();
    return '${directory.path}/$fileName';
  }

  Future<void> _startRecording({bool replacing = false}) async {
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        setState(() {
          _phase = _VoiceModalPhase.error;
          _errorMessage = 'Microphone permission is required.';
        });
        return;
      }

      final encoder = await _selectEncoder();
      if (encoder == null) {
        if (!mounted) return;
        setState(() {
          _phase = _VoiceModalPhase.error;
          _errorMessage = 'Voice recording is not supported in this browser.';
        });
        return;
      }

      if (replacing && _uploadedAttachment != null) {
        await widget.attachmentManager.removeUnlinked(
          _uploadedAttachment!.attachmentId,
        );
      }

      await _player.stop();
      await _amplitudeSub?.cancel();

      final path = await _recordingPath(encoder);
      await _recorder.start(RecordConfig(encoder: encoder), path: path);

      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 60))
          .listen((amplitude) {
        if (!mounted) return;
        _updateLiveLevel(_normalizeAmplitude(amplitude.current));
      });

      if (!mounted) return;
      setState(() {
        _phase = _VoiceModalPhase.recording;
        _errorMessage = null;
        _elapsedSeconds = 0;
        _localPath = path;
        _activeEncoder = encoder;
        _uploadedAttachment = null;
        _resetWaveform();
      });

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_elapsedSeconds >= TicketAttachmentLimits.maxRecordingSeconds) {
          unawaited(_stopAndSave());
          return;
        }
        setState(() => _elapsedSeconds++);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceModalPhase.error;
        _errorMessage =
            'Could not start recording. Try another browser or device mic.';
      });
    }
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

  Future<void> _stopAndSave() async {
    if (_phase == _VoiceModalPhase.uploading ||
        _phase == _VoiceModalPhase.saved) {
      return;
    }

    _timer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;

    final path = await _recorder.stop();
    if (!mounted) return;

    final resolvedPath = path ?? _localPath;
    if (resolvedPath == null) {
      setState(() {
        _phase = _VoiceModalPhase.error;
        _errorMessage = 'No audio was captured. Please try again.';
      });
      return;
    }

    setState(() {
      _phase = _VoiceModalPhase.uploading;
      _localPath = resolvedPath;
      _errorMessage = null;
    });

    try {
      final encoder = _activeEncoder ?? AudioEncoder.wav;
      final bytes = await _readBytes(resolvedPath);
      final extension = _extensionFor(encoder);
      final attachment = await widget.attachmentManager.uploadBytes(
        fileName: 'voice-message.$extension',
        mimeType: _mimeTypeFor(encoder),
        bytes: bytes,
        isAudio: true,
      );
      if (!mounted) return;
      setState(() {
        _uploadedAttachment = attachment;
        _playbackDuration = _recordedDuration;
        _phase = _VoiceModalPhase.saved;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      if (!mounted || _isClosing) return;
      _finish(
        _VoiceSessionResult(
          attachment: attachment,
          localPath: resolvedPath,
          encoder: encoder,
          duration: _playbackDuration,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _VoiceModalPhase.error;
        _errorMessage = error.toString();
      });
    }
  }

  Duration get _recordedDuration {
    if (_playbackDuration > Duration.zero) return _playbackDuration;
    if (_elapsedSeconds > 0) return Duration(seconds: _elapsedSeconds);
    return widget.existingDuration;
  }

  Future<void> _togglePlayback() async {
    final path = _localPath;
    if (path == null) return;

    final state = _player.state;
    if (state == PlayerState.playing) {
      await _player.pause();
      if (!mounted) return;
      setState(() => _isPlaying = false);
      return;
    }

    if (state == PlayerState.paused) {
      await _player.resume();
      if (!mounted) return;
      setState(() => _isPlaying = true);
      return;
    }

    if (_playbackPosition > Duration.zero &&
        _playbackDuration > Duration.zero &&
        _playbackPosition >= _playbackDuration) {
      await _player.seek(Duration.zero);
    }

    if (kIsWeb) {
      await _player.play(UrlSource(path));
    } else {
      await _player.play(DeviceFileSource(path));
    }
    if (!mounted) return;
    setState(() => _isPlaying = true);
  }

  Future<void> _seekPlayback(double milliseconds) async {
    final target = Duration(milliseconds: milliseconds.round());
    await _player.seek(target);
    if (!mounted) return;
    setState(() => _playbackPosition = target);
  }

  Future<void> _reRecord() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
    });
    await _startRecording(replacing: true);
  }

  Future<void> _discard() async {
    _timer?.cancel();
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    if (_phase == _VoiceModalPhase.recording) {
      await _recorder.stop();
    }
    await _player.stop();
    if (_uploadedAttachment != null) {
      await widget.attachmentManager.removeUnlinked(
        _uploadedAttachment!.attachmentId,
      );
    }
    _finish(const _VoiceSessionResult());
  }

  void _finish(_VoiceSessionResult result) {
    if (_isClosing || !mounted) return;
    _isClosing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _handleDismissRequest() async {
    if (_isClosing) return;

    switch (_phase) {
      case _VoiceModalPhase.recording:
        await _stopAndSave();
      case _VoiceModalPhase.uploading:
      case _VoiceModalPhase.saved:
        // Wait for upload / saved close to finish.
        break;
      case _VoiceModalPhase.review:
        await _player.stop();
        _finish(
          _VoiceSessionResult(
            attachment: _uploadedAttachment,
            localPath: _localPath,
            encoder: _activeEncoder,
            duration: _recordedDuration,
          ),
        );
      case _VoiceModalPhase.error:
        _finish(
          _VoiceSessionResult(
            attachment: _uploadedAttachment,
            localPath: _localPath,
            encoder: _activeEncoder,
            duration: _recordedDuration,
          ),
        );
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 9999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final maxSeconds = TicketAttachmentLimits.maxRecordingSeconds;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(_handleDismissRequest());
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: Row(
          children: [
            Expanded(
              child: Text(
                switch (_phase) {
                  _VoiceModalPhase.recording => 'Recording',
                  _VoiceModalPhase.uploading => 'Saving…',
                  _VoiceModalPhase.saved => 'Saved',
                  _VoiceModalPhase.review => 'Voice message',
                  _VoiceModalPhase.error => 'Recording',
                },
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: _phase == _VoiceModalPhase.uploading ||
                      _phase == _VoiceModalPhase.saved
                  ? null
                  : () => unawaited(_handleDismissRequest()),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_phase == _VoiceModalPhase.recording) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RecordingDot(),
                    SizedBox(width: 8),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _LiveWaveform(
                        level: _liveLevel,
                        barCount: _waveformBarCount,
                        color: Colors.redAccent,
                        height: 64,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _RecordingTimerRing(
                      elapsedSeconds: _elapsedSeconds,
                      maxSeconds: maxSeconds,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Speak now. Tap Stop to save, or Discard to cancel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ] else if (_phase == _VoiceModalPhase.uploading) ...[
                const SizedBox(height: 12),
                CircularProgressIndicator(color: primary),
                const SizedBox(height: 16),
                const Text(
                  'Uploading your voice message…',
                  textAlign: TextAlign.center,
                ),
              ] else if (_phase == _VoiceModalPhase.saved) ...[
                const SizedBox(height: 8),
                Icon(Icons.check_circle, color: primary, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'Voice message saved',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ] else if (_phase == _VoiceModalPhase.review) ...[
                _VoiceTrackPlayer(
                  isPlaying: _isPlaying,
                  position: _playbackPosition,
                  duration: _recordedDuration,
                  enabled: _localPath != null,
                  onTogglePlay: () => unawaited(_togglePlayback()),
                  onSeek: (seconds) => unawaited(_seekPlayback(seconds)),
                  formatDuration: _formatDuration,
                ),
              ] else ...[
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Something went wrong.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_phase == _VoiceModalPhase.recording) ...[
            TextButton(
              onPressed: () => unawaited(_discard()),
              child: const Text('Discard'),
            ),
            FilledButton.icon(
              onPressed: () => unawaited(_stopAndSave()),
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
              ),
            ),
          ]
          else if (_phase == _VoiceModalPhase.review) ...[
            TextButton(
              onPressed: () => unawaited(_discard()),
              child: const Text('Discard'),
            ),
            FilledButton.icon(
              onPressed: () => unawaited(_reRecord()),
              icon: const Icon(Icons.refresh),
              label: const Text('Re-record'),
            ),
          ] else if (_phase == _VoiceModalPhase.error) ...[
            TextButton(
              onPressed: () => _finish(
                _VoiceSessionResult(
                  attachment: _uploadedAttachment,
                  localPath: _localPath,
                  encoder: _activeEncoder,
                  duration: _recordedDuration,
                ),
              ),
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () => unawaited(_startRecording(replacing: true)),
              child: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceTrackPlayer extends StatelessWidget {
  const _VoiceTrackPlayer({
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.enabled,
    required this.onTogglePlay,
    required this.onSeek,
    required this.formatDuration,
  });

  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final bool enabled;
  final VoidCallback onTogglePlay;
  final ValueChanged<double> onSeek;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final totalMs = math.max(duration.inMilliseconds, 1).toDouble();
    final positionMs =
        position.inMilliseconds.clamp(0, totalMs.round()).toDouble();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            IconButton(
              tooltip: isPlaying ? 'Pause' : 'Play',
              onPressed: enabled ? onTogglePlay : null,
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                size: 40,
                color: primary,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Slider(
                      value: positionMs.clamp(0, totalMs),
                      max: totalMs,
                      onChanged: enabled ? onSeek : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          formatDuration(position),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatDuration(duration),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingDot extends StatefulWidget {
  const _RecordingDot();

  @override
  State<_RecordingDot> createState() => _RecordingDotState();
}

class _RecordingDotState extends State<_RecordingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _RecordingTimerRing extends StatelessWidget {
  const _RecordingTimerRing({
    required this.elapsedSeconds,
    required this.maxSeconds,
  });

  final int elapsedSeconds;
  final int maxSeconds;
  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final progress =
        maxSeconds <= 0 ? 0.0 : (elapsedSeconds / maxSeconds).clamp(0.0, 1.0);

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: _size,
            height: _size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
              color: Colors.redAccent,
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${elapsedSeconds}s',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveWaveform extends StatefulWidget {
  const _LiveWaveform({
    required this.level,
    required this.barCount,
    required this.color,
    this.height = 110,
  });

  final double level;
  final int barCount;
  final Color color;
  final double height;

  @override
  State<_LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<_LiveWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.color.withValues(alpha: 0.18)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _LiveWavePainter(
                  level: widget.level,
                  barCount: widget.barCount,
                  color: widget.color,
                  phase: _controller.value * math.pi * 2,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LiveWavePainter extends CustomPainter {
  _LiveWavePainter({
    required this.level,
    required this.barCount,
    required this.color,
    required this.phase,
  });

  final double level;
  final int barCount;
  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final gap = 3.0;
    final totalGap = gap * (barCount - 1);
    final barWidth = ((size.width - totalGap) / barCount).clamp(3.0, 10.0);
    final drawnWidth = (barWidth * barCount) + totalGap;
    final startX = (size.width - drawnWidth) / 2;
    final midY = size.height / 2;
    final maxBarHeight = size.height * 0.95;
    final center = (barCount - 1) / 2.0;

    for (var i = 0; i < barCount; i++) {
      // Center-weighted envelope so the middle reacts strongest.
      final distance = (i - center).abs() / center;
      final envelope = (1.0 - (distance * 0.55)).clamp(0.35, 1.0);

      // Instant mic level, with light phase motion so bars feel live (not a timeline).
      final wobble = 0.55 +
          (0.45 *
              math.sin(phase * (1.6 + distance) + i * 0.55).abs());
      final barLevel = (level * envelope * wobble).clamp(0.08, 1.0);
      final barHeight = (maxBarHeight * barLevel).clamp(6.0, maxBarHeight);
      final x = startX + (i * (barWidth + gap));
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + (barWidth / 2), midY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveWavePainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.phase != phase ||
        oldDelegate.color != color ||
        oldDelegate.barCount != barCount;
  }
}

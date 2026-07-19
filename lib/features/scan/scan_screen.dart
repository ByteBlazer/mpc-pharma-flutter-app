import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'scan_models.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _requiredConsecutiveScans = 3;
  static const _maxBarcodeLength = 50;

  final _audioPlayer = AudioPlayer();
  MobileScannerController? _scannerController;

  bool _scanMode = true; // true = SCAN, false = UNSCAN
  bool _isScanning = false;
  bool _isLoading = false;
  bool _permissionDeniedForever = false;

  String? _pendingBarcode;
  String? _lastApiBarcode;
  String? _consecutiveValue;
  int _consecutiveCount = 0;

  ScanDocResult? _bannerResult;
  Timer? _bannerTimer;
  bool _showingUnscanDialog = false;

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _audioPlayer.dispose();
    _scannerController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _ensureScannerController() async {
    // Desktop/web webcams are typically user-facing. Requesting
    // CameraFacing.back (environment) often fails with NotFoundError in Chrome
    // even when Cheese/OS can open the same camera.
    _scannerController ??= MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
      autoStart: false,
    );
  }

  Future<bool> _requestCameraPermission() async {
    if (kIsWeb) return true;

    var status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _permissionDeniedForever = false);
      return true;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      setState(() => _permissionDeniedForever = true);
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera permission needed'),
          content: const Text(
            'Camera access is permanently denied. Open app settings to allow '
            'camera so you can scan barcodes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
      return false;
    }

    status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() => _permissionDeniedForever = false);
      return true;
    }
    if (status.isPermanentlyDenied) {
      setState(() => _permissionDeniedForever = true);
    }
    if (mounted) {
      showAppSnackBar(
        context,
        message: 'Camera permission is required to scan barcodes.',
        type: AppSnackBarType.warning,
      );
    }
    return false;
  }

  Future<void> _toggleScanning() async {
    if (_isLoading) return;

    if (_isScanning) {
      await _stopScanning();
      return;
    }

    final allowed = await _requestCameraPermission();
    if (!allowed || !mounted) return;

    await _ensureScannerController();
    if (!mounted) return;

    // MobileScanner must be in the tree before start(); otherwise the
    // controller times out as not attached (often shown as a camera error).
    setState(() {
      _isScanning = true;
      _consecutiveValue = null;
      _consecutiveCount = 0;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    try {
      await _scannerController!.start();
      await WakelockPlus.enable();
    } catch (error) {
      if (!mounted) return;
      await _stopScanning();
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Could not start camera: $error',
        type: AppSnackBarType.error,
      );
    }
  }

  Future<void> _stopScanning() async {
    try {
      await _scannerController?.stop();
    } catch (_) {}
    await WakelockPlus.disable();
    if (!mounted) return;
    setState(() {
      _isScanning = false;
      _consecutiveValue = null;
      _consecutiveCount = 0;
    });
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (!_isScanning || _isLoading || _pendingBarcode != null) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) {
      _consecutiveValue = null;
      _consecutiveCount = 0;
      return;
    }

    if (_consecutiveValue == raw) {
      _consecutiveCount += 1;
    } else {
      _consecutiveValue = raw;
      _consecutiveCount = 1;
    }

    if (_consecutiveCount >= _requiredConsecutiveScans) {
      _acceptBarcode(raw);
    }
  }

  void _acceptBarcode(String barcode) {
    final value = barcode.trim();
    if (value.isEmpty) return;
    if (value.length > _maxBarcodeLength) {
      _showBanner(
        const ScanDocResult(
          statusCode: 400,
          success: false,
          message: 'Barcode is too long (max 50 characters).',
        ),
      );
      return;
    }
    if (_lastApiBarcode == value && _isLoading) return;
    if (_lastApiBarcode == value && _pendingBarcode == value) return;

    setState(() {
      _pendingBarcode = value;
      _consecutiveValue = null;
      _consecutiveCount = 0;
    });
    _submitBarcode(value);
  }

  Future<void> _submitBarcode(String barcode) async {
    if (_lastApiBarcode == barcode && _isLoading) return;
    setState(() {
      _isLoading = true;
      _lastApiBarcode = barcode;
      _bannerResult = null;
    });
    _bannerTimer?.cancel();

    // Pause camera preview while API runs.
    if (_isScanning) {
      try {
        await _scannerController?.stop();
      } catch (_) {}
    }

    try {
      final result = await widget.apiClient.scanDoc(
        barcode: barcode,
        unscan: !_scanMode,
      );
      if (!mounted) return;
      await _handleResult(result);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString();
      if (_isAuthError(text)) {
        showAppSnackBar(
          context,
          message: text,
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      await _handleResult(ScanDocResult.unreachable());
    }
  }

  bool _isAuthError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('unauthorized') ||
        normalized.contains('forbidden') ||
        normalized.contains('token') ||
        normalized.contains('expired');
  }

  Future<void> _handleResult(ScanDocResult result) async {
    setState(() => _isLoading = false);

    if (result.isUiSuccess) {
      await _playFeedback(success: true);
      if (!_scanMode) {
        await _showUnscanSuccessDialog(result);
      } else {
        _showBanner(result, autoClear: const Duration(seconds: 2));
      }
    } else {
      await _playFeedback(success: false);
      _showBanner(result, autoClear: const Duration(seconds: 3));
    }
  }

  Future<void> _playFeedback({required bool success}) async {
    try {
      if (success) {
        await HapticFeedback.mediumImpact();
        await _audioPlayer.play(AssetSource('sounds/scan_success.wav'));
      } else {
        await HapticFeedback.heavyImpact();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await HapticFeedback.vibrate();
        await _audioPlayer.play(AssetSource('sounds/scan_error.wav'));
      }
    } catch (_) {
      // Sound/haptics are best-effort.
    }
  }

  void _showBanner(ScanDocResult result, {Duration? autoClear}) {
    _bannerTimer?.cancel();
    setState(() => _bannerResult = result);
    if (autoClear != null) {
      _bannerTimer = Timer(autoClear, () {
        if (!mounted) return;
        setState(() {
          _bannerResult = null;
          _pendingBarcode = null;
          _lastApiBarcode = null;
        });
        _resumeCameraIfNeeded();
      });
    }
  }

  Future<void> _showUnscanSuccessDialog(ScanDocResult result) async {
    if (_showingUnscanDialog) return;
    _showingUnscanDialog = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Unscan successful'),
        content: Text(result.displayMessage),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    _showingUnscanDialog = false;
    if (!mounted) return;
    setState(() {
      _scanMode = true;
      _pendingBarcode = null;
      _lastApiBarcode = null;
      _bannerResult = null;
    });
    await _resumeCameraIfNeeded();
  }

  Future<void> _resumeCameraIfNeeded() async {
    if (!_isScanning || _isLoading) return;
    try {
      await _ensureScannerController();
      await _scannerController!.start();
    } catch (_) {}
  }

  Future<void> _openManualEntry() async {
    if (_isLoading) return;
    final submitted = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _ManualBarcodeSheet(),
    );
    if (submitted == null) return;
    final value = submitted.trim();
    if (value.isEmpty) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Enter a barcode first.',
        type: AppSnackBarType.warning,
      );
      return;
    }
    _acceptBarcode(value);
  }

  Color _bannerColor(ScanDocResult result) {
    if (result.isUiSuccess) return const Color(0xFF2E7D32);
    if (result.isUiHardError) return const Color(0xFFC62828);
    return const Color(0xFFB26A00);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(title: const Text('Scan')),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        _ScanModeToggle(
                          scanMode: _scanMode,
                          enabled: !_isLoading,
                          onChanged: (scanMode) {
                            setState(() => _scanMode = scanMode);
                          },
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _scanMode
                                        ? primary.withValues(alpha: 0.25)
                                        : Colors.red.shade400,
                                    width: _scanMode ? 1.5 : 3,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: _buildCameraCard(primary),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isLoading ? null : _toggleScanning,
                            icon: Icon(
                              _isScanning
                                  ? Icons.stop_circle_outlined
                                  : Icons.play_circle_outline,
                            ),
                            label: Text(_isScanning ? 'STOP' : 'START'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isLoading ? null : _openManualEntry,
                          child: const Text('Enter barcode manually'),
                        ),
                        if (_permissionDeniedForever)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextButton(
                              onPressed: openAppSettings,
                              child: const Text('Open app settings'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_bannerResult != null)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 12,
                  child: _ScanResultBanner(
                    result: _bannerResult!,
                    color: _bannerColor(_bannerResult!),
                    onClose: () {
                      _bannerTimer?.cancel();
                      setState(() {
                        _bannerResult = null;
                        _pendingBarcode = null;
                        _lastApiBarcode = null;
                      });
                      _resumeCameraIfNeeded();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCard(Color primary) {
    if (_isLoading) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: 0.04),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isScanning && _scannerController != null) {
      return MobileScanner(
        controller: _scannerController!,
        onDetect: _onBarcodeDetect,
      );
    }

    return ColoredBox(
      color: AppTheme.gradientPageSurfaceFill(primary),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _scanMode ? 'Press START to scan' : 'Press START to unscan',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanModeToggle extends StatelessWidget {
  const _ScanModeToggle({
    required this.scanMode,
    required this.enabled,
    required this.onChanged,
  });

  final bool scanMode;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AppSurface(
      borderRadius: 14,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            Expanded(
              child: _ModeChip(
                label: 'SCAN',
                selected: scanMode,
                color: primary,
                enabled: enabled,
                onTap: () => onChanged(true),
              ),
            ),
            Expanded(
              child: _ModeChip(
                label: 'UNSCAN',
                selected: !scanMode,
                color: Colors.red.shade700,
                enabled: enabled,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanResultBanner extends StatelessWidget {
  const _ScanResultBanner({
    required this.result,
    required this.color,
    required this.onClose,
  });

  final ScanDocResult result;
  final Color color;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 5)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                result.displayMessage,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualBarcodeSheet extends StatefulWidget {
  const _ManualBarcodeSheet();

  @override
  State<_ManualBarcodeSheet> createState() => _ManualBarcodeSheetState();
}

class _ManualBarcodeSheetState extends State<_ManualBarcodeSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter barcode manually',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: _ScanScreenState._maxBarcodeLength,
              decoration: const InputDecoration(
                labelText: 'Barcode',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: const Text('GO'),
            ),
          ],
        ),
      ),
    );
  }
}

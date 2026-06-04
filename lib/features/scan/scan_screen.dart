import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../../config/app_config.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  MobileScannerController? _controller;
  bool _scanning = false;
  bool _unscanMode = false;
  bool _loading = false;
  String? _lastBarcode;
  int _consecutiveCount = 0;
  final List<ScanDocSuccessResponse> _recentScans = [];

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required to scan')),
      );
    }
  }

  Future<void> _toggleScanning() async {
    if (!_scanning) {
      await _ensureCamera();
      _controller ??= MobileScannerController(detectionSpeed: DetectionSpeed.normal);
      setState(() {
        _scanning = true;
        _lastBarcode = null;
        _consecutiveCount = 0;
      });
    } else {
      await _controller?.stop();
      setState(() => _scanning = false);
    }
  }

  Future<void> _processBarcode(String barcode) async {
    if (_loading) return;
    if (_lastBarcode == barcode) {
      _consecutiveCount++;
    } else {
      _lastBarcode = barcode;
      _consecutiveCount = 1;
    }

    if (_consecutiveCount < AppConfig.requiredConsecutiveScans) return;

    setState(() {
      _loading = true;
      _consecutiveCount = 0;
      _lastBarcode = null;
    });

    try {
      final result = await ref.read(apiClientProvider).scanDoc(
            barcode: barcode,
            unscan: _unscanMode,
          );
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: 100);
      }
      setState(() => _recentScans.insert(0, result));
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? 'Success' : 'Failed'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manualEntry() async {
    final controller = TextEditingController();
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter barcode manually'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (barcode != null && barcode.isNotEmpty) {
      await _processBarcode(barcode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Scan')),
              ButtonSegment(value: true, label: Text('Unscan')),
            ],
            selected: {_unscanMode},
            onSelectionChanged: (value) {
              setState(() => _unscanMode = value.first);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _toggleScanning,
                  icon: Icon(_scanning ? Icons.pause : Icons.play_arrow),
                  label: Text(_scanning ? 'Stop Scan' : 'Start Scan'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _loading ? null : _manualEntry,
                child: const Text('Manual'),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _scanning && _controller != null
              ? MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;
                    final value = barcodes.first.rawValue;
                    if (value != null && value.isNotEmpty) {
                      _processBarcode(value);
                    }
                  },
                )
              : const EmptyState(message: 'Press start to scan'),
        ),
        if (_recentScans.isNotEmpty)
          SizedBox(
            height: 140,
            child: ListView.builder(
              itemCount: _recentScans.length,
              itemBuilder: (context, index) {
                final scan = _recentScans[index];
                return ListTile(
                  dense: true,
                  title: Text(scan.docId),
                  subtitle: Text(scan.message),
                  leading: Icon(
                    scan.success ? Icons.check_circle : Icons.error,
                    color: scan.success ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

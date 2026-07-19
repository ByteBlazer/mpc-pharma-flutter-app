import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';

import '../../api/api_client.dart';
import '../../utils/geo_distance.dart';
import '../../widgets/app_snack_bar.dart';
import 'my_trips_models.dart';

Future<bool> showMarkDeliveredSheet({
  required BuildContext context,
  required ApiClient apiClient,
  required int tripId,
  required List<TripDoc> docs,
  required Future<void> Function() onLoginAgain,
}) async {
  if (docs.isEmpty) return false;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => MarkDeliveredSheet(
      apiClient: apiClient,
      tripId: tripId,
      docs: docs,
      onLoginAgain: onLoginAgain,
    ),
  );
  return result == true;
}

class MarkDeliveredSheet extends StatefulWidget {
  const MarkDeliveredSheet({
    super.key,
    required this.apiClient,
    required this.tripId,
    required this.docs,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final int tripId;
  final List<TripDoc> docs;
  final Future<void> Function() onLoginAgain;

  @override
  State<MarkDeliveredSheet> createState() => _MarkDeliveredSheetState();
}

class _MarkDeliveredSheetState extends State<MarkDeliveredSheet> {
  final _commentController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  bool _updateCustomerLocation = true;
  bool _submitting = false;
  bool _loadingRecent = true;
  String? _proximityWarning;
  String? _reusedSignatureBase64;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final first = widget.docs.first;
    try {
      final recent = await widget.apiClient.getRecentSignature(
        tripId: widget.tripId,
        docId: first.id,
      );
      if (recent.found && recent.signatureBase64.isNotEmpty) {
        _reusedSignatureBase64 = recent.signatureBase64;
      }
    } catch (_) {}

    if (first.hasCustomerGeo) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        final meters = haversineDistanceMeters(
          lat1: position.latitude,
          lon1: position.longitude,
          lat2: first.customerLat!,
          lon2: first.customerLng!,
        );
        if (meters > 500) {
          _proximityWarning =
              'You appear more than 500 m from this customer’s usual delivery '
              'location (${meters.round()} m away). You can still submit.';
        }
      } catch (_) {
        _proximityWarning =
            'Could not check distance to the customer location right now.';
      }
    }

    if (mounted) setState(() => _loadingRecent = false);
  }

  Future<void> _clearSignature() async {
    _signatureController.clear();
    setState(() => _reusedSignatureBase64 = null);
  }

  Future<String?> _resolveSignatureBase64() async {
    if (_reusedSignatureBase64 != null &&
        _reusedSignatureBase64!.isNotEmpty &&
        !_signatureController.isNotEmpty) {
      return _reusedSignatureBase64;
    }
    if (!_signatureController.isNotEmpty) return null;
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) return null;
    return encodeSignatureBytes(bytes);
  }

  Future<void> _submit() async {
    final signature = await _resolveSignatureBase64();
    if (signature == null || signature.isEmpty) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: 'Signature is mandatory',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    var updateLocation = _updateCustomerLocation;
    double? lat;
    double? lng;

    if (updateLocation) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
        lat = position.latitude;
        lng = position.longitude;
      } catch (_) {
        updateLocation = false;
        lat = null;
        lng = null;
        if (mounted) {
          showAppSnackBar(
            context,
            message:
                'Could not get GPS for customer location update. '
                'Submitting delivery without updating customer location.',
            type: AppSnackBarType.warning,
          );
        }
      }
    }

    try {
      final result = await widget.apiClient.markDeliveriesBatch(
        tripId: widget.tripId,
        docIds: widget.docs.map((d) => d.id).toList(),
        signature: signature,
        deliveryComment: _commentController.text.trim(),
        updateCustomerLocation: updateLocation,
        deliveryLatitude: lat,
        deliveryLongitude: lng,
      );
      if (!mounted) return;
      if (result.statusCode == 401 || result.statusCode == 403) {
        showAppSnackBar(
          context,
          message: result.displayMessage,
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.success
            ? AppSnackBarType.success
            : AppSnackBarType.error,
      );
      if (result.success) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.92;
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mark delivered (${widget.docs.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _submitting ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (_loadingRecent)
            const LinearProgressIndicator(minHeight: 2)
          else
            const SizedBox(height: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Text(
                  widget.docs.map((d) => d.id).join(', '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                  ),
                ),
                if (_proximityWarning != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _proximityWarning!,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                const Text(
                  'Customer Signature Below',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_reusedSignatureBase64 != null &&
                    !_signatureController.isNotEmpty)
                  _RecentSignaturePreview(base64: _reusedSignatureBase64!)
                else
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Signature(
                        controller: _signatureController,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _submitting ? null : _clearSignature,
                    child: const Text('Clear signature'),
                  ),
                ),
                TextField(
                  controller: _commentController,
                  enabled: !_submitting,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _updateCustomerLocation,
                  onChanged: _submitting
                      ? null
                      : (value) {
                          setState(
                            () => _updateCustomerLocation = value ?? true,
                          );
                        },
                  title: const Text('Update customer location'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: _submitting || _loadingRecent ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm delivery'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSignaturePreview extends StatelessWidget {
  const _RecentSignaturePreview({required this.base64});

  final String base64;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64);
    } catch (_) {}
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: bytes == null
          ? const Text('Could not load recent signature')
          : Image.memory(bytes, fit: BoxFit.contain),
    );
  }
}

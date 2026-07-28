import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../utils/geo_distance.dart';
import '../../widgets/app_snack_bar.dart';
import '../trip_dashboard/trip_dashboard_helpers.dart';
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
  static const _signatureAreaHeight = 220.0;

  final _commentController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
  );
  bool _updateCustomerLocation = false;
  bool _isSimulationMode = false;
  bool _submitting = false;
  String? _proximityWarning;
  String? _submissionError;
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
    final isSimulation = await JwtPayload.currentIsImpersonation();
    if (!mounted) return;
    setState(() {
      _isSimulationMode = isSimulation;
      if (!isSimulation) {
        _updateCustomerLocation = true;
      }
    });
    _loadRecentSignature();
    _checkProximity();
  }

  Future<void> _loadRecentSignature() async {
    final first = widget.docs.first;
    try {
      final recent = await widget.apiClient.getRecentSignature(
        tripId: widget.tripId,
        docId: first.id,
      );
      if (!mounted) return;
      if (recent.found && recent.signatureBase64.isNotEmpty) {
        setState(() => _reusedSignatureBase64 = recent.signatureBase64);
      }
    } catch (_) {}
  }

  Future<void> _checkProximity() async {
    final first = widget.docs.first;
    if (!first.hasCustomerGeo || !mounted) return;

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
      if (!mounted) return;
      if (meters > 500) {
        setState(() {
          _proximityWarning =
              'You appear more than 500 m from this customer’s usual delivery '
              'location (${meters.round()} m away). You can still submit.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _proximityWarning =
            'Could not check distance to the customer location right now.';
      });
    }
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

    setState(() {
      _submitting = true;
      _submissionError = null;
    });
    var updateLocation = _isSimulationMode ? false : _updateCustomerLocation;
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
      if (result.success) {
        showAppSnackBar(
          context,
          message: result.displayMessage,
          type: AppSnackBarType.success,
        );
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _submissionError = result.displayMessage);
      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.isCustomerDeliveryCooldown
            ? AppSnackBarType.warning
            : AppSnackBarType.error,
      );
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
          const SizedBox(height: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                ...widget.docs.asMap().entries.map(
                  (entry) {
                    final doc = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${entry.key + 1}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              doc.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: 'monospace',
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (doc.docAmount.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              formatInrAmount(doc.docAmount),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Customer Signature Below',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (_reusedSignatureBase64 != null &&
                    !_signatureController.isNotEmpty)
                  _RecentSignaturePreview(
                    base64: _reusedSignatureBase64!,
                    height: _signatureAreaHeight,
                  )
                else
                  Container(
                    height: _signatureAreaHeight,
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
                  maxLines: 2,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Comments (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _updateCustomerLocation,
                  onChanged: _submitting || _isSimulationMode
                      ? null
                      : (value) {
                          setState(
                            () => _updateCustomerLocation = value ?? true,
                          );
                        },
                  title: const Text('Update customer location'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_proximityWarning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _proximityWarning!,
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_submissionError != null) ...[
                    Text(
                      _submissionError!,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSignaturePreview extends StatelessWidget {
  const _RecentSignaturePreview({
    required this.base64,
    required this.height,
  });

  final String base64;
  final double height;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64);
    } catch (_) {}
    return Container(
      height: height,
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

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../config/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/utils/app_utils.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/trip_widgets.dart';
import '../../routing/app_routes.dart';

class TripDetailsScreen extends ConsumerStatefulWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends ConsumerState<TripDetailsScreen> {
  SingleTripDetailsResponse? _trip;
  bool _loading = true;
  String? _error;
  final Map<String, bool> _expandedGroups = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(apiClientProvider).getSingleTripDetails(widget.tripId);
      setState(() {
        _trip = response;
        for (final group in response.docGroups ?? []) {
          if (group.heading != null) {
            _expandedGroups[group.heading!] = group.expandGroupByDefault;
          }
        }
      });
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position?> _currentPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _dropOff(String heading) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Drop Off',
      message: 'Drop off lot at $heading?',
    );
    if (confirmed != true) return;

    try {
      final response = await ref.read(apiClientProvider).dropOff(
            tripId: widget.tripId,
            heading: heading,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Drop off recorded')),
        );
      }
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  Future<void> _endTrip() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'End Trip',
      message: 'Are you sure you want to end this trip?',
    );
    if (confirmed != true) return;

    try {
      final response =
          await ref.read(apiClientProvider).endTrip(widget.tripId);
      final prefs = await ref.read(prefsProvider.future);
      await LocationTrackingService(prefs, ref.read(apiClientProvider)).stop();
      await prefs.saveCurrentTripId(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Trip ended')),
        );
        context.go(AppRoutes.home);
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  Future<void> _markUndelivered(Doc doc) async {
    final commentController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Undelivered'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            labelText: 'Failure comment',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true || doc.id == null) return;

    try {
      await ref.read(apiClientProvider).markAsUndelivered(
            docId: doc.id!,
            body: MarkAsUnDeliveredRequest(
              failureComment: commentController.text.trim(),
            ),
          );
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      commentController.dispose();
    }
  }

  Future<void> _markDelivered(Doc doc) async {
    if (doc.id == null) return;

    final signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    final commentController = TextEditingController();
    var updateCustomerLocation = false;
    String? recentSignature;

    try {
      final recent = await ref.read(apiClientProvider).getRecentSignature(
            tripId: widget.tripId,
            docId: doc.id!,
          );
      recentSignature = recent.signature;
    } catch (_) {}

    if (!mounted) return;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Mark as Delivered'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (recentSignature?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Recent signature available'),
                    ),
                  SizedBox(
                    height: 180,
                    child: Signature(
                      controller: signatureController,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  TextButton(
                    onPressed: signatureController.clear,
                    child: const Text('Clear Signature'),
                  ),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    value: updateCustomerLocation,
                    onChanged: (v) =>
                        setDialogState(() => updateCustomerLocation = v ?? false),
                    title: const Text('Update customer location'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );

    if (submitted != true) {
      signatureController.dispose();
      commentController.dispose();
      return;
    }

    String? signatureBase64;
    if (signatureController.isNotEmpty) {
      final bytes = await signatureController.toPngBytes();
      if (bytes != null) {
        signatureBase64 = base64Encode(bytes);
      }
    } else if (recentSignature?.isNotEmpty == true) {
      signatureBase64 = recentSignature;
    }

    final position = await _currentPosition();
    final customerLat = double.tryParse(doc.customerGeoLatitude ?? '');
    final customerLng = double.tryParse(doc.customerGeoLongitude ?? '');

    if (position != null &&
        customerLat != null &&
        customerLng != null) {
      final distance = AppUtils.haversineDistanceMeters(
        position.latitude,
        position.longitude,
        customerLat,
        customerLng,
      );
      if (distance > 500 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are ${distance.toStringAsFixed(0)}m from customer location',
            ),
          ),
        );
      }
    }

    try {
      await ref.read(apiClientProvider).markAsDelivered(
            docId: doc.id!,
            updateCustomerLocation: updateCustomerLocation,
            body: MarkAsDeliveredRequest(
              signature: signatureBase64,
              deliveryComment: commentController.text.trim(),
              deliveryLatitude: position?.latitude.toString(),
              deliveryLongitude: position?.longitude.toString(),
            ),
          );
      await _load();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      signatureController.dispose();
      commentController.dispose();
    }
  }

  Future<void> _openNavigation(Doc doc) async {
    final lat = double.tryParse(doc.customerGeoLatitude ?? '');
    final lng = double.tryParse(doc.customerGeoLongitude ?? '');
    if (lat == null || lng == null) return;
    await openGoogleMapsNavigation(
      destinationLat: lat,
      destinationLng: lng,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Trip #${widget.tripId}')),
      body: _loading
          ? const LoadingOverlay()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : _buildBody(),
      bottomNavigationBar: _trip != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: _endTrip,
                  child: const Text('End Trip'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    final trip = _trip!;
    final groups = trip.docGroups ?? [];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  tripMetaRow(icon: Icons.route, label: 'Route', value: trip.route ?? ''),
                  tripMetaRow(
                    icon: Icons.local_shipping,
                    label: 'Vehicle',
                    value: trip.vehicleNumber ?? '',
                  ),
                  tripMetaRow(
                    icon: Icons.person,
                    label: 'Driver',
                    value: trip.driverName ?? '',
                  ),
                  if (trip.deliveryCountStatusMsg?.isNotEmpty == true)
                    tripMetaRow(
                      icon: Icons.inventory_2,
                      label: 'Deliveries',
                      value: trip.deliveryCountStatusMsg!,
                    ),
                ],
              ),
            ),
          ),
          ...groups.map((group) {
            final heading = group.heading ?? 'Group';
            final expanded = _expandedGroups[heading] ?? false;
            return Card(
              child: Column(
                children: [
                  ListTile(
                    title: Text(heading, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                    onTap: () {
                      setState(() => _expandedGroups[heading] = !expanded);
                    },
                  ),
                  if (group.showDropOffButton && !group.dropOffCompleted)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _dropOff(heading),
                          child: const Text('Drop Off At Hub'),
                        ),
                      ),
                    ),
                  if (group.dropOffCompleted)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Dropped off at hub'),
                    ),
                  if (expanded)
                    ...(group.docs ?? []).map((doc) => _docTile(doc)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _docTile(Doc doc) {
    final isOnTrip = doc.status == AppConstants.docStatusOnTrip;
    return ListTile(
      title: Text(doc.customerFirmName ?? doc.id ?? 'Document'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (doc.customerAddress?.isNotEmpty == true) Text(doc.customerAddress!),
          if (doc.docAmount?.isNotEmpty == true) Text('Amount: ${doc.docAmount}'),
          Text('Status: ${doc.status ?? ''}'),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          switch (value) {
            case 'call':
              if (doc.customerPhone?.isNotEmpty == true) {
                await dialPhoneNumber(doc.customerPhone!);
              }
            case 'navigate':
              await _openNavigation(doc);
            case 'deliver':
              await _markDelivered(doc);
            case 'fail':
              await _markUndelivered(doc);
          }
        },
        itemBuilder: (context) => [
          if (doc.customerPhone?.isNotEmpty == true)
            const PopupMenuItem(value: 'call', child: Text('Call')),
          const PopupMenuItem(value: 'navigate', child: Text('Navigate')),
          if (isOnTrip) ...[
            const PopupMenuItem(value: 'deliver', child: Text('Mark Delivered')),
            const PopupMenuItem(value: 'fail', child: Text('Mark Undelivered')),
          ],
        ],
      ),
    );
  }
}

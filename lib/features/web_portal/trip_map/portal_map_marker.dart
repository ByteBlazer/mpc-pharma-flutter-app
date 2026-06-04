import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../config/app_constants.dart';
import '../../../core/models/web_portal_models.dart';

enum PortalMarkerType { driver, customer }

class PortalMapMarker {
  PortalMapMarker({
    required this.id,
    required this.position,
    required this.type,
    required this.title,
    this.tripId,
    this.status,
    this.customerInfo,
    this.customerDocs = const [],
  });

  final String id;
  final LatLng position;
  final PortalMarkerType type;
  final String title;
  final int? tripId;
  final String? status;
  final PortalCustomerInfo? customerInfo;
  final List<WebPortalDoc> customerDocs;

  Marker toGoogleMarker({
    required BitmapDescriptor driverIcon,
    required BitmapDescriptor customerIcon,
    required void Function(PortalMapMarker marker) onTap,
    bool driverClickable = true,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: type == PortalMarkerType.driver ? driverIcon : customerIcon,
      zIndexInt: type == PortalMarkerType.customer ? 2 : 1,
      infoWindow: InfoWindow(title: title),
      onTap: () {
        if (type == PortalMarkerType.driver && !driverClickable) return;
        onTap(this);
      },
    );
  }
}

class PortalCustomerInfo {
  const PortalCustomerInfo({
    required this.firmName,
    required this.address,
    required this.city,
    required this.phone,
  });

  final String firmName;
  final String address;
  final String city;
  final String phone;
}

class PortalTripSummary {
  const PortalTripSummary({
    required this.totalDeliveries,
    required this.completedDeliveries,
    required this.failedDeliveries,
    required this.pendingDeliveries,
    required this.dropoffsPending,
    this.duration,
    this.durationLabel,
  });

  final int totalDeliveries;
  final int completedDeliveries;
  final int failedDeliveries;
  final int pendingDeliveries;
  final int dropoffsPending;
  final String? duration;
  final String? durationLabel;
}

class PortalTripMapLogic {
  PortalTripMapLogic._();

  static const defaultCenter = LatLng(9.9312, 76.2673);

  static int _statusPriority(String status) {
    return switch (status) {
      AppConstants.docStatusUndelivered => 5,
      AppConstants.docStatusOnTrip => 4,
      'AT_TRANSIT_HUB' => 3,
      'TRIP_SCHEDULED' => 2,
      'READY_FOR_DISPATCH' => 1,
      AppConstants.docStatusDelivered => 0,
      _ => 0,
    };
  }

  static String _pickHigherPriorityStatus(String? current, String candidate) {
    if (current == null || current.isEmpty) return candidate;
    return _statusPriority(candidate) > _statusPriority(current)
        ? candidate
        : current;
  }

  static List<PortalMapMarker> buildDriverMarkers(List<WebPortalTrip> trips) {
    final markers = <PortalMapMarker>[];
    for (final trip in trips) {
      final lat = double.tryParse(trip.driverLastKnownLatitude ?? '');
      final lng = double.tryParse(trip.driverLastKnownLongitude ?? '');
      if (lat == null || lng == null) continue;
      markers.add(
        PortalMapMarker(
          id: 'driver-${trip.tripId}',
          position: LatLng(lat, lng),
          type: PortalMarkerType.driver,
          title: '${trip.driverName} - ${trip.vehicleNumber} - ${trip.route}',
          tripId: trip.tripId,
        ),
      );
    }
    return markers;
  }

  static List<PortalMapMarker> buildSelectedTripMarkers(WebPortalTrip trip) {
    final customerMap = <String, PortalMapMarker>{};

    for (final group in trip.docGroups ?? <WebPortalDocGroup>[]) {
      for (final doc in group.docs) {
        if (doc.lot != null && doc.lot!.isNotEmpty) continue;
        final lat = double.tryParse(doc.customerGeoLatitude ?? '');
        final lng = double.tryParse(doc.customerGeoLongitude ?? '');
        if (lat == null || lng == null) continue;

        final key = doc.customerId.trim().isNotEmpty
            ? doc.customerId
            : '${doc.customerFirmName}-$lat-$lng';

        final existing = customerMap[key];
        if (existing != null) {
          customerMap[key] = PortalMapMarker(
            id: existing.id,
            position: existing.position,
            type: PortalMarkerType.customer,
            title: existing.title,
            tripId: trip.tripId,
            status: _pickHigherPriorityStatus(existing.status, doc.status),
            customerInfo: existing.customerInfo,
            customerDocs: [...existing.customerDocs, doc],
          );
        } else {
          customerMap[key] = PortalMapMarker(
            id: 'customer-${key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}',
            position: LatLng(lat, lng),
            type: PortalMarkerType.customer,
            title: doc.customerFirmName,
            tripId: trip.tripId,
            status: doc.status,
            customerInfo: PortalCustomerInfo(
              firmName: doc.customerFirmName,
              address: doc.customerAddress,
              city: doc.customerCity,
              phone: doc.customerPhone,
            ),
            customerDocs: [doc],
          );
        }
      }
    }

    final markers = <PortalMapMarker>[...customerMap.values];

    final dLat = double.tryParse(trip.driverLastKnownLatitude ?? '');
    final dLng = double.tryParse(trip.driverLastKnownLongitude ?? '');
    if (dLat != null && dLng != null) {
      markers.insert(
        0,
        PortalMapMarker(
          id: 'driver-${trip.tripId}',
          position: LatLng(dLat, dLng),
          type: PortalMarkerType.driver,
          title:
              '${trip.driverName} - ${trip.vehicleNumber} - ${trip.route}',
          tripId: trip.tripId,
        ),
      );
    }

    return markers;
  }

  static PortalTripSummary? computeTripSummary(WebPortalTrip? trip) {
    if (trip?.docGroups == null) return null;

    final directByCustomer = <String, List<WebPortalDoc>>{};
    for (final group in trip!.docGroups!) {
      for (final doc in group.docs) {
        if (doc.lot != null && doc.lot!.isNotEmpty) continue;
        directByCustomer.putIfAbsent(doc.customerId, () => []).add(doc);
      }
    }

    var completed = 0;
    var failed = 0;
    var pending = 0;
    for (final docs in directByCustomer.values) {
      if (docs.every((d) => d.status == AppConstants.docStatusDelivered)) {
        completed++;
      } else if (docs.any(
        (d) => d.status == AppConstants.docStatusUndelivered,
      )) {
        failed++;
      } else {
        pending++;
      }
    }

    final dropoffs =
        trip.docGroups!.where((g) => g.showDropOffButton).length;

    String? duration;
    String? durationLabel;
    if (trip.status == AppConstants.tripStatusStarted ||
        trip.status == 'ENDED') {
      final end = trip.status == 'ENDED' ? trip.lastUpdatedAt : DateTime.now();
      final diff = end.difference(trip.startedAt);
      duration = '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
      durationLabel = trip.status == 'ENDED'
          ? 'Total Trip Duration:'
          : 'Time Since Start Of Trip:';
    }

    return PortalTripSummary(
      totalDeliveries: directByCustomer.length,
      completedDeliveries: completed,
      failedDeliveries: failed,
      pendingDeliveries: pending,
      dropoffsPending: dropoffs,
      duration: duration,
      durationLabel: durationLabel,
    );
  }

  static LatLngBounds? boundsFor(List<PortalMapMarker> markers) {
    if (markers.isEmpty) return null;
    var minLat = markers.first.position.latitude;
    var maxLat = minLat;
    var minLng = markers.first.position.longitude;
    var maxLng = minLng;
    for (final m in markers) {
      minLat = minLat < m.position.latitude ? minLat : m.position.latitude;
      maxLat = maxLat > m.position.latitude ? maxLat : m.position.latitude;
      minLng = minLng < m.position.longitude ? minLng : m.position.longitude;
      maxLng = maxLng > m.position.longitude ? maxLng : m.position.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static String mapHeading({
    required int activeTab,
    required int? selectedTripId,
    required WebPortalTrip? selectedTrip,
  }) {
    if (selectedTripId != null && selectedTrip != null) {
      return 'Trip #$selectedTripId - ${selectedTrip.route}';
    }
    if (selectedTripId != null) {
      return 'Trip #$selectedTripId';
    }
    return switch (activeTab) {
      0 => 'All Ongoing Trips - Driver Locations',
      1 => 'Select a Trip to View Details',
      _ => 'Select a Trip to View Details',
    };
  }

  static String generateTrackingUrl(String docId) {
    final token = base64.encode(utf8.encode(docId));
    final origin = Uri.base.origin;
    return '$origin/track?t=$token';
  }
}

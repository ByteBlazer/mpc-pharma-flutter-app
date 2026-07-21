import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String mapMarkerAssetPath = 'assets/images/customer_map_marker.png';
const String driverMapMarkerAssetPath = 'assets/images/truck_map_marker.png';

const ImageConfiguration _mapMarkerImageConfiguration = ImageConfiguration(
  size: Size(32, 32),
  devicePixelRatio: 1.0,
);

const ImageConfiguration _driverMapMarkerImageConfiguration =
    ImageConfiguration(
  size: Size(60, 60),
  devicePixelRatio: 1.0,
);

const ImageConfiguration _tripDashboardCustomerMapMarkerImageConfiguration =
    ImageConfiguration(
  size: Size(64, 64),
  devicePixelRatio: 1.0,
);

Future<BitmapDescriptor> loadMapMarkerIcon() {
  return BitmapDescriptor.asset(
    _mapMarkerImageConfiguration,
    mapMarkerAssetPath,
  );
}

Future<BitmapDescriptor> loadTripDashboardCustomerMapMarkerIcon() {
  return BitmapDescriptor.asset(
    _tripDashboardCustomerMapMarkerImageConfiguration,
    mapMarkerAssetPath,
  );
}

Future<BitmapDescriptor> loadDriverMapMarkerIcon() {
  return BitmapDescriptor.asset(
    _driverMapMarkerImageConfiguration,
    driverMapMarkerAssetPath,
  );
}

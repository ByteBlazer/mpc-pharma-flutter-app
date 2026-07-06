import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String mapMarkerAssetPath = 'assets/images/customer_map_marker.png';

const ImageConfiguration _mapMarkerImageConfiguration = ImageConfiguration(
  size: Size(32, 32),
  devicePixelRatio: 1.0,
);

Future<BitmapDescriptor> loadMapMarkerIcon() {
  return BitmapDescriptor.asset(
    _mapMarkerImageConfiguration,
    mapMarkerAssetPath,
  );
}

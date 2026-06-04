import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/app_utils.dart';

Future<void> dialPhoneNumber(String phone) async {
  final uri = Uri.parse('tel:$phone');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> openGoogleMapsNavigation({
  required double destinationLat,
  required double destinationLng,
}) async {
  final uri = Uri.parse(
    'google.navigation:q=$destinationLat,$destinationLng&mode=d',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
    return;
  }
  final webUri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng&travelmode=driving',
  );
  await launchUrl(webUri, mode: LaunchMode.externalApplication);
}

String formatTripCreatedAt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  return AppUtils.convertIso8601ToIst(iso);
}

Widget tripMetaRow({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../core/models/web_portal_models.dart';

/// Web portal targets web; no-op on other platforms.
Future<void> downloadDeliveryReportExcel(
  BuildContext context,
  List<WebPortalDeliveryReportItem> rows,
) async {}

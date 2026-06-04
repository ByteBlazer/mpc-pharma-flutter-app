import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/web_portal_models.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/utils/jwt_utils.dart';

final webPortalUserProvider = Provider<JwtPayload?>((ref) {
  final prefs = ref.watch(prefsProvider);
  return prefs.maybeWhen(
    data: (p) {
      final token = p.accessToken;
      if (token == null) return null;
      return JwtPayload.decode(token);
    },
    orElse: () => null,
  );
});

final portalUsersProvider = FutureProvider.autoDispose<List<WebPortalUser>>(
  (ref) => ref.watch(apiClientProvider).getPortalUsers(),
);

final portalUserRolesListProvider =
    FutureProvider.autoDispose<List<WebPortalUserRole>>(
  (ref) => ref.watch(apiClientProvider).getPortalUserRoles(),
);

final portalBaseLocationsProvider =
    FutureProvider.autoDispose<List<WebPortalBaseLocation>>(
  (ref) => ref.watch(apiClientProvider).getPortalBaseLocations(),
);

final portalAllTripsProvider =
    FutureProvider.autoDispose<WebPortalAllTripsResponse>(
  (ref) => ref.watch(apiClientProvider).getAllTrips(),
);

final portalTripDetailProvider =
    FutureProvider.autoDispose.family<WebPortalTrip, int>(
  (ref, tripId) => ref.watch(apiClientProvider).getPortalTripDetail(tripId),
);

final portalLightweightCustomersProvider =
    FutureProvider.autoDispose<List<WebPortalLightweightCustomer>>(
  (ref) => ref.watch(apiClientProvider).getLightweightCustomers(),
);

final portalRoutesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(apiClientProvider).getRoutes(),
);

final portalOriginWarehousesProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(apiClientProvider).getOriginWarehouses(),
);

final portalDriversProvider = FutureProvider.autoDispose<DriverListResponse>(
  (ref) => ref.watch(apiClientProvider).getDriverList(),
);

final portalBackupsProvider =
    FutureProvider.autoDispose<WebPortalBackupListResponse>(
  (ref) => ref.watch(apiClientProvider).listBackups(),
);

final portalSettingProvider =
    FutureProvider.autoDispose.family<WebPortalSetting, String>(
  (ref, name) => ref.watch(apiClientProvider).getPortalSetting(name),
);

final deliveryReportFiltersProvider =
    StateProvider<WebPortalDeliveryReportFilters>(
  (ref) => WebPortalDeliveryReportFilters(),
);

final deliveryReportQueryProvider =
    StateProvider<WebPortalDeliveryReportFilters?>(
  (ref) => null,
);

final deliveryReportDataProvider =
    FutureProvider.autoDispose<WebPortalDeliveryReportResponse?>((ref) async {
  final query = ref.watch(deliveryReportQueryProvider);
  if (query == null) return null;
  return ref.watch(apiClientProvider).getDeliveryReport(query);
});

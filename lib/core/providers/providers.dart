import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_constants.dart';
import '../api/api_client.dart';
import '../storage/prefs_service.dart';

final prefsProvider = FutureProvider<PrefsService>((ref) async {
  return PrefsService.create();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.watch(prefsProvider).requireValue;
  return ApiClient(prefs);
});

final userRolesProvider = Provider<Set<UserType>>((ref) {
  final prefs = ref.watch(prefsProvider);
  return prefs.maybeWhen(
    data: (p) => p.userTypes,
    orElse: () => {},
  );
});

class HomeRefreshNotifier extends StateNotifier<int> {
  HomeRefreshNotifier() : super(0);
  void refresh() => state++;
}

final queueRefreshProvider =
    StateNotifierProvider<HomeRefreshNotifier, int>((ref) {
  return HomeRefreshNotifier();
});

final scheduledTripsRefreshProvider =
    StateNotifierProvider<HomeRefreshNotifier, int>((ref) {
  return HomeRefreshNotifier();
});

final myTripsRefreshProvider =
    StateNotifierProvider<HomeRefreshNotifier, int>((ref) {
  return HomeRefreshNotifier();
});

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

final lastLoginTimeProvider = StateProvider<DateTime?>((ref) => null);

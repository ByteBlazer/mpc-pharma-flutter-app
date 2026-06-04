import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/app_workflow.dart';
import '../core/auth/auth_manager.dart';
import '../core/providers/providers.dart';
import '../core/services/location_tracking_service.dart';
import '../core/services/session_service.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/otp_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/schedule_trip/schedule_trip_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/trip_details/trip_details_screen.dart';
import '../features/web_portal/web_portal_base_locations_screen.dart';
import '../features/web_portal/web_portal_delivery_report_screen.dart';
import '../features/web_portal/web_portal_home_screen.dart';
import '../features/web_portal/web_portal_reports_screen.dart';
import '../features/web_portal/web_portal_settings_screen.dart';
import '../features/web_portal/web_portal_shell.dart';
import '../features/web_portal/web_portal_trips_screen.dart';
import '../features/web_portal/web_portal_users_screen.dart';
import '../features/workflow_selection/placeholder_workflow_screen.dart';
import '../features/workflow_selection/workflow_selection_screen.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final prefsAsync = ref.watch(prefsProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: GoRouterRefreshStream(
      AuthManager.instance.authEvents,
    ),
    redirect: (context, state) {
      if (prefsAsync.isLoading) return null;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'];
          return LoginScreen(prefillPhone: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: AppRoutes.workflowSelect,
        builder: (context, state) => const WorkflowSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.workflowCustomer,
        builder: (context, state) => const PlaceholderWorkflowScreen(
          workflow: AppWorkflow.customer,
        ),
      ),
      GoRoute(
        path: AppRoutes.workflowWeb,
        redirect: (context, state) {
          if (state.uri.path == AppRoutes.workflowWeb) {
            return AppRoutes.workflowWebHome;
          }
          return null;
        },
        routes: [
          ShellRoute(
            builder: (context, state, child) =>
                WebPortalShell(child: child),
            routes: [
              GoRoute(
                path: 'home',
                builder: (context, state) => const WebPortalHomeScreen(),
              ),
              GoRoute(
                path: 'users',
                builder: (context, state) => const WebPortalUsersScreen(),
              ),
              GoRoute(
                path: 'base-locations',
                builder: (context, state) =>
                    const WebPortalBaseLocationsScreen(),
              ),
              GoRoute(
                path: 'trips',
                builder: (context, state) => const WebPortalTripsScreen(),
              ),
              GoRoute(
                path: 'reports',
                builder: (context, state) => const WebPortalReportsScreen(),
                routes: [
                  GoRoute(
                    path: 'delivery',
                    builder: (context, state) =>
                        const WebPortalDeliveryReportScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const WebPortalSettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return HomeScreen(initialTab: tab);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.scheduleTrip,
        builder: (context, state) {
          final route = state.uri.queryParameters['route'] ?? '';
          final userListJson = state.uri.queryParameters['users'] ?? '[]';
          final userIds = (jsonDecode(userListJson) as List)
              .map((e) => e.toString())
              .toList();
          return ScheduleTripScreen(route: route, userIds: userIds);
        },
      ),
      GoRoute(
        path: '${AppRoutes.tripDetails}/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          return TripDetailsScreen(tripId: tripId);
        },
      ),
    ],
  );
});

class AppRouterListener extends ConsumerStatefulWidget {
  const AppRouterListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppRouterListener> createState() => _AppRouterListenerState();
}

class _AppRouterListenerState extends ConsumerState<AppRouterListener> {
  StreamSubscription<AuthEvent>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = AuthManager.instance.authEvents.listen((event) async {
      if (event != AuthEvent.expired) return;
      final context = ref.context;
      if (!context.mounted) return;

      final router = GoRouter.of(context);
      final location = router.state.uri.path;
      if (location == AppRoutes.login ||
          location == AppRoutes.splash ||
          location.startsWith(AppRoutes.otp)) {
        return;
      }

      final prefs = await ref.read(prefsProvider.future);
      final phone = prefs.phoneNumber;
      final session = SessionService(prefs);
      final locationService = LocationTrackingService(
        prefs,
        ref.read(apiClientProvider),
      );
      await locationService.stop();
      await session.clearSession();
      ref.read(lastLoginTimeProvider.notifier).state = null;

      if (context.mounted) {
        router.go('${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

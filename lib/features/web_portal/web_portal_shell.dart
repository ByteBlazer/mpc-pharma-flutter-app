import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class WebPortalShell extends ConsumerWidget {
  const WebPortalShell({super.key, required this.child});

  final Widget child;

  static const _navItems = [
    _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      route: AppRoutes.workflowWebHome,
    ),
    _NavItem(
      label: 'Users',
      icon: Icons.people_outline,
      route: AppRoutes.workflowWebUsers,
    ),
    _NavItem(
      label: 'Locations',
      icon: Icons.storefront_outlined,
      route: AppRoutes.workflowWebBaseLocations,
    ),
    _NavItem(
      label: 'Trips',
      icon: Icons.local_shipping_outlined,
      route: AppRoutes.workflowWebTrips,
    ),
    _NavItem(
      label: 'Reports',
      icon: Icons.assessment_outlined,
      route: AppRoutes.workflowWebReports,
    ),
  ];

  int _selectedIndex(String location) {
    if (location.startsWith(AppRoutes.workflowWebReports)) return 4;
    if (location.startsWith(AppRoutes.workflowWebTrips)) return 3;
    if (location.startsWith(AppRoutes.workflowWebBaseLocations)) return 2;
    if (location.startsWith(AppRoutes.workflowWebUsers)) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(location);
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Pharma Tracker'),
        actions: [
          IconButton(
            icon: Icon(
              location == AppRoutes.workflowWebSettings
                  ? Icons.settings
                  : Icons.settings_outlined,
            ),
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.workflowWebSettings),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isWide)
            Material(
              color: AppColors.primary,
              child: Row(
                children: [
                  for (var i = 0; i < _navItems.length; i++)
                    _TopNavButton(
                      item: _navItems[i],
                      selected: selected == i,
                      onTap: () => context.go(_navItems[i].route),
                    ),
                ],
              ),
            )
          else
            NavigationBar(
              selectedIndex: selected.clamp(0, _navItems.length - 1),
              onDestinationSelected: (i) => context.go(_navItems[i].route),
              destinations: [
                for (final item in _navItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Confirm Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
    );
    if (ok != true || !context.mounted) return;

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
      context.go('${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}');
    }
  }
}

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class _TopNavButton extends StatelessWidget {
  const _TopNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor:
            selected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon, size: 18),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

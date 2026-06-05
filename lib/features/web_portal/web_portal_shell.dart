import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/providers.dart';
import '../../core/widgets/mpc_pharma_logo.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';
import 'web_portal_theme.dart';

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

  /// Main nav highlight index, or `null` when no tab applies (e.g. Settings).
  int? _selectedNavIndex(String location) {
    if (location.startsWith(AppRoutes.workflowWebSettings)) return null;
    if (location.startsWith(AppRoutes.workflowWebReports)) return 4;
    if (location.startsWith(AppRoutes.workflowWebTrips)) return 3;
    if (location.startsWith(AppRoutes.workflowWebBaseLocations)) return 2;
    if (location.startsWith(AppRoutes.workflowWebUsers)) return 1;
    if (location.startsWith(AppRoutes.workflowWebHome) ||
        location == AppRoutes.workflowWeb) {
      return 0;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedNavIndex(location);
    final onSettings = location.startsWith(AppRoutes.workflowWebSettings);
    final width = MediaQuery.sizeOf(context).width;
    // Text nav needs ~1100px; icon row needs ~768px before crowding.
    final useTextNav = width >= 1100;
    final useIconNav = width >= 768;
    final showBrandText = width >= 520;

    return Theme(
      data: WebPortalTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: InkWell(
            onTap: () => context.go(AppRoutes.workflowWebHome),
            child: Row(
              children: [
                const MpcPharmaLogo(size: 32),
                if (showBrandText) ...[
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'MPC Pharma',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (useTextNav)
              for (var i = 0; i < _navItems.length; i++)
                _AppBarNavButton(
                  item: _navItems[i],
                  selected: selectedIndex == i,
                  onTap: () => context.go(_navItems[i].route),
                )
            else if (useIconNav)
              for (var i = 0; i < _navItems.length; i++)
                IconButton(
                  icon: Icon(_navItems[i].icon),
                  tooltip: _navItems[i].label,
                  onPressed: () => context.go(_navItems[i].route),
                  style: IconButton.styleFrom(
                    backgroundColor: selectedIndex == i
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.transparent,
                    visualDensity: VisualDensity.compact,
                  ),
                )
            else
              PopupMenuButton<int>(
                icon: const Icon(Icons.menu),
                tooltip: 'Navigation',
                onSelected: (i) => context.go(_navItems[i].route),
                itemBuilder: (context) => [
                  for (var i = 0; i < _navItems.length; i++)
                    PopupMenuItem(
                      value: i,
                      child: Row(
                        children: [
                          Icon(
                            _navItems[i].icon,
                            size: 20,
                            color: selectedIndex == i
                                ? AppColors.primary
                                : Colors.black87,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _navItems[i].label,
                            style: TextStyle(
                              fontWeight: selectedIndex == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            IconButton(
              icon: Icon(
                onSettings ? Icons.settings : Icons.settings_outlined,
              ),
              tooltip: 'Settings',
              onPressed: () => context.go(AppRoutes.workflowWebSettings),
              style: IconButton.styleFrom(
                backgroundColor: onSettings
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.transparent,
                visualDensity: VisualDensity.compact,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: () => _confirmLogout(context, ref),
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        body: child,
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
      context.go(
        '${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}',
      );
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

class _AppBarNavButton extends StatelessWidget {
  const _AppBarNavButton({
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
        backgroundColor: selected
            ? Colors.white.withValues(alpha: 0.22)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        item.label.toUpperCase(),
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.5,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

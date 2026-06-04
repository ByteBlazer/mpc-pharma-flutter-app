import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_constants.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../routing/app_routes.dart';
import '../my_trips/my_trips_screen.dart';
import '../queue/dispatch_queue_screen.dart';
import '../scan/scan_screen.dart';
import '../scheduled_trips/scheduled_trips_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final PageController _pageController;
  List<HomeTab> _tabs = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupTabs());
  }

  void _setupTabs() {
    final roles = ref.read(userRolesProvider);
    _tabs = HomeTab.values
        .where((tab) => tab.visibleFor.any(roles.contains))
        .toList();

    if (widget.initialTab == 'trips') {
      final idx = _tabs.indexOf(HomeTab.scheduledTrips);
      if (idx >= 0) _currentIndex = idx;
    }

    if (_currentIndex < _tabs.length) {
      _pageController.jumpToPage(_currentIndex);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onRefresh() {
    final tab = _tabs[_currentIndex];
    switch (tab) {
      case HomeTab.scan:
        break;
      case HomeTab.queue:
        ref.read(queueRefreshProvider.notifier).refresh();
      case HomeTab.scheduledTrips:
        ref.read(scheduledTripsRefreshProvider.notifier).refresh();
      case HomeTab.myTrips:
        ref.read(myTripsRefreshProvider.notifier).refresh();
    }
  }

  IconData _iconFor(HomeTab tab) => switch (tab) {
        HomeTab.scan => Icons.qr_code_scanner,
        HomeTab.queue => Icons.format_list_bulleted,
        HomeTab.scheduledTrips => Icons.calendar_month,
        HomeTab.myTrips => Icons.local_shipping,
      };

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(userRolesProvider);

    if (roles.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MPC Pharma'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push(AppRoutes.profile),
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No navigation tabs are visible as your user id does not have the required access roles. Please contact admin to provide the necessary access roles for your user id',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    _tabs = HomeTab.values
        .where((tab) => tab.visibleFor.any(roles.contains))
        .toList();

    if (_tabs.isEmpty) {
      return const Scaffold(body: Center(child: Text('No tabs available')));
    }

    if (_currentIndex >= _tabs.length) _currentIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_currentIndex].title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_tabs[_currentIndex] != HomeTab.scan)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(AppRoutes.profile),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        children: _tabs.map((tab) {
          return switch (tab) {
            HomeTab.scan => const ScanScreen(),
            HomeTab.queue => const DispatchQueueScreen(),
            HomeTab.scheduledTrips => const ScheduledTripsScreen(),
            HomeTab.myTrips => const MyTripsScreen(),
          };
        }).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        },
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(_iconFor(tab)),
                label: tab.title,
              ),
            )
            .toList(),
      ),
    );
  }
}

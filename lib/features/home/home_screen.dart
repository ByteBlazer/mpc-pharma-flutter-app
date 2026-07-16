import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../../app_theme.dart';
import '../../auth/jwt_payload.dart';
import '../../utils/build_timestamp.dart';
import '../../widgets/app_brand_page_background.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/simulation_mode_banner.dart';
import '../auth/impersonate_screen.dart';
import '../customers/customers_screen.dart';
import '../departments/departments_screen.dart';
import '../locations/locations_screen.dart';
import '../settings/settings_screen.dart';
import '../tickets/tickets_screen.dart';
import '../users/users_screen.dart';

const _homeTileSpacing = 20.0;

bool _isWideHomeLayout(double width) => width > 500;

double _homeTileWidth(double width) => _isWideHomeLayout(width) ? 88.0 : 68.0;

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    required this.onSessionReplaced,
    required this.onExitSimulation,
    required this.isSimulationMode,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final VoidCallback onSessionReplaced;
  final Future<void> Function() onExitSimulation;
  final bool isSimulationMode;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(
          child: AppBrandPageBackground(showDecorCircles: true),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _HomeWelcomeCard(),
                            const SizedBox(height: 28),
                            _HomeFeatureGrid(
                              isSimulationMode: isSimulationMode,
                              apiClient: apiClient,
                              onLoginAgain: onLoginAgain,
                              onSessionReplaced: onSessionReplaced,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (isSimulationMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: SimulationModeBanner(
                        isVisible: true,
                        onExitSimulation: onExitSimulation,
                      ),
                    ),
                  ),
                ),
              _HomeBuildTimestamp(apiClient: apiClient),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeBuildTimestamp extends StatelessWidget {
  const _HomeBuildTimestamp({required this.apiClient});

  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: loadBuildTimestamp(apiClient: apiClient),
      builder: (context, snapshot) {
        final stamp = snapshot.data;
        if (stamp == null || stamp.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            'Build $stamp',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black45,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}

class _HomeWelcomeCard extends StatelessWidget {
  const _HomeWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeUser?>(
      future: _HomeUser.load(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();

        final primary = Theme.of(context).colorScheme.primary;
        final accentText = AppTheme.primaryAccentText(primary);

        return AppSurface(
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.11),
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.20)),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: accentText,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: accentText,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (user.baseLocationName.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: primary.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: accentText,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user.baseLocationName,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeUser {
  const _HomeUser({required this.username, required this.baseLocationName});

  final String username;
  final String baseLocationName;

  static Future<_HomeUser?> load() async {
    final token = await AuthTokenStore().readToken();
    if (token == null) return null;

    final parts = token.split('.');
    if (parts.length < 2) return null;

    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) return null;

    return _HomeUser(
      username: json['username']?.toString() ?? '',
      baseLocationName: json['baseLocationName']?.toString() ?? '',
    );
  }
}

class _HomeFeatureGrid extends StatelessWidget {
  const _HomeFeatureGrid({
    required this.isSimulationMode,
    required this.apiClient,
    required this.onLoginAgain,
    required this.onSessionReplaced,
  });

  final bool isSimulationMode;
  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final VoidCallback onSessionReplaced;

  Future<_HomeFeatureVisibility> _loadVisibility() async {
    final showImpersonate =
        !isSimulationMode && await JwtPayload.canStartImpersonation();
    final showTickets = await JwtPayload.currentUserIsEmployee();
    final showComplaints = await JwtPayload.currentUserIsCustomer();
    final showSettings = await JwtPayload.currentUserIsAppAdmin();
    return _HomeFeatureVisibility(
      showImpersonate: showImpersonate,
      showTickets: showTickets,
      showComplaints: showComplaints,
      showSettings: showSettings,
    );
  }

  List<Widget> _buildTiles(
    BuildContext context,
    _HomeFeatureVisibility visibility,
  ) {
    return [
      if (visibility.showImpersonate)
        _FeatureTile(
          icon: Icons.manage_accounts_outlined,
          label: 'Simulate Other User',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ImpersonateScreen(
                  apiClient: apiClient,
                  onLoginAgain: onLoginAgain,
                  onSessionReplaced: onSessionReplaced,
                ),
              ),
            );
          },
        ),
      if (visibility.showTickets)
        _FeatureTile(
          icon: Icons.confirmation_number_outlined,
          label: 'Tickets',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TicketsScreen(
                  apiClient: apiClient,
                  onLoginAgain: onLoginAgain,
                ),
              ),
            );
          },
        ),
      if (visibility.showComplaints)
        _FeatureTile(
          icon: Icons.support_agent_outlined,
          label: 'Complaints',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ComplaintsScreen(
                  apiClient: apiClient,
                  onLoginAgain: onLoginAgain,
                ),
              ),
            );
          },
        ),
      _FeatureTile(
        icon: Icons.people_alt_outlined,
        label: 'Users',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  UsersScreen(apiClient: apiClient, onLoginAgain: onLoginAgain),
            ),
          );
        },
      ),
      _FeatureTile(
        icon: Icons.business_outlined,
        label: 'Departments',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DepartmentsScreen(
                apiClient: apiClient,
                onLoginAgain: onLoginAgain,
              ),
            ),
          );
        },
      ),
      _FeatureTile(
        icon: Icons.storefront_outlined,
        label: 'Customers',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CustomersScreen(
                apiClient: apiClient,
                onLoginAgain: onLoginAgain,
              ),
            ),
          );
        },
      ),
      _FeatureTile(
        icon: Icons.map_outlined,
        label: 'Locations',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => LocationsScreen(
                apiClient: apiClient,
                onLoginAgain: onLoginAgain,
              ),
            ),
          );
        },
      ),
      if (visibility.showSettings)
        _FeatureTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  apiClient: apiClient,
                  onLoginAgain: onLoginAgain,
                ),
              ),
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeFeatureVisibility>(
      future: _loadVisibility(),
      builder: (context, snapshot) {
        final visibility = snapshot.data;
        if (visibility == null) return const SizedBox.shrink();

        final tiles = _buildTiles(context, visibility);

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.sizeOf(context).width;
            final tileWidth = _homeTileWidth(screenWidth);
            final columns =
                ((constraints.maxWidth + _homeTileSpacing) /
                        (tileWidth + _homeTileSpacing))
                    .floor()
                    .clamp(1, 8);
            final gridWidth =
                tileWidth * columns + _homeTileSpacing * (columns - 1);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      for (
                        var rowStart = 0;
                        rowStart < tiles.length;
                        rowStart += columns
                      ) ...[
                        if (rowStart > 0)
                          const SizedBox(height: _homeTileSpacing),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (
                              var column = 0;
                              column < columns;
                              column++
                            ) ...[
                              if (column > 0)
                                const SizedBox(width: _homeTileSpacing),
                              SizedBox(
                                width: tileWidth,
                                child: rowStart + column < tiles.length
                                    ? tiles[rowStart + column]
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeFeatureVisibility {
  const _HomeFeatureVisibility({
    required this.showImpersonate,
    required this.showTickets,
    required this.showComplaints,
    required this.showSettings,
  });

  final bool showImpersonate;
  final bool showTickets;
  final bool showComplaints;
  final bool showSettings;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = _isWideHomeLayout(screenWidth);
    final tileWidth = _homeTileWidth(screenWidth);
    final iconBoxSize = isWide ? 72.0 : 52.0;
    final iconSize = isWide ? 32.0 : 24.0;
    final borderRadius = isWide ? 16.0 : 14.0;
    final labelSpacing = isWide ? 8.0 : 6.0;
    final labelFontSize = isWide ? 13.0 : 11.0;
    final labelLineHeight = labelFontSize * 1.15;
    final labelAreaHeight = labelLineHeight * 2;

    const borderWidth = 1.0;
    const tileInset = 2.0;
    final innerRadius = borderRadius > borderWidth
        ? borderRadius - borderWidth
        : 0.0;

    return SizedBox(
      width: tileWidth,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(tileInset),
              child: Container(
                padding: const EdgeInsets.all(borderWidth),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(innerRadius),
                  ),
                  child: Icon(
                    icon,
                    size: iconSize,
                    color: AppTheme.primaryGlyph(colorScheme.primary),
                  ),
                ),
              ),
            ),
            SizedBox(height: labelSpacing),
            SizedBox(
              height: labelAreaHeight,
              width: tileWidth,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: labelFontSize,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

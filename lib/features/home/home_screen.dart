import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/simulation_mode_banner.dart';
import '../auth/impersonate_screen.dart';
import '../customers/customers_screen.dart';
import '../departments/departments_screen.dart';
import '../locations/locations_screen.dart';
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
    return SafeArea(
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
                        const _HomeUserSummary(),
                        const SizedBox(height: 24),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: SimulationModeBanner(
                  isVisible: isSimulationMode,
                  onExitSimulation: onExitSimulation,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeUserSummary extends StatelessWidget {
  const _HomeUserSummary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeUser?>(
      future: _HomeUser.load(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) return const SizedBox.shrink();

        return Row(
          children: [
            Expanded(
              child: _HomeUserSummaryItem(
                icon: Icons.person_outline,
                text: user.username,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _HomeUserSummaryItem(
                icon: Icons.location_on_outlined,
                text: user.baseLocationName,
                alignment: MainAxisAlignment.end,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeUserSummaryItem extends StatelessWidget {
  const _HomeUserSummaryItem({
    required this.icon,
    required this.text,
    this.alignment = MainAxisAlignment.start,
  });

  final IconData icon;
  final String text;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      children: [
        Icon(icon, size: 18, color: Colors.black),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.black),
          ),
        ),
      ],
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
    final showImpersonate = !isSimulationMode &&
        await JwtPayload.canStartImpersonation();
    final showTickets = await JwtPayload.currentUserIsEmployee();
    return _HomeFeatureVisibility(
      showImpersonate: showImpersonate,
      showTickets: showTickets,
    );
  }

  List<Widget> _buildTiles(BuildContext context, _HomeFeatureVisibility visibility) {
    return [
      if (visibility.showImpersonate)
        _FeatureTile(
          icon: Icons.manage_accounts_outlined,
          label: 'Simulate Another User',
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
              builder: (_) => UsersScreen(
                apiClient: apiClient,
                onLoginAgain: onLoginAgain,
              ),
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
                      for (var rowStart = 0;
                          rowStart < tiles.length;
                          rowStart += columns) ...[
                        if (rowStart > 0)
                          const SizedBox(height: _homeTileSpacing),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var column = 0; column < columns; column++) ...[
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
  });

  final bool showImpersonate;
  final bool showTickets;
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
    final innerRadius =
        borderRadius > borderWidth ? borderRadius - borderWidth : 0.0;

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
                    color: colorScheme.primary,
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

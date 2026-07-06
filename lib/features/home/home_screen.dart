import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../api/auth_token_store.dart';
import '../departments/departments_screen.dart';
import '../locations/locations_screen.dart';
import '../users/users_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HomeUserSummary(),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
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
                  ],
                ),
              ],
            ),
          ),
        ),
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
    final isWide = MediaQuery.sizeOf(context).width > 500;
    final tileWidth = isWide ? 88.0 : 68.0;
    final iconBoxSize = isWide ? 72.0 : 52.0;
    final iconSize = isWide ? 32.0 : 24.0;
    final borderRadius = isWide ? 16.0 : 14.0;
    final labelSpacing = isWide ? 8.0 : 6.0;
    final labelFontSize = isWide ? 13.0 : 11.0;

    return SizedBox(
      width: tileWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: SizedBox(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  child: Icon(icon, size: iconSize, color: colorScheme.primary),
                ),
              ),
              SizedBox(height: labelSpacing),
              Text(
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
            ],
          ),
        ),
      ),
    );
  }
}

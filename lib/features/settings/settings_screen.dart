import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_surface.dart';
import '../tickets/complaint_categories_screen.dart';
import '../tickets/internal_categories_screen.dart';
import 'database_management_screen.dart';
import 'miscellaneous_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  children: [
                    _SettingsMenuTile(
                      icon: Icons.category_outlined,
                      title: 'Customer complaint categories',
                      subtitle:
                          'Add or edit categories used when raising complaints',
                      color: primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ComplaintCategoriesScreen(
                              apiClient: apiClient,
                              onLoginAgain: onLoginAgain,
                            ),
                          ),
                        );
                      },
                    ),
                    _SettingsMenuTile(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Internal ticket categories',
                      subtitle:
                          'Add or edit categories used for internal tickets',
                      color: primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => InternalCategoriesScreen(
                              apiClient: apiClient,
                              onLoginAgain: onLoginAgain,
                            ),
                          ),
                        );
                      },
                    ),
                    _SettingsMenuTile(
                      icon: Icons.tune_outlined,
                      title: 'Miscellaneous',
                      subtitle:
                          'Location heartbeat, scan cool-off, ERP and SMS flags',
                      color: primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => MiscellaneousSettingsScreen(
                              apiClient: apiClient,
                              onLoginAgain: onLoginAgain,
                            ),
                          ),
                        );
                      },
                    ),
                    _SettingsMenuTile(
                      icon: Icons.storage_outlined,
                      title: 'Database Management',
                      subtitle:
                          'Create, download, or restore database backups',
                      color: primary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DatabaseManagementScreen(
                              apiClient: apiClient,
                              onLoginAgain: onLoginAgain,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AppSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: color.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';
import 'web_portal_constants.dart';
import 'web_portal_providers.dart';
import 'web_portal_utils.dart';

class WebPortalSettingsScreen extends ConsumerStatefulWidget {
  const WebPortalSettingsScreen({super.key});

  @override
  ConsumerState<WebPortalSettingsScreen> createState() =>
      _WebPortalSettingsScreenState();
}

class _WebPortalSettingsScreenState
    extends ConsumerState<WebPortalSettingsScreen> {
  bool _busy = false;

  static const _coolOffOptions = [
    ('30', '30 seconds'),
    ('60', '1 minute'),
    ('120', '2 minutes'),
    ('300', '5 minutes'),
    ('600', '10 minutes'),
  ];

  static const _heartbeatOptions = [
    ('1', '1 minute'),
    ('3', '3 minutes'),
    ('5', '5 minutes'),
    ('10', '10 minutes'),
    ('15', '15 minutes'),
    ('30', '30 minutes'),
  ];

  Future<void> _saveSetting(String name, String value) async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).updatePortalSetting(
            settingName: name,
            settingValue: value,
          );
      ref.invalidate(portalSettingProvider(name));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setting saved successfully!')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiClientProvider).createBackup();
      ref.invalidate(portalBackupsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup created: ${result.filename ?? result.message ?? 'OK'}',
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _downloadBackup(String filename) async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadBackupBytes(filename);
      final file = File('${Directory.systemTemp.path}/$filename');
      await file.writeAsBytes(bytes);
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        final httpUri = Uri.parse(api.backupDownloadUrl(filename));
        await launchUrl(httpUri, mode: LaunchMode.externalApplication);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $filename')),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup(WebPortalBackupFile backup) async {
    final passkeyController = TextEditingController();
    var confirmed = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Restore Database'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(backup.filename, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'This will DELETE all current data and replace with backup data.',
                style: TextStyle(color: Colors.red),
              ),
              CheckboxListTile(
                value: confirmed,
                onChanged: (v) => setDialog(() => confirmed = v ?? false),
                title: const Text('I understand this will delete all current data'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              TextField(
                controller: passkeyController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Restore Passkey'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmed && passkeyController.text.isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Restore'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      passkeyController.dispose();
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).restoreBackup(
            filename: backup.filename,
            passkey: passkeyController.text,
          );
      passkeyController.dispose();
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
      if (mounted) {
        context.go('${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}');
      }
    } on DioException catch (e) {
      passkeyController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(portalBackupsProvider);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              Text('Mobile App Settings',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                color: Colors.orange.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Global settings affect all mobile app users. Change with caution.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _SettingCard(
                    title: 'Location Heartbeat',
                    icon: Icons.location_on_outlined,
                    settingName: WebPortalSettingNames.minsBetweenHeartbeats,
                    options: _heartbeatOptions,
                    onSave: _saveSetting,
                  ),
                  _SettingCard(
                    title: 'Route Scan Cool Off',
                    icon: Icons.crop_free,
                    settingName: WebPortalSettingNames.coolOffSeconds,
                    options: _coolOffOptions,
                    onSave: _saveSetting,
                  ),
                  _SettingCard(
                    title: 'Update Doc Status to ERP',
                    icon: Icons.sync,
                    settingName: WebPortalSettingNames.updateDocStatusToErp,
                    options: const [('true', 'Enabled'), ('false', 'Disabled')],
                    onSave: _saveSetting,
                  ),
                  _SettingCard(
                    title: 'Send Tracking SMS',
                    icon: Icons.sms_outlined,
                    settingName: WebPortalSettingNames.sendTrackingSms,
                    options: const [('true', 'Enabled'), ('false', 'Disabled')],
                    onSave: _saveSetting,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text('Database Management',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 320,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Database Backup',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            const Text(
                              'Create a compressed backup uploaded to storage.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _busy ? null : _createBackup,
                              icon: const Icon(Icons.backup),
                              label: const Text('Create Backup'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Database Restore',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    )),
                                const Spacer(),
                                TextButton(
                                  onPressed: () =>
                                      ref.invalidate(portalBackupsProvider),
                                  child: const Text('Refresh'),
                                ),
                              ],
                            ),
                            const Text(
                              'Restore is destructive. Create a backup first.',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 12),
                            backupsAsync.when(
                              loading: () =>
                                  const Center(child: CircularProgressIndicator()),
                              error: (e, _) => Text(e.toString()),
                              data: (data) {
                                if (data.backups.isEmpty) {
                                  return const Text('No backups available.');
                                }
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Env')),
                                      DataColumn(label: Text('Type')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Size')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: data.backups.map((b) {
                                      final parsed =
                                          WebPortalUtils.parseBackupFilename(
                                        b.filename,
                                      );
                                      return DataRow(
                                        cells: [
                                          DataCell(
                                            Text(parsed.environment.toUpperCase()),
                                          ),
                                          DataCell(Text(parsed.type)),
                                          DataCell(
                                            Text(WebPortalUtils.formatDateString(
                                              b.lastModified,
                                            )),
                                          ),
                                          DataCell(
                                            Text(WebPortalUtils.formatFileSize(
                                              b.size,
                                            )),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _downloadBackup(
                                                            b.filename,
                                                          ),
                                                  child: const Text('Download'),
                                                ),
                                                TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _restoreBackup(b),
                                                  child: const Text(
                                                    'Restore',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_busy) const LoadingOverlay(),
      ],
    );
  }
}

class _SettingCard extends ConsumerStatefulWidget {
  const _SettingCard({
    required this.title,
    required this.icon,
    required this.settingName,
    required this.options,
    required this.onSave,
  });

  final String title;
  final IconData icon;
  final String settingName;
  final List<(String, String)> options;
  final Future<void> Function(String name, String value) onSave;

  @override
  ConsumerState<_SettingCard> createState() => _SettingCardState();
}

class _SettingCardState extends ConsumerState<_SettingCard> {
  String? _value;

  @override
  Widget build(BuildContext context) {
    final settingAsync = ref.watch(portalSettingProvider(widget.settingName));

    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: settingAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
            data: (setting) {
              _value ??= setting.settingValue;
              final value = _value ?? '';
              final allOptions = List<(String, String)>.from(widget.options);
              if (value.isNotEmpty && !allOptions.any((o) => o.$1 == value)) {
                allOptions.add((value, value));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.icon, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(widget.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: value.isEmpty ? null : value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: allOptions
                        .map(
                          (o) =>
                              DropdownMenuItem(value: o.$1, child: Text(o.$2)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _value = v),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: value.isEmpty
                        ? null
                        : () => widget.onSave(widget.settingName, value),
                    child: const Text('Save Setting'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

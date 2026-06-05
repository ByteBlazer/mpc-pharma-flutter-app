import 'dart:math' show max, min;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/services/location_tracking_service.dart';
import '../../core/services/session_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';
import 'web_portal_backup_download.dart';
import 'web_portal_constants.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_providers.dart';
import 'web_portal_styles.dart';
import 'web_portal_theme.dart';
import 'web_portal_utils.dart';

const _pagePadding = 24.0;
const _cardMinWidth = 280.0;
const _cardMaxWidth = 400.0;
const _restoreCardMaxWidth = 900.0;
const _backupTableMaxHeight = 300.0;
const _backupColEnvWidth = 140.0;
const _backupColTypeWidth = 100.0;
const _backupColSizeWidth = 100.0;
const _backupColActionsWidth = 264.0;
const _backupColDateMinWidth = 200.0;
const _backupTableScrollbarReserve = 16.0;
const _backupTableMinWidth =
    _backupColEnvWidth +
    _backupColTypeWidth +
    _backupColSizeWidth +
    _backupColActionsWidth +
    _backupColDateMinWidth;

class WebPortalSettingsScreen extends ConsumerStatefulWidget {
  const WebPortalSettingsScreen({super.key});

  @override
  ConsumerState<WebPortalSettingsScreen> createState() =>
      _WebPortalSettingsScreenState();
}

class _WebPortalSettingsScreenState
    extends ConsumerState<WebPortalSettingsScreen> {
  String? _busyMessage;

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

  Future<void> _runBusy(String message, Future<void> Function() action) async {
    setState(() => _busyMessage = message);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busyMessage = null);
    }
  }

  Future<void> _saveSetting(String name, String value) async {
    await ref.read(apiClientProvider).updatePortalSetting(
          settingName: name,
          settingValue: value,
        );
  }

  static bool _settingInitiallyLoading(AsyncValue<WebPortalSetting> async) =>
      async.isLoading && !async.hasValue;

  Future<String?> _createBackup() async {
    String? successMessage;
    await _runBusy(
      'Creating backup... This may take a few minutes.',
      () async {
        final result = await ref.read(apiClientProvider).createBackup();
        ref.invalidate(portalBackupsProvider);
        successMessage =
            'Backup created successfully: ${result.filename ?? result.message ?? 'OK'}';
      },
    );
    return successMessage;
  }

  Future<String?> _downloadBackup(String filename) async {
    await _runBusy('Downloading backup...', () async {
      final api = ref.read(apiClientProvider);
      final bytes = await api.downloadBackupBytes(filename);
      downloadBackupFile(filename, Uint8List.fromList(bytes));
    });
    return null;
  }

  Future<void> _restoreBackup(WebPortalBackupFile backup) async {
    final passkeyController = TextEditingController();
    var confirmed = false;
    var restoring = false;
    String? errorMessage;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Theme(
        data: WebPortalTheme.dialogForm(),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final parsed =
                WebPortalUtils.parseBackupFilename(backup.filename);

            Future<void> handleRestore() async {
              setDialogState(() {
                restoring = true;
                errorMessage = null;
              });
              try {
                await ref.read(apiClientProvider).restoreBackup(
                      filename: backup.filename,
                      passkey: passkeyController.text,
                    );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on DioException catch (e) {
                setDialogState(() {
                  restoring = false;
                  errorMessage = ApiClient.parseError(e);
                });
              }
            }

            return Stack(
              children: [
                Dialog(
              backgroundColor: Colors.white,
              elevation: 24,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        color: WebPortalStyles.errorMain,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      child: const Text(
                        '⚠️ Restore Database - DESTRUCTIVE OPERATION',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SettingsInfoBanner(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    backup.filename,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Environment: ${parsed.environment.toUpperCase()} (${parsed.type})',
                                    style: WebPortalStyles.settingsCaption,
                                  ),
                                  Text(
                                    'Size: ${WebPortalUtils.formatFileSize(backup.size)} (${_formatBackupDate(backup.lastModified)})',
                                    style: WebPortalStyles.settingsCaption,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SettingsDangerBanner(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'This will:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const _RestoreConsequenceLine(
                                    icon: Icons.close,
                                    iconColor: WebPortalStyles.errorMain,
                                    text:
                                        'DELETE all current data in the database',
                                  ),
                                  const SizedBox(height: 4),
                                  const _RestoreConsequenceLine(
                                    icon: Icons.check,
                                    iconColor: Color(0xFF2E7D32),
                                    text:
                                        'REPLACE with data from the selected backup',
                                  ),
                                ],
                              ),
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: confirmed,
                              onChanged: restoring
                                  ? null
                                  : (v) => setDialogState(() {
                                        confirmed = v ?? false;
                                        errorMessage = null;
                                      }),
                              title: const Text(
                                'I understand this will delete all current data',
                                style: TextStyle(fontSize: 14),
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            ),
                            TextField(
                              controller: passkeyController,
                              obscureText: true,
                              enabled: !restoring,
                              onChanged: (_) => setDialogState(() {
                                errorMessage = null;
                              }),
                              decoration:
                                  WebPortalMuiDialog.outlinedFieldLabel(
                                'Restore Passkey',
                              ),
                            ),
                            if (errorMessage != null) ...[
                              const SizedBox(height: 12),
                              _SettingsInlineAlert(
                                message: errorMessage!,
                                isError: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    WebPortalMuiDialog.dialogActionsBar([
                      WebPortalMuiDialog.cancelActionButton(
                        dialogContext,
                        enabled: !restoring,
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                      ),
                      _SettingsErrorContainedButton(
                        label: restoring
                            ? 'Restoring...'
                            : 'Restore Database',
                        onPressed: !restoring &&
                                confirmed &&
                                passkeyController.text.isNotEmpty
                            ? handleRestore
                            : null,
                      ),
                    ]),
                  ],
                ),
              ),
                ),
                if (restoring)
                  const LoadingOverlay(
                    message:
                        'Restoring database... Please do not refresh or close this page.',
                    modal: true,
                  ),
              ],
            );
          },
        ),
      ),
    );

    passkeyController.dispose();
    if (ok != true || !mounted) return;

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
      context.go(
        '${AppRoutes.login}?phone=${Uri.encodeComponent(phone ?? '')}',
      );
    }
  }

  String _formatBackupDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return WebPortalUtils.formatDateTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    final backupsAsync = ref.watch(portalBackupsProvider);
    final heartbeatAsync = ref.watch(
      portalSettingProvider(WebPortalSettingNames.minsBetweenHeartbeats),
    );
    final coolOffAsync = ref.watch(
      portalSettingProvider(WebPortalSettingNames.coolOffSeconds),
    );
    final erpAsync = ref.watch(
      portalSettingProvider(WebPortalSettingNames.updateDocStatusToErp),
    );
    final smsAsync = ref.watch(
      portalSettingProvider(WebPortalSettingNames.sendTrackingSms),
    );

    if (_settingInitiallyLoading(heartbeatAsync) ||
        _settingInitiallyLoading(coolOffAsync) ||
        _settingInitiallyLoading(erpAsync) ||
        _settingInitiallyLoading(smsAsync)) {
      return const LoadingOverlay(
        message: 'Loading settings...',
        modal: true,
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(_pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Settings', style: WebPortalStyles.pageTitle(context)),
              const SizedBox(height: 32),
              _SettingsSectionHeader(
                title: 'Mobile App Settings',
                subtitle: 'Manage settings for the mobile app',
                child: _SettingsWarningBanner(
                  child: Text.rich(
                    TextSpan(
                      style: WebPortalStyles.settingsBodySecondary,
                      children: const [
                        TextSpan(
                          text: 'Global Settings Warning: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text:
                              'These settings are global and will affect all users of the mobile app. Please exercise caution when modifying these values as changes will impact the entire system.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = min(
                    _cardMaxWidth,
                    max(
                      _cardMinWidth,
                      (constraints.maxWidth - 72) / 4,
                    ),
                  );
                  return Wrap(
                    spacing: 24,
                    runSpacing: 24,
                    alignment: WrapAlignment.center,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _MobileSettingCard(
                          title: 'Location Heartbeat',
                          description:
                              'The frequency at which location updates are sent to the server, from the mobile app.',
                          fieldLabel: 'Heartbeat Interval',
                          icon: Icons.location_on_outlined,
                          settingName:
                              WebPortalSettingNames.minsBetweenHeartbeats,
                          options: _heartbeatOptions,
                          onSave: (name, value) => _runBusy(
                            'Saving Heartbeat Setting...',
                            () => _saveSetting(name, value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MobileSettingCard(
                          title: 'Route Scan Cool Off',
                          description:
                              'The time interval after which scans from a different route is permitted, in the mobile app.',
                          fieldLabel: 'Cool Off Period',
                          icon: Icons.crop_free,
                          settingName: WebPortalSettingNames.coolOffSeconds,
                          options: _coolOffOptions,
                          onSave: (name, value) => _runBusy(
                            'Saving Cool Off Setting...',
                            () => _saveSetting(name, value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MobileSettingCard(
                          title: 'Update Doc Status to ERP',
                          description:
                              'Controls whether document status updates are sent to the ERP system from the mobile app.',
                          fieldLabel: 'Enable ERP Updates',
                          icon: Icons.sync,
                          settingName:
                              WebPortalSettingNames.updateDocStatusToErp,
                          options: const [
                            ('true', 'Enabled'),
                            ('false', 'Disabled'),
                          ],
                          onSave: (name, value) => _runBusy(
                            'Saving ERP Update Setting...',
                            () => _saveSetting(name, value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MobileSettingCard(
                          title: 'Send Tracking SMS',
                          description:
                              'Controls whether tracking SMS alerts are sent to customers when a document is on trip.',
                          fieldLabel: 'Enable SMS Alerts',
                          icon: Icons.sms_outlined,
                          settingName: WebPortalSettingNames.sendTrackingSms,
                          options: const [
                            ('true', 'Enabled'),
                            ('false', 'Disabled'),
                          ],
                          onSave: (name, value) => _runBusy(
                            'Saving SMS Notification Setting...',
                            () => _saveSetting(name, value),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 48),
              _SettingsSectionHeader(
                title: 'Database Management',
                subtitle: 'Backup and restore database operations',
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = min(
                    _cardMaxWidth,
                    max(_cardMinWidth, constraints.maxWidth * 0.33),
                  );
                  return Column(
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _DatabaseBackupCard(
                              onCreateBackup: () async {
                                try {
                                  return await _createBackup();
                                } on DioException catch (e) {
                                  if (!mounted) rethrow;
                                  return ApiClient.parseError(e);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _restoreCardMaxWidth,
                            minWidth: _cardMinWidth,
                          ),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: _DatabaseRestoreCard(
                              backupsAsync: backupsAsync,
                              onRefresh: () =>
                                  ref.invalidate(portalBackupsProvider),
                              onDownload: (filename) async {
                                try {
                                  await _downloadBackup(filename);
                                } on DioException catch (e) {
                                  if (!context.mounted) return;
                                  await WebPortalMuiDialog.showResultDialog(
                                    context: context,
                                    title: 'Error',
                                    message: ApiClient.parseError(e),
                                  );
                                }
                              },
                              onRestore: _restoreBackup,
                              formatDate: _formatBackupDate,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        if (_busyMessage != null)
          Positioned.fill(
            child: LoadingOverlay(message: _busyMessage!, modal: true),
          ),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.title,
    this.subtitle,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: WebPortalStyles.settingsSectionTitle,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: WebPortalStyles.settingsSectionSubtitle,
          ),
        ],
        if (child != null) ...[
          const SizedBox(height: 16),
          child!,
        ],
      ],
    );
  }
}

class _SettingsWarningBanner extends StatelessWidget {
  const _SettingsWarningBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Material(
          color: const Color(0xFFFFF4E5),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange.shade800,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestoreConsequenceLine extends StatelessWidget {
  const _RestoreConsequenceLine({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
      ],
    );
  }
}

class _SettingsDangerBanner extends StatelessWidget {
  const _SettingsDangerBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFEBEE),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline,
              color: WebPortalStyles.errorMain,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _SettingsInfoBanner extends StatelessWidget {
  const _SettingsInfoBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE3F2FD),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _SettingsCardShell extends StatelessWidget {
  const _SettingsCardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WebPortalPaper(
      elevated: true,
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }
}

class _MobileSettingCard extends ConsumerStatefulWidget {
  const _MobileSettingCard({
    required this.title,
    required this.description,
    required this.fieldLabel,
    required this.icon,
    required this.settingName,
    required this.options,
    required this.onSave,
  });

  final String title;
  final String description;
  final String fieldLabel;
  final IconData icon;
  final String settingName;
  final List<(String, String)> options;
  final Future<void> Function(String name, String value) onSave;

  @override
  ConsumerState<_MobileSettingCard> createState() =>
      _MobileSettingCardState();
}

class _MobileSettingCardState extends ConsumerState<_MobileSettingCard> {
  String? _value;
  bool _saving = false;
  bool _saveSuccess = false;
  bool _saveError = false;

  @override
  Widget build(BuildContext context) {
    final settingAsync = ref.watch(portalSettingProvider(widget.settingName));

    return _SettingsCardShell(
      child: settingAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text(e.toString()),
        data: (setting) {
          _value ??= setting.settingValue;
          final value = _value ?? '';
          final allOptions = List<(String, String)>.from(widget.options);
          if (value.isNotEmpty && !allOptions.any((o) => o.$1 == value)) {
            final label = widget.settingName ==
                    WebPortalSettingNames.coolOffSeconds
                ? '$value seconds'
                : widget.settingName ==
                        WebPortalSettingNames.minsBetweenHeartbeats
                    ? '$value minutes'
                    : value;
            allOptions.add((value, label));
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: AppColors.primary, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: WebPortalStyles.settingsCardTitle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.description,
                style: WebPortalStyles.settingsBodySecondary,
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: value.isEmpty ? null : value,
                isExpanded: true,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                decoration: WebPortalMuiDialog.outlinedFieldLabel(
                  widget.fieldLabel,
                ),
                items: allOptions
                    .map(
                      (o) => DropdownMenuItem(
                        value: o.$1,
                        child: Text(o.$2),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _value = v;
                  _saveSuccess = false;
                  _saveError = false;
                }),
              ),
              const SizedBox(height: 16),
              _SettingsContainedButton(
                label: _saving ? 'Saving...' : 'Save Setting',
                icon: Icons.save_outlined,
                onPressed: value.isEmpty || _saving
                    ? null
                    : () async {
                        setState(() {
                          _saving = true;
                          _saveSuccess = false;
                          _saveError = false;
                        });
                        try {
                          await widget.onSave(widget.settingName, value);
                          if (mounted) {
                            setState(() {
                              _saving = false;
                              _saveSuccess = true;
                            });
                          }
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _saving = false;
                              _saveError = true;
                            });
                          }
                        }
                      },
              ),
              if (_saveError) ...[
                const SizedBox(height: 12),
                _SettingsInlineAlert(
                  message: 'Failed to save setting. Please try again.',
                  isError: true,
                ),
              ],
              if (_saveSuccess) ...[
                const SizedBox(height: 12),
                const _SettingsInlineAlert(
                  message: 'Setting saved successfully!',
                  isError: false,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DatabaseBackupCard extends StatefulWidget {
  const _DatabaseBackupCard({required this.onCreateBackup});

  final Future<String?> Function() onCreateBackup;

  @override
  State<_DatabaseBackupCard> createState() => _DatabaseBackupCardState();
}

class _DatabaseBackupCardState extends State<_DatabaseBackupCard> {
  bool _creating = false;
  String? _successMessage;
  String? _errorMessage;

  Future<void> _handleCreate() async {
    setState(() {
      _creating = true;
      _successMessage = null;
      _errorMessage = null;
    });
    try {
      final message = await widget.onCreateBackup();
      if (!mounted) return;
      setState(() {
        _creating = false;
        if (message != null && message.startsWith('Backup created')) {
          _successMessage = message;
        } else if (message != null) {
          _errorMessage = message;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _creating = false;
          _errorMessage = 'Failed to create backup. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.backup_outlined, color: AppColors.primary, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Database Backup',
                  style: WebPortalStyles.settingsCardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Create a backup of the database. This will upload a compressed backup file to S3 storage.',
            style: WebPortalStyles.settingsBodySecondary,
          ),
          const SizedBox(height: 24),
          _SettingsContainedButton(
            label: _creating ? 'Creating Backup...' : 'Create Backup',
            icon: Icons.backup_outlined,
            onPressed: _creating ? null : _handleCreate,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _SettingsInlineAlert(message: _errorMessage!, isError: true),
          ],
          if (_successMessage != null) ...[
            const SizedBox(height: 12),
            _SettingsInlineAlert(message: _successMessage!, isError: false),
          ],
        ],
      ),
    );
  }
}

class _DatabaseRestoreCard extends StatelessWidget {
  const _DatabaseRestoreCard({
    required this.backupsAsync,
    required this.onRefresh,
    required this.onDownload,
    required this.onRestore,
    required this.formatDate,
  });

  final AsyncValue<WebPortalBackupListResponse> backupsAsync;
  final VoidCallback onRefresh;
  final Future<void> Function(String filename) onDownload;
  final Future<void> Function(WebPortalBackupFile backup) onRestore;
  final String Function(String iso) formatDate;

  @override
  Widget build(BuildContext context) {
    return _SettingsCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.restore, color: WebPortalStyles.errorMain, size: 24),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Database Restore',
                  style: WebPortalStyles.settingsCardTitle,
                ),
              ),
              TextButton(
                onPressed: onRefresh,
                child: const Text(
                  'Refresh',
                  style: WebPortalStyles.dialogActionTextLabelStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsDangerBanner(
            child: Text.rich(
              TextSpan(
                style: WebPortalStyles.settingsBodySecondary.copyWith(
                  color: Colors.black87,
                ),
                children: const [
                  TextSpan(
                    text: 'Danger Zone: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text:
                        'Database restore is a destructive operation that will delete all current data. Always create a backup before restoring.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Restore database from a backup file. Select a backup from the list below.',
            style: WebPortalStyles.settingsBodySecondary,
          ),
          const SizedBox(height: 24),
          backupsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text(e.toString()),
            data: (data) {
              if (data.backups.isEmpty) {
                return const _SettingsInfoBanner(
                  child: Text(
                    'No backups available. Create a backup first.',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }
              return _BackupTable(
                backups: data.backups,
                onDownload: onDownload,
                onRestore: onRestore,
                formatDate: formatDate,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BackupTable extends StatefulWidget {
  const _BackupTable({
    required this.backups,
    required this.onDownload,
    required this.onRestore,
    required this.formatDate,
  });

  final List<WebPortalBackupFile> backups;
  final Future<void> Function(String filename) onDownload;
  final Future<void> Function(WebPortalBackupFile backup) onRestore;
  final String Function(String iso) formatDate;

  @override
  State<_BackupTable> createState() => _BackupTableState();
}

class _BackupTableState extends State<_BackupTable> {
  late final ScrollController _verticalController = ScrollController();
  late final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final scrollsVertically =
            widget.backups.length * 52.0 > _backupTableMaxHeight;
        final scrollbarReserve =
            scrollsVertically ? _backupTableScrollbarReserve : 0.0;
        final contentWidth = max(
          viewportWidth - scrollbarReserve,
          _backupTableMinWidth,
        );

        final table = ClipRect(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BackupTableHeader(contentWidth: contentWidth),
                SizedBox(
                  height: _backupTableMaxHeight,
                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: widget.backups.length,
                    itemBuilder: (context, index) {
                      final backup = widget.backups[index];
                      return _BackupTableRow(
                        contentWidth: contentWidth,
                        backup: backup,
                        onDownload: () => widget.onDownload(backup.filename),
                        onRestore: () => widget.onRestore(backup),
                        formatDate: widget.formatDate,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );

        return SizedBox(
          width: viewportWidth,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: contentWidth > viewportWidth,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        );
      },
    );
  }
}

class _BackupTableHeader extends StatelessWidget {
  const _BackupTableHeader({required this.contentWidth});

  final double contentWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WebPortalStyles.usersTableHeaderBg,
        border: Border(
          bottom: BorderSide(color: WebPortalStyles.borderColor),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: _BackupTableRowLayout(
          contentWidth: contentWidth,
          env: _headerCell('Environment'),
          type: _headerCell('Type'),
          dateTime: _headerCell('Date & Time'),
          size: _headerCell('Size'),
          actions: _headerCell('Actions'),
        ),
      ),
    );
  }

  Widget _headerCell(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(label, style: WebPortalStyles.usersTableHeaderStyle),
    );
  }
}

class _BackupTableRowLayout extends StatelessWidget {
  const _BackupTableRowLayout({
    required this.contentWidth,
    required this.env,
    required this.type,
    required this.dateTime,
    required this.size,
    required this.actions,
  });

  final double contentWidth;
  final Widget env;
  final Widget type;
  final Widget dateTime;
  final Widget size;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    final dateWidth = max(
      _backupColDateMinWidth,
      contentWidth -
          _backupColEnvWidth -
          _backupColTypeWidth -
          _backupColSizeWidth -
          _backupColActionsWidth,
    );

    return SizedBox(
      width: contentWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _backupColEnvWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: env,
            ),
          ),
          SizedBox(
            width: _backupColTypeWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: type,
            ),
          ),
          SizedBox(
            width: dateWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: dateTime,
            ),
          ),
          SizedBox(
            width: _backupColSizeWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: size,
            ),
          ),
          SizedBox(
            width: _backupColActionsWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: actions,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupTableRow extends StatelessWidget {
  const _BackupTableRow({
    required this.contentWidth,
    required this.backup,
    required this.onDownload,
    required this.onRestore,
    required this.formatDate,
  });

  final double contentWidth;
  final WebPortalBackupFile backup;
  final VoidCallback onDownload;
  final VoidCallback onRestore;
  final String Function(String iso) formatDate;

  @override
  Widget build(BuildContext context) {
    final parsed = WebPortalUtils.parseBackupFilename(backup.filename);
    final isProduction = parsed.environment.toLowerCase() == 'production';
    final isAuto = parsed.type.toLowerCase() == 'auto';

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: WebPortalStyles.borderColor),
        ),
      ),
      child: SizedBox(
        height: 52,
        child: _BackupTableRowLayout(
          contentWidth: contentWidth,
          env: _EnvChip(
            label: parsed.environment.toUpperCase(),
            isProduction: isProduction,
          ),
          type: _TypeChip(
            label: parsed.type,
            isAuto: isAuto,
          ),
          dateTime: Text(
            formatDate(backup.lastModified),
            style: WebPortalStyles.usersTableCellStyle,
            overflow: TextOverflow.ellipsis,
          ),
          size: Text(
            WebPortalUtils.formatFileSize(backup.size),
            style: WebPortalStyles.usersTableCellStyle,
          ),
          actions: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SettingsOutlinedButton(
                label: 'Download',
                icon: Icons.download_outlined,
                color: AppColors.primary,
                onPressed: onDownload,
              ),
              const SizedBox(width: 6),
              _SettingsOutlinedButton(
                label: 'Restore',
                color: WebPortalStyles.errorMain,
                onPressed: onRestore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnvChip extends StatelessWidget {
  const _EnvChip({required this.label, required this.isProduction});

  final String label;
  final bool isProduction;

  @override
  Widget build(BuildContext context) {
    return _BackupTablePill(
      label: label,
      backgroundColor:
          isProduction ? WebPortalStyles.errorMain : const Color(0xFF0288D1),
      foregroundColor: Colors.white,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.isAuto});

  final String label;
  final bool isAuto;

  @override
  Widget build(BuildContext context) {
    if (isAuto) {
      return _BackupTablePill(
        label: label,
        borderColor: WebPortalStyles.borderColor,
        foregroundColor: Colors.black87,
      );
    }
    return _BackupTablePill(
      label: label,
      backgroundColor: const Color(0xFF2E7D32),
      foregroundColor: Colors.white,
      fontWeight: FontWeight.w500,
    );
  }
}

/// MUI `Chip` `size="small"` — shrink-wrapped; must not use [Container.alignment].
class _BackupTablePill extends StatelessWidget {
  const _BackupTablePill({
    required this.label,
    this.backgroundColor,
    this.foregroundColor = Colors.black87,
    this.borderColor,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w400,
  });

  final String label;
  final Color? backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          label,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

class _SettingsErrorContainedButton extends StatelessWidget {
  const _SettingsErrorContainedButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: WebPortalStyles.errorMain,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.75,
        ),
      ),
      child: Text(label.toUpperCase()),
    );
  }
}

class _SettingsContainedButton extends StatefulWidget {
  const _SettingsContainedButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  State<_SettingsContainedButton> createState() =>
      _SettingsContainedButtonState();
}

class _SettingsContainedButtonState extends State<_SettingsContainedButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          width: double.infinity,
          decoration: BoxDecoration(
            color: enabled
                ? (_hovered
                    ? WebPortalStyles.usersPrimaryDark
                    : AppColors.primary)
                : AppColors.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label.toUpperCase(),
                style: WebPortalStyles.usersAddUserLabelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsOutlinedButton extends StatelessWidget {
  const _SettingsOutlinedButton({
    required this.label,
    required this.onPressed,
    required this.color,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsInlineAlert extends StatelessWidget {
  const _SettingsInlineAlert({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color =
        isError ? WebPortalStyles.errorMain : const Color(0xFF2E7D32);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isError ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(fontSize: 14, color: color, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

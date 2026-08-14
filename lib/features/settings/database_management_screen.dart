import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_environment.dart';
import '../../app_theme.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_async_list_loader.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'backup_models.dart';

const _recentBackupWindow = Duration(minutes: 5);

bool hasRecentCurrentEnvironmentBackup(List<BackupFile> backups) {
  final env = AppEnvironment.name.trim().toLowerCase();
  if (env.isEmpty) return false;
  final cutoff = DateTime.now().toUtc().subtract(_recentBackupWindow);
  for (final backup in backups) {
    final modified = backup.lastModified?.toUtc();
    if (modified == null || modified.isBefore(cutoff)) continue;
    final filename = backup.filename.toLowerCase();
    if (filename.contains('-$env-')) return true;
    if (backup.environment.toLowerCase() == env) return true;
  }
  return false;
}

String formatBackupDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} '
      '${local.year}, $hour12:$minute $period';
}

class DatabaseManagementScreen extends StatefulWidget {
  const DatabaseManagementScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<DatabaseManagementScreen> createState() =>
      _DatabaseManagementScreenState();
}

class _DatabaseManagementScreenState extends State<DatabaseManagementScreen> {
  final _loader = AppAsyncListLoader<List<BackupFile>>();
  final _scrollController = ScrollController();
  bool _isCreating = false;
  String? _downloadingFilename;

  @override
  void initState() {
    super.initState();
    _loader.initialize(_loadBackups);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<BackupFile>> _loadBackups() {
    return widget.apiClient.listDatabaseBackups();
  }

  Future<void> _refresh() {
    return _loader.reload(load: _loadBackups, setState: setState);
  }

  Future<void> _createBackup() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text('Creating backup... This may take a few minutes.'),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final result = await widget.apiClient.createDatabaseBackup();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final filename = result.filename.trim();
      showAppSnackBar(
        context,
        message: filename.isEmpty
            ? (result.message.isEmpty
                  ? 'Backup created successfully.'
                  : result.message)
            : 'Backup created: $filename',
        type: AppSnackBarType.success,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showAppSnackBar(
        context,
        message: _errorMessage(
          error,
          fallback: 'Failed to create backup. Please try again.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _downloadBackup(BackupFile backup) async {
    if (_downloadingFilename != null) return;
    setState(() => _downloadingFilename = backup.filename);
    try {
      final bytes = await widget.apiClient.downloadDatabaseBackup(
        filename: backup.filename,
      );
      await downloadFile(
        fileName: backup.filename,
        bytes: bytes,
        mimeType: 'application/octet-stream',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: _errorMessage(
          error,
          fallback: 'Failed to download backup. Please try again.',
        ),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _downloadingFilename = null);
    }
  }

  Future<void> _openRestoreFlow(BackupFile backup) async {
    List<BackupFile> knownBackups = const [];
    try {
      knownBackups = await _loader.future;
    } catch (_) {
      knownBackups = const [];
    }
    if (!mounted) return;

    final restored = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _RestoreBackupDialog(
        backup: backup,
        initialHasRecentCurrentEnvBackup: hasRecentCurrentEnvironmentBackup(
          knownBackups,
        ),
        onRecheckRecentBackup: () async {
          final backups = await widget.apiClient.listDatabaseBackups();
          await _refresh();
          return hasRecentCurrentEnvironmentBackup(backups);
        },
        onRestore: (passkey) => widget.apiClient.restoreDatabaseBackup(
          filename: backup.filename,
          passkey: passkey,
        ),
      ),
    );
    if (!mounted || restored != true) return;

    showAppSnackBar(
      context,
      message: 'Database restored. Please log in again.',
      type: AppSnackBarType.success,
    );
    await widget.onLoginAgain();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _errorMessage(Object error, {required String fallback}) {
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(
          title: const Text('Database Management'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _isCreating ? null : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSurface(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Manual backup',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Creates a compressed database dump and uploads it '
                              'to secure storage. Scheduled Auto backups also '
                              'appear in the list below.',
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FilledButton.icon(
                                onPressed: _isCreating ? null : _createBackup,
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.backup_outlined),
                                label: Text(
                                  _isCreating ? 'Creating…' : 'Create Backup',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Available backups',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download a copy, or restore (destructive). Create a '
                      'fresh backup before restoring so the current environment '
                      'can be recovered.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<List<BackupFile>>(
                        key: ValueKey(_loader.refreshToken),
                        future: _loader.future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return AppLoadErrorState(
                              title: 'Failed to load backups',
                              message: snapshot.error.toString(),
                              onRetry: _refresh,
                              onLoginAgain: widget.onLoginAgain,
                            );
                          }

                          final backups = snapshot.data ?? const [];
                          if (backups.isEmpty) {
                            return AppSurface(
                              child: const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No backups available. Create a backup first.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black54,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return AppScrollbar(
                            controller: _scrollController,
                            child: ListView.builder(
                              controller: _scrollController,
                              itemCount: backups.length,
                              itemBuilder: (context, index) {
                                final backup = backups[index];
                                final downloading =
                                    _downloadingFilename == backup.filename;
                                return _BackupCard(
                                  backup: backup,
                                  primary: primary,
                                  dateLabel: formatBackupDate(
                                    backup.lastModified,
                                  ),
                                  isDownloading: downloading,
                                  onDownload: () => _downloadBackup(backup),
                                  onRestore: () => _openRestoreFlow(backup),
                                );
                              },
                            ),
                          );
                        },
                      ),
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

class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.backup,
    required this.primary,
    required this.dateLabel,
    required this.isDownloading,
    required this.onDownload,
    required this.onRestore,
  });

  final BackupFile backup;
  final Color primary;
  final String dateLabel;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppSurface(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                backup.filename,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaChip(
                    label: backup.environment,
                    emphasized: backup.isProduction,
                    primary: primary,
                  ),
                  _MetaChip(
                    label: backup.backupType,
                    emphasized: false,
                    primary: primary,
                  ),
                  _MetaChip(
                    label: backup.sizeLabel,
                    emphasized: false,
                    primary: primary,
                  ),
                  _MetaChip(
                    label: dateLabel,
                    emphasized: false,
                    primary: primary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: isDownloading ? null : onDownload,
                    icon: isDownloading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(isDownloading ? 'Downloading…' : 'Download'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restore'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.emphasized,
    required this.primary,
  });

  final String label;
  final bool emphasized;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? Colors.red.shade50
            : primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? Colors.red.shade200
              : primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized ? Colors.red.shade800 : Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RestoreBackupDialog extends StatefulWidget {
  const _RestoreBackupDialog({
    required this.backup,
    required this.initialHasRecentCurrentEnvBackup,
    required this.onRecheckRecentBackup,
    required this.onRestore,
  });

  final BackupFile backup;
  final bool initialHasRecentCurrentEnvBackup;
  final Future<bool> Function() onRecheckRecentBackup;
  final Future<RestoreBackupResult> Function(String passkey) onRestore;

  @override
  State<_RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends State<_RestoreBackupDialog> {
  final _passkeyController = TextEditingController();
  bool _confirmed = false;
  bool _isBusy = false;
  bool _isRechecking = false;
  late bool _hasRecentCurrentEnvBackup;
  String? _errorMessage;
  bool _isSafetyCheckError = false;
  bool _isPasskeyError = false;
  bool _obscurePasskey = true;

  @override
  void initState() {
    super.initState();
    _hasRecentCurrentEnvBackup = widget.initialHasRecentCurrentEnvBackup;
    _passkeyController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passkeyController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_isBusy &&
      _hasRecentCurrentEnvBackup &&
      _confirmed &&
      _passkeyController.text.trim().isNotEmpty;

  static bool _looksLikeSafetyCheck(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('safety check') ||
        normalized.contains('no recent backup') ||
        (normalized.contains('create a backup first') &&
            normalized.contains('minutes'));
  }

  static bool _looksLikePasskeyError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('passkey') || normalized.contains('password');
  }

  Future<void> _recheckRecentBackup() async {
    if (_isBusy || _isRechecking) return;
    setState(() => _isRechecking = true);
    try {
      final hasRecent = await widget.onRecheckRecentBackup();
      if (!mounted) return;
      setState(() {
        _hasRecentCurrentEnvBackup = hasRecent;
        if (hasRecent) {
          _isSafetyCheckError = false;
          if (_errorMessage != null && _looksLikeSafetyCheck(_errorMessage!)) {
            _errorMessage = null;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().trim().isEmpty
            ? 'Failed to refresh backup list.'
            : error.toString();
      });
    } finally {
      if (mounted) setState(() => _isRechecking = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final passkey = _passkeyController.text.trim();
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _isSafetyCheckError = false;
      _isPasskeyError = false;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Restoring database... Please do not close the app.',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await widget.onRestore(passkey);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final text = error.toString().trim();
      final message = text.isEmpty
          ? 'Failed to restore backup. Please try again.'
          : text;
      final safety = _looksLikeSafetyCheck(message);
      setState(() {
        _isBusy = false;
        _errorMessage = message;
        _isSafetyCheckError = safety;
        _isPasskeyError = !safety && _looksLikePasskeyError(message);
        if (safety) _hasRecentCurrentEnvBackup = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;
    final dateLabel = formatBackupDate(backup.lastModified);
    final envName = AppEnvironment.name;

    return AlertDialog(
      title: const Text('Restore database'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  backup.isProduction
                      ? 'This will permanently delete all current PRODUCTION '
                            'database data and replace it with the selected backup.'
                      : 'This will permanently delete all current database data '
                            'and replace it with the selected backup.',
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (!_hasRecentCurrentEnvBackup) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Recent backup required',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Create a backup of the current "$envName" environment '
                        'first. A backup from the last 30 minutes is required '
                        'before restore can proceed. Cancel this dialog, use '
                        'Create Backup, then open Restore again.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isRechecking ? null : _recheckRecentBackup,
                        icon: _isRechecking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(
                          _isRechecking
                              ? 'Checking…'
                              : 'I created a backup — recheck',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else
                const Text(
                  'A recent backup of the current environment was found. '
                  'You can proceed with restore.',
                  style: TextStyle(color: Colors.black54, height: 1.35),
                ),
              const SizedBox(height: 16),
              _RestoreDetailRow(label: 'Filename', value: backup.filename),
              _RestoreDetailRow(
                label: 'Environment',
                value: backup.environment,
              ),
              _RestoreDetailRow(label: 'Type', value: backup.backupType),
              _RestoreDetailRow(label: 'Size', value: backup.sizeLabel),
              _RestoreDetailRow(label: 'Date', value: dateLabel),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _confirmed,
                onChanged: !_hasRecentCurrentEnvBackup || _isBusy
                    ? null
                    : (value) => setState(() => _confirmed = value == true),
                title: const Text(
                  'I understand that current data will be deleted and replaced.',
                  style: TextStyle(fontSize: 14, height: 1.3),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passkeyController,
                enabled: _hasRecentCurrentEnvBackup && !_isBusy,
                obscureText: _obscurePasskey,
                decoration: InputDecoration(
                  labelText: 'Restore passkey',
                  suffixIcon: IconButton(
                    tooltip: _obscurePasskey ? 'Show' : 'Hide',
                    onPressed: () =>
                        setState(() => _obscurePasskey = !_obscurePasskey),
                    icon: Icon(
                      _obscurePasskey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (_canSubmit) _submit();
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isSafetyCheckError
                        ? Colors.orange.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSafetyCheckError
                          ? Colors.orange.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isSafetyCheckError
                            ? 'Recent backup required'
                            : _isPasskeyError
                            ? 'Invalid passkey'
                            : 'Restore failed',
                        style: TextStyle(
                          color: _isSafetyCheckError
                              ? Colors.orange.shade900
                              : Colors.red.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: _isSafetyCheckError
                              ? Colors.orange.shade900
                              : Colors.red.shade800,
                          height: 1.35,
                        ),
                      ),
                      if (_isSafetyCheckError) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Create a backup from this screen, then tap recheck '
                          'or open Restore again within 30 minutes.',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isRechecking
                              ? null
                              : _recheckRecentBackup,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Recheck recent backup'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: const Text('Restore'),
        ),
      ],
    );
  }
}

class _RestoreDetailRow extends StatelessWidget {
  const _RestoreDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

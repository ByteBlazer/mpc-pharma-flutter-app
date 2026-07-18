import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import 'setting_models.dart';

class MiscellaneousSettingsScreen extends StatefulWidget {
  const MiscellaneousSettingsScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<MiscellaneousSettingsScreen> createState() =>
      _MiscellaneousSettingsScreenState();
}

class _MiscellaneousSettingsScreenState
    extends State<MiscellaneousSettingsScreen> {
  final _scrollController = ScrollController();
  late Future<Map<MiscSettingKey, String>> _loadFuture;
  int _refreshToken = 0;

  static const _heartbeatOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];

  static const _coolOffOptions = [
    5,
    10,
    15,
    20,
    30,
    45,
    60,
    90,
    120,
    180,
    240,
    300,
    450,
    600,
  ];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadSettings();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<Map<MiscSettingKey, String>> _loadSettings() async {
    final entries = await Future.wait(
      MiscSettingKey.values.map((key) async {
        final setting = await widget.apiClient.getAppSetting(
          settingName: key.apiName,
        );
        return MapEntry(key, setting.settingValue);
      }),
    );
    return Map<MiscSettingKey, String>.fromEntries(entries);
  }

  Future<void> _refresh() async {
    final next = _loadSettings();
    setState(() {
      _refreshToken += 1;
      _loadFuture = next;
    });
    await next;
  }

  IconData _iconFor(MiscSettingKey key) {
    return switch (key) {
      MiscSettingKey.locationHeartbeat => Icons.location_on_outlined,
      MiscSettingKey.routeScanCoolOff => Icons.qr_code_scanner_outlined,
      MiscSettingKey.updateDocStatusToErp => Icons.sync_outlined,
      MiscSettingKey.sendTrackingSms => Icons.sms_outlined,
    };
  }

  List<String> _optionsFor(MiscSettingKey key, String currentValue) {
    if (key.isBoolean) {
      return const ['true', 'false'];
    }
    if (key == MiscSettingKey.locationHeartbeat) {
      final values = _heartbeatOptions.map((v) => v.toString()).toList();
      _ensureCurrentInOptions(values, currentValue);
      return values;
    }
    final values = _coolOffOptions.map((v) => v.toString()).toList();
    _ensureCurrentInOptions(values, currentValue);
    return values;
  }

  void _ensureCurrentInOptions(List<String> options, String currentValue) {
    final trimmed = currentValue.trim();
    if (trimmed.isEmpty) return;
    if (!options.contains(trimmed)) {
      options.add(trimmed);
      options.sort((a, b) {
        final ai = int.tryParse(a) ?? 0;
        final bi = int.tryParse(b) ?? 0;
        return ai.compareTo(bi);
      });
    }
  }

  String _labelFor(MiscSettingKey key, String value) {
    if (key.isBoolean) {
      return value.toLowerCase() == 'true' ? 'Enabled' : 'Disabled';
    }
    if (key == MiscSettingKey.locationHeartbeat) {
      final mins = int.tryParse(value) ?? 0;
      return mins == 1 ? '1 minute' : '$value minutes';
    }
    final seconds = int.tryParse(value) ?? 0;
    return seconds == 1 ? '1 second' : '$value seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AppScreenScaffold(
        appBar: AppBar(
          title: const Text('Miscellaneous'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: FutureBuilder<Map<MiscSettingKey, String>>(
            key: ValueKey(_refreshToken),
            future: _loadFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return AppLoadErrorState(
                  title: 'Failed to load settings',
                  message: snapshot.error.toString(),
                  onRetry: _refresh,
                  onLoginAgain: widget.onLoginAgain,
                );
              }

              final values = snapshot.data ?? const {};
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final medium = constraints.maxWidth >= 640;
                  final columns = wide ? 2 : (medium ? 2 : 1);

                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: AppScrollbar(
                          controller: _scrollController,
                          child: GridView.builder(
                            controller: _scrollController,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: 280,
                            ),
                            itemCount: MiscSettingKey.values.length,
                            itemBuilder: (context, index) {
                              final key = MiscSettingKey.values[index];
                              return _MiscSettingCard(
                                settingKey: key,
                                icon: _iconFor(key),
                                initialValue: values[key] ?? '',
                                options: _optionsFor(key, values[key] ?? ''),
                                labelBuilder: (value) =>
                                    _labelFor(key, value),
                                apiClient: widget.apiClient,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiscSettingCard extends StatefulWidget {
  const _MiscSettingCard({
    required this.settingKey,
    required this.icon,
    required this.initialValue,
    required this.options,
    required this.labelBuilder,
    required this.apiClient,
  });

  final MiscSettingKey settingKey;
  final IconData icon;
  final String initialValue;
  final List<String> options;
  final String Function(String value) labelBuilder;
  final ApiClient apiClient;

  @override
  State<_MiscSettingCard> createState() => _MiscSettingCardState();
}

class _MiscSettingCardState extends State<_MiscSettingCard> {
  late String _selectedValue;
  late String _savedValue;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedValue = _normalizeInitial(widget.initialValue);
    _savedValue = _selectedValue;
  }

  @override
  void didUpdateWidget(covariant _MiscSettingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selectedValue = _normalizeInitial(widget.initialValue);
      _savedValue = _selectedValue;
    }
  }

  String _normalizeInitial(String raw) {
    final trimmed = raw.trim();
    if (widget.settingKey.isBoolean) {
      return trimmed.toLowerCase() == 'true' ? 'true' : 'false';
    }
    if (trimmed.isEmpty && widget.options.isNotEmpty) {
      return widget.options.first;
    }
    return trimmed;
  }

  bool get _isDirty => _selectedValue != _savedValue;

  Future<void> _save() async {
    if (_isSaving || !_isDirty) return;
    setState(() => _isSaving = true);
    try {
      final result = await widget.apiClient.updateAppSetting(
        settingName: widget.settingKey.apiName,
        settingValue: _selectedValue,
      );
      if (!mounted) return;
      setState(() {
        _savedValue = result.newValue.trim().isEmpty
            ? _selectedValue
            : result.newValue.trim();
        _selectedValue = _savedValue;
        if (widget.settingKey.isBoolean) {
          _selectedValue =
              _savedValue.toLowerCase() == 'true' ? 'true' : 'false';
          _savedValue = _selectedValue;
        }
      });
      showAppSnackBar(
        context,
        message: result.message.trim().isEmpty
            ? 'Setting saved.'
            : result.message,
        type: AppSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final options = widget.options;
    final dropdownValue =
        options.contains(_selectedValue) ? _selectedValue : null;

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.settingKey.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                widget.settingKey.helpText,
                style: const TextStyle(
                  color: Colors.black54,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey('${widget.settingKey.apiName}-$_selectedValue'),
              initialValue: dropdownValue,
              decoration: InputDecoration(
                labelText: widget.settingKey.fieldLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final option in options)
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text(widget.labelBuilder(option)),
                  ),
              ],
              onChanged: _isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedValue = value);
                    },
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving || !_isDirty ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save setting'),
            ),
          ],
        ),
      ),
    );
  }
}

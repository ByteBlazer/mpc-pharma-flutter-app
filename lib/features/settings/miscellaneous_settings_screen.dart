import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_snack_bar.dart';
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

  static const _heartbeatOptions = [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
  ];

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

  static final _deliveryCooldownOptions =
      List<int>.generate(61, (index) => index);

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
      MiscSettingKey.defaultGreeting => Icons.waving_hand_outlined,
      MiscSettingKey.minVersionAndroid => Icons.android,
      MiscSettingKey.minVersionIos => Icons.phone_iphone,
      MiscSettingKey.appUpdateMessage => Icons.system_update_alt_outlined,
      MiscSettingKey.androidStoreUrl => Icons.shop_outlined,
      MiscSettingKey.iosStoreUrl => Icons.storefront_outlined,
      MiscSettingKey.deliveryCustomerCooldown => Icons.timer_outlined,
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
    if (key == MiscSettingKey.deliveryCustomerCooldown) {
      final values =
          _deliveryCooldownOptions.map((v) => v.toString()).toList();
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
    if (key == MiscSettingKey.deliveryCustomerCooldown) {
      final mins = int.tryParse(value) ?? 0;
      if (mins == 0) return 'Disabled (0 minutes)';
      return mins == 1 ? '1 minute' : '$mins minutes';
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
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: AppScrollbar(
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        itemCount: MiscSettingKey.values.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 32,
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                        itemBuilder: (context, index) {
                          final key = MiscSettingKey.values[index];
                          return _MiscSettingRow(
                            settingKey: key,
                            icon: _iconFor(key),
                            initialValue: values[key] ?? '',
                            options: _optionsFor(key, values[key] ?? ''),
                            labelBuilder: (value) => _labelFor(key, value),
                            apiClient: widget.apiClient,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MiscSettingRow extends StatefulWidget {
  const _MiscSettingRow({
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
  State<_MiscSettingRow> createState() => _MiscSettingRowState();
}

class _MiscSettingRowState extends State<_MiscSettingRow> {
  late String _selectedValue;
  late String _savedValue;
  TextEditingController? _textController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _applyInitial(widget.initialValue);
  }

  @override
  void dispose() {
    _textController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MiscSettingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _applyInitial(widget.initialValue);
    }
  }

  void _applyInitial(String raw) {
    if (widget.settingKey.usesTextField) {
      final trimmed = raw.trim();
      _textController ??= TextEditingController();
      _textController!.text = trimmed;
      _savedValue = trimmed;
      return;
    }
    _selectedValue = _normalizeInitial(raw);
    _savedValue = _selectedValue;
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

  String get _currentValue {
    if (widget.settingKey.usesTextField) {
      return _textController?.text.trim() ?? '';
    }
    return _selectedValue;
  }

  bool get _isDirty => _currentValue != _savedValue;

  double _inputMaxWidth(MiscSettingKey key) {
    return switch (key.inputType) {
      MiscSettingInputType.boolean => 140,
      MiscSettingInputType.intSelect => 220,
      MiscSettingInputType.semverOptional => 160,
      MiscSettingInputType.textOptional => 320,
      MiscSettingInputType.textRequired => 360,
      MiscSettingInputType.urlOptional => 420,
    };
  }

  Future<void> _save() async {
    if (_isSaving || !_isDirty) return;

    final value = _currentValue;
    final validationError = widget.settingKey.validateValue(value);
    if (validationError != null) {
      showAppSnackBar(
        context,
        message: validationError,
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final result = await widget.apiClient.updateAppSetting(
        settingName: widget.settingKey.apiName,
        settingValue: value,
      );
      if (!mounted) return;
      setState(() {
        _savedValue = result.newValue.trim().isEmpty
            ? value
            : result.newValue.trim();
        if (widget.settingKey.usesTextField) {
          _textController?.text = _savedValue;
        } else {
          _selectedValue = _savedValue;
          if (widget.settingKey.isBoolean) {
            _selectedValue =
                _savedValue.toLowerCase() == 'true' ? 'true' : 'false';
            _savedValue = _selectedValue;
          }
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

  Widget _buildInput(double maxWidth) {
    final decoration = InputDecoration(
      labelText: widget.settingKey.fieldLabel,
      hintText: widget.settingKey.placeholder,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      counterText: widget.settingKey.maxLength == null ? '' : null,
    );

    if (widget.settingKey.usesTextField) {
      final controller = _textController!;
      final isUrl =
          widget.settingKey.inputType == MiscSettingInputType.urlOptional;
      return TextFormField(
        controller: controller,
        enabled: !_isSaving,
        keyboardType: isUrl ? TextInputType.url : TextInputType.text,
        maxLines: isUrl ? 2 : 1,
        maxLength: widget.settingKey.maxLength,
        onChanged: (_) => setState(() {}),
        decoration: decoration,
      );
    }

    final options = widget.options;
    final dropdownValue =
        options.contains(_selectedValue) ? _selectedValue : null;

    return DropdownButtonFormField<String>(
      key: ValueKey('${widget.settingKey.apiName}-$_selectedValue'),
      initialValue: dropdownValue,
      decoration: decoration,
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
    );
  }

  Widget _buildSaveButton() {
    return FilledButton(
      onPressed: _isSaving || !_isDirty ? null : _save,
      style: FilledButton.styleFrom(
        minimumSize: const Size(72, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: _isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Save'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final inputMaxWidth = _inputMaxWidth(widget.settingKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, size: 18, color: primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.settingKey.title,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: Text(
            widget.settingKey.helpText,
            style: const TextStyle(
              color: Colors.black54,
              height: 1.35,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 26),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final rowMax = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : inputMaxWidth + 96;
              final fitsInline = rowMax >= inputMaxWidth + 96;

              if (fitsInline) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: inputMaxWidth),
                      child: _buildInput(inputMaxWidth),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildSaveButton(),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: rowMax.clamp(160, inputMaxWidth),
                    ),
                    child: _buildInput(inputMaxWidth),
                  ),
                  _buildSaveButton(),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

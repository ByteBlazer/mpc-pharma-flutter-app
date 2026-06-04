import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import 'web_portal_filter_field_dom.dart';
import 'web_portal_styles.dart';

/// Browser-native `<input type="date">` + `showPicker()` — styled like MUI outlined fields.
class WebPortalDateField extends StatefulWidget {
  const WebPortalDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? min;
  final DateTime? max;

  static String formatDisplay(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd MMM yyyy').format(d);
  }

  static String formatApi(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  State<WebPortalDateField> createState() => _WebPortalDateFieldState();
}

class _WebPortalDateFieldState extends State<WebPortalDateField> {
  static int _nextId = 0;

  late final String _viewType;
  web.HTMLDivElement? _shell;
  web.HTMLInputElement? _input;
  web.HTMLSpanElement? _display;
  web.HTMLButtonElement? _clearBtn;
  web.HTMLDivElement? _dateBox;
  bool _registered = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'wp-date-field-${_nextId++}';
    _registerFactory();
  }

  @override
  void didUpdateWidget(covariant WebPortalDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDom();
  }

  void _registerFactory() {
    if (_registered) return;
    _registered = true;
    final label = widget.label;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final shell = web.HTMLDivElement()
        ..className = 'wp-date-shell'
        ..style.width = '100%'
        ..style.height = '${WebPortalStyles.filterFieldHeight}px'
        ..style.display = 'flex'
        ..style.alignItems = 'flex-end'
        ..style.boxSizing = 'border-box'
        ..style.overflow = 'hidden';
      shell.innerHTML = _shellHtml(label).toJS;
      _shell = shell;
      _input = shell.querySelector('input') as web.HTMLInputElement?;
      _display = shell.querySelector('.wp-date-text') as web.HTMLSpanElement?;
      _clearBtn = shell.querySelector('.wp-field-clear') as web.HTMLButtonElement?;
      _dateBox = shell.querySelector('.wp-date-box') as web.HTMLDivElement?;

      _dateBox?.addEventListener('click', _onBoxClick.toJS);
      _clearBtn?.addEventListener('click', _onClearClick.toJS);
      _input?.addEventListener('change', _onInputChange.toJS);
      _input?.addEventListener('input', _onInputChange.toJS);

      _syncDom();
      return shell;
    });
  }

  void _onBoxClick(web.Event event) {
    final input = _input;
    if (input == null) return;
    event.stopPropagation();
    input.showPicker();
  }

  void _onClearClick(web.Event event) {
    event.stopPropagation();
    final input = _input;
    if (input != null) input.value = '';
    widget.onChanged(null);
    _syncDom();
  }

  void _onInputChange(web.Event _) {
    final raw = _input?.value ?? '';
    if (raw.isEmpty) {
      widget.onChanged(null);
      return;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      widget.onChanged(DateTime(parsed.year, parsed.month, parsed.day));
    }
  }

  void _syncDom() {
    final input = _input;
    final display = _display;
    if (input == null || display == null) return;

    final api = WebPortalDateField.formatApi(widget.value);
    input.value = api;
    input.min = widget.min != null
        ? WebPortalDateField.formatApi(widget.min)
        : '2020-01-01';
    input.max = widget.max != null
        ? WebPortalDateField.formatApi(widget.max)
        : WebPortalDateField.formatApi(
            DateTime.now().add(const Duration(days: 365)),
          );

    final text = WebPortalDateField.formatDisplay(widget.value);
    if (text.isEmpty) {
      display.textContent = 'Click to select date';
      display.className = 'wp-date-text placeholder';
    } else {
      display.textContent = text;
      display.className = 'wp-date-text';
    }
    WebPortalFilterFieldDom.setClearVisible(_clearBtn, widget.value != null);
  }

  static String _shellHtml(String label) {
    final safeLabel = label
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    return '''
<style>
${WebPortalFilterFieldDom.clearCss}
.wp-date-shell{font-family:Roboto,Helvetica,Arial,sans-serif;user-select:none;margin:0;padding:0;display:flex;align-items:flex-end;width:100%;height:100%;box-sizing:border-box}
.wp-date-wrap{position:relative;width:100%;height:40px}
.wp-date-label{position:absolute;top:0;left:12px;transform:translateY(-50%);font-size:12px;color:#757575;background:#fff;padding:0 4px;z-index:2;line-height:1.2;white-space:nowrap}
.wp-date-box{width:100%;height:40px;border:1px solid rgba(0,0,0,0.23);border-radius:4px;box-sizing:border-box;background:#fff;display:flex;align-items:center;padding:0 4px 0 12px;gap:8px;cursor:pointer}
.wp-date-box:hover{border-color:rgba(0,0,0,0.87)}
.wp-date-icon{width:18px;height:18px;flex-shrink:0;color:#757575;display:block}
.wp-date-text{font-size:14px;line-height:1.4;color:#212121;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin:0;padding:0}
.wp-date-text.placeholder{color:#757575}
.wp-date-input{position:absolute;opacity:0;width:0;height:0;pointer-events:none}
</style>
<div class="wp-date-wrap">
<span class="wp-date-label">$safeLabel</span>
<div class="wp-date-box">
<svg class="wp-date-icon" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10zM5 8V6h14v2H5z"/></svg>
<span class="wp-date-text placeholder">Click to select date</span>
${WebPortalFilterFieldDom.clearButtonHtml}
</div>
</div>
<input class="wp-date-input" type="date" />
''';
  }

  @override
  Widget build(BuildContext context) {
    if (_shell == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncDom();
      });
    }
    return HtmlElementView(viewType: _viewType);
  }
}

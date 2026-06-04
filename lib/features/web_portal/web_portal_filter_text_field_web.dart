import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_portal_filter_field_dom.dart';
import 'web_portal_styles.dart';

/// Browser-native text input — same 56px / 40px shell as date and dropdown fields.
class WebPortalFilterTextField extends StatefulWidget {
  const WebPortalFilterTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.suffixIcon,
    this.onCleared,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final VoidCallback? onCleared;

  @override
  State<WebPortalFilterTextField> createState() =>
      _WebPortalFilterTextFieldState();
}

class _WebPortalFilterTextFieldState extends State<WebPortalFilterTextField> {
  static int _nextId = 0;

  late final String _viewType;
  web.HTMLInputElement? _input;
  web.HTMLButtonElement? _clearBtn;
  bool _registered = false;
  bool _syncingFromController = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'wp-filter-text-${_nextId++}';
    widget.controller.addListener(_onControllerChanged);
    _registerFactory();
  }

  @override
  void didUpdateWidget(covariant WebPortalFilterTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _syncDomFromController();
    _updateClearVisibility();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (_syncingFromController) return;
    _syncDomFromController();
    _updateClearVisibility();
  }

  void _registerFactory() {
    if (_registered) return;
    _registered = true;
    final label = widget.label;
    final hint = widget.hint ?? '';
    final isNumeric = widget.keyboardType == TextInputType.number;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final shell = web.HTMLDivElement()
        ..className = 'wp-text-shell'
        ..style.width = '100%'
        ..style.height = '${WebPortalStyles.filterFieldHeight}px'
        ..style.display = 'flex'
        ..style.alignItems = 'flex-end'
        ..style.boxSizing = 'border-box'
        ..style.overflow = 'hidden';
      shell.innerHTML = _shellHtml(label, hint, isNumeric).toJS;

      _input = shell.querySelector('input') as web.HTMLInputElement?;
      _clearBtn = shell.querySelector('.wp-field-clear') as web.HTMLButtonElement?;

      _input?.addEventListener('input', _onInput.toJS);
      _clearBtn?.addEventListener('click', _onClearClick.toJS);

      _syncDomFromController();
      _updateClearVisibility();
      return shell;
    });
  }

  void _onInput(web.Event _) {
    final value = _input?.value ?? '';
    _syncingFromController = true;
    widget.controller.text = value;
    widget.controller.selection = TextSelection.collapsed(offset: value.length);
    _syncingFromController = false;
    _updateClearVisibility();
  }

  void _onClearClick(web.Event event) {
    event.stopPropagation();
    _input?.value = '';
    _syncingFromController = true;
    widget.controller.clear();
    _syncingFromController = false;
    _updateClearVisibility();
    widget.onCleared?.call();
    _input?.focus();
  }

  void _syncDomFromController() {
    final input = _input;
    if (input == null) return;
    final text = widget.controller.text;
    if (input.value != text) {
      input.value = text;
    }
  }

  void _updateClearVisibility() {
    WebPortalFilterFieldDom.setClearVisible(
      _clearBtn,
      widget.controller.text.isNotEmpty,
    );
  }

  static String _shellHtml(String label, String hint, bool isNumeric) {
    final safeLabel = _escape(label);
    final safeHint = _escape(hint);
    final inputType = isNumeric ? 'text' : 'text';
    final inputMode = isNumeric ? 'numeric' : 'text';
    return '''
<style>
${WebPortalFilterFieldDom.clearCss}
.wp-text-shell{font-family:Roboto,Helvetica,Arial,sans-serif;margin:0;padding:0;width:100%;height:100%;box-sizing:border-box}
.wp-text-wrap{position:relative;width:100%;height:40px}
.wp-text-label{position:absolute;top:0;left:12px;transform:translateY(-50%);font-size:12px;color:#757575;background:#fff;padding:0 4px;z-index:2;line-height:1.2;white-space:nowrap;pointer-events:none}
.wp-text-box{width:100%;height:40px;border:1px solid rgba(0,0,0,0.23);border-radius:4px;box-sizing:border-box;background:#fff;display:flex;align-items:center;padding:0 4px 0 12px;gap:4px}
.wp-text-box:focus-within{border-color:#1976d2;border-width:2px;padding:0 3px 0 11px}
.wp-text-input{flex:1;min-width:0;border:none;outline:none;font-size:14px;line-height:1.4;color:#212121;background:transparent;font-family:inherit;margin:0;padding:0;height:100%}
.wp-text-input::placeholder{color:#757575}
</style>
<div class="wp-text-wrap">
<span class="wp-text-label">$safeLabel</span>
<div class="wp-text-box">
<input class="wp-text-input" type="$inputType" inputmode="$inputMode" placeholder="$safeHint" autocomplete="off" />
${WebPortalFilterFieldDom.clearButtonHtml}
</div>
</div>
''';
  }

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncDomFromController();
        _updateClearVisibility();
      }
    });
    return HtmlElementView(viewType: _viewType);
  }
}

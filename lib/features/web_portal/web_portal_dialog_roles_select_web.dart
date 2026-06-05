import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../core/theme/app_colors.dart';
import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_dom.dart';
import 'web_portal_styles.dart';

/// DOM multi-select for dialog roles — MUI `Select` multiple + `Chip` renderValue.
class WebPortalDialogRolesSelectImpl extends StatefulWidget {
  const WebPortalDialogRolesSelectImpl({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.hasError = false,
  });

  final List<WebPortalDropdownOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final bool hasError;

  @override
  State<WebPortalDialogRolesSelectImpl> createState() =>
      _WebPortalDialogRolesSelectImplState();
}

class _MultiMenuArgs {
  const _MultiMenuArgs({required this.rows, required this.selectedIds});
  final List<DomDropdownOptionRow> rows;
  final List<String> selectedIds;
}

String _primaryHex() {
  final c = AppColors.primary;
  return '#${c.toARGB32().toRadixString(16).substring(2)}';
}

String _buildRolesMenuHtml(
  List<DomDropdownOptionRow> rows,
  Set<String> selectedIds,
) {
  if (rows.isEmpty) {
    return '<div class="wp-roles-empty">No roles available</div>';
  }
  final buf = StringBuffer();
  for (final r in rows) {
    final checked = selectedIds.contains(r.id);
    final classes = <String>['wp-roles-item'];
    if (checked) classes.add('selected');
    if (r.bold) classes.add('bold');
    final id = WebPortalFilterDropdownDom.escapeAttr(r.id);
    final label = WebPortalFilterDropdownDom.escapeText(r.label);
    final checkedAttr = checked ? ' checked' : '';
    buf.write(
      '<label class="${classes.join(' ')}" data-dd-id="$id">'
      '<input type="checkbox" data-dd-id="$id"$checkedAttr aria-label="$label"/>'
      '<span class="wp-roles-item-label">$label</span>'
      '</label>',
    );
  }
  return buf.toString();
}

String _buildMultiMenuIsolate(_MultiMenuArgs args) {
  return _buildRolesMenuHtml(args.rows, args.selectedIds.toSet());
}

class _WebPortalDialogRolesSelectImplState
    extends State<WebPortalDialogRolesSelectImpl> {
  static int _nextId = 0;

  static const _menuMaxHeightPx = 280;
  static final _fieldHeightPx = WebPortalStyles.dialogFormFieldHeight.round();

  late final String _viewType;
  web.HTMLDivElement? _root;
  web.HTMLDivElement? _wrap;
  web.HTMLDivElement? _menu;
  web.HTMLDivElement? _scroll;
  web.HTMLDivElement? _trigger;
  web.HTMLDivElement? _chips;
  bool _registered = false;
  bool _menuOpen = false;
  List<DomDropdownOptionRow>? _lastRows;
  void Function(web.Event)? _docClickListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'wp-dialog-roles-${_nextId++}';
    _registerFactory();
    _scheduleMenuSync();
  }

  @override
  void didUpdateWidget(covariant WebPortalDialogRolesSelectImpl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameOptions(oldWidget.options, widget.options) ||
        oldWidget.selectedIds != widget.selectedIds) {
      _scheduleMenuSync();
    }
    if (oldWidget.hasError != widget.hasError) {
      _syncErrorState();
    }
    _syncDisplay();
    _syncWrapState();
  }

  @override
  void dispose() {
    _detachDocumentListener();
    _menu?.remove();
    super.dispose();
  }

  bool _sameOptions(
    List<WebPortalDropdownOption> a,
    List<WebPortalDropdownOption> b,
  ) {
    if (identical(a, b) || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].label != b[i].label) return false;
    }
    return true;
  }

  List<DomDropdownOptionRow> _toRows() => [
        for (final o in widget.options)
          DomDropdownOptionRow(id: o.id, label: o.label, bold: o.bold),
      ];

  void _scheduleMenuSync() {
    final rows = _toRows();
    _lastRows = rows;
    final args = _MultiMenuArgs(
      rows: rows,
      selectedIds: widget.selectedIds.toList(),
    );
    compute(_buildMultiMenuIsolate, args).then((html) {
      if (!mounted || !identical(_lastRows, rows)) return;
      _scroll?.innerHTML = html.toJS;
    });
  }

  String _rolesStyles() {
    final primary = _primaryHex();
    final selectedBg = 'rgba(73,151,155,0.08)';
    return '''
<style>
.wp-roles-root{position:relative;width:100%;height:${_fieldHeightPx}px;font-family:Roboto,Helvetica,Arial,sans-serif;box-sizing:border-box;overflow:visible}
.wp-roles-wrap{position:relative;width:100%;height:${_fieldHeightPx}px;overflow:visible}
.wp-roles-label{position:absolute;top:0;left:12px;transform:translateY(-50%);font-size:12px;color:#757575;background:#fff;padding:0 4px;z-index:2;line-height:1.2;white-space:nowrap;pointer-events:none;transition:color .15s}
.wp-roles-label .req{color:#d32f2f}
.wp-roles-wrap.focused .wp-roles-label{color:$primary}
.wp-roles-trigger{width:100%;height:${_fieldHeightPx}px;border:1px solid rgba(0,0,0,0.23);border-radius:4px;background:#fff;box-sizing:border-box;display:flex;align-items:center;padding:0 36px 0 12px;gap:4px;cursor:pointer;transition:border-color .15s}
.wp-roles-trigger:hover{border-color:rgba(0,0,0,0.87)}
.wp-roles-trigger.focused{border:2px solid $primary;padding:0 35px 0 11px}
.wp-roles-trigger.error{border:1px solid #d32f2f}
.wp-roles-trigger.error.focused{border:2px solid #d32f2f;padding:0 35px 0 11px}
.wp-roles-wrap.error .wp-roles-label{color:#d32f2f}
.wp-roles-chips{flex:1;min-width:0;display:flex;flex-wrap:wrap;gap:4px;align-items:center;align-content:center;min-height:24px}
.wp-roles-chip{display:inline-flex;align-items:center;height:24px;background:rgba(0,0,0,0.08);border-radius:16px;padding:0 8px;font-size:13px;color:rgba(0,0,0,0.87);line-height:1;white-space:nowrap}
.wp-roles-arrow{position:absolute;right:8px;top:50%;transform:translateY(-50%);width:24px;height:24px;color:rgba(0,0,0,0.54);pointer-events:none;transition:transform .15s}
.wp-roles-wrap.focused .wp-roles-arrow{transform:translateY(-50%) rotate(180deg)}
.wp-roles-menu{display:none;position:fixed;z-index:10000;background:#fff;border:none;border-radius:4px;box-shadow:0 5px 5px -3px rgba(0,0,0,.2),0 8px 10px 1px rgba(0,0,0,.14),0 3px 14px 2px rgba(0,0,0,.12);box-sizing:border-box;overflow:hidden;flex-direction:column;padding:8px 0}
.wp-roles-menu.open{display:flex}
.wp-roles-scroll{max-height:${_menuMaxHeightPx}px;overflow:auto;width:100%;box-sizing:border-box;-webkit-overflow-scrolling:touch}
.wp-roles-item{display:flex;align-items:center;gap:8px;min-height:48px;padding:4px 16px;white-space:nowrap;cursor:pointer;font-size:16px;line-height:1.5;color:rgba(0,0,0,0.87);box-sizing:border-box}
.wp-roles-item:hover{background:rgba(0,0,0,.04)}
.wp-roles-item.selected{background:$selectedBg}
.wp-roles-item.selected:hover{background:$selectedBg}
.wp-roles-item input[type=checkbox]{appearance:none;-webkit-appearance:none;width:18px;height:18px;margin:0;cursor:pointer;flex-shrink:0;border:2px solid rgba(0,0,0,0.54);border-radius:2px;background:#fff;box-sizing:border-box;transition:background .15s,border-color .15s}
.wp-roles-item input[type=checkbox]:checked{background:$primary;border-color:$primary;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='white'%3E%3Cpath d='M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z'/%3E%3C/svg%3E");background-size:18px;background-position:center;background-repeat:no-repeat}
.wp-roles-item-label{font-size:16px;font-weight:400;color:rgba(0,0,0,0.87)}
.wp-roles-item.bold .wp-roles-item-label{font-weight:700}
.wp-roles-empty{padding:16px;color:#757575;font-size:14px}
</style>
<div class="wp-roles-wrap">
<span class="wp-roles-label">Roles <span class="req">*</span></span>
<div class="wp-roles-trigger" role="button" tabindex="0">
<div class="wp-roles-chips"></div>
</div>
<svg class="wp-roles-arrow" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M7 10l5 5 5-5z"/></svg>
</div>
<div class="wp-roles-menu" role="listbox">
<div class="wp-roles-scroll"></div>
</div>
''';
  }

  void _registerFactory() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final root = web.HTMLDivElement()
        ..className = 'wp-roles-root'
        ..style.width = '100%'
        ..style.height = '${_fieldHeightPx}px';
      root.innerHTML = _rolesStyles().toJS;

      _root = root;
      _wrap = root.querySelector('.wp-roles-wrap') as web.HTMLDivElement?;
      _menu = root.querySelector('.wp-roles-menu') as web.HTMLDivElement?;
      _scroll = root.querySelector('.wp-roles-scroll') as web.HTMLDivElement?;
      _trigger = root.querySelector('.wp-roles-trigger') as web.HTMLDivElement?;
      _chips = root.querySelector('.wp-roles-chips') as web.HTMLDivElement?;

      _trigger?.addEventListener('click', _onTriggerClick.toJS);
      _scroll?.addEventListener('click', _onMenuClick.toJS);
      _scroll?.addEventListener('change', _onMenuChange.toJS);

      final body = web.document.body;
      if (body != null && _menu != null) {
        body.appendChild(_menu!);
      }

      _syncDisplay();
      _syncWrapState();
      _syncErrorState();
      return root;
    });
  }

  void _syncErrorState() {
    final wrap = _wrap;
    if (wrap == null) return;
    if (widget.hasError) {
      wrap.classList.add('error');
      _trigger?.classList.add('error');
    } else {
      wrap.classList.remove('error');
      _trigger?.classList.remove('error');
    }
  }

  void _syncWrapState() {
    final wrap = _wrap;
    if (wrap == null) return;
    if (widget.selectedIds.isNotEmpty) {
      wrap.classList.add('has-value');
    } else {
      wrap.classList.remove('has-value');
    }
  }

  void _onTriggerClick(web.Event event) {
    event.stopPropagation();
    if (_menuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    final root = _root;
    final menu = _menu;
    final trigger = _trigger;
    if (root == null || menu == null || trigger == null) return;

    WebPortalFilterDropdownDom.positionAndOpenMenu(
      root: root,
      menu: menu,
      trigger: trigger,
    );
    trigger.classList.add('focused');
    _wrap?.classList.add('focused');
    _menuOpen = true;
    _attachDocumentListener();
  }

  void _closeMenu() {
    final menu = _menu;
    if (menu == null) return;
    WebPortalFilterDropdownDom.closeMenu(menu);
    _trigger?.classList.remove('focused');
    _wrap?.classList.remove('focused');
    _menuOpen = false;
    _detachDocumentListener();
  }

  void _attachDocumentListener() {
    _detachDocumentListener();
    void listener(web.Event e) {
      final target = e.target;
      if (target is web.Node &&
          (_root?.contains(target) == true || _menu?.contains(target) == true)) {
        return;
      }
      _closeMenu();
    }

    _docClickListener = listener;
    web.document.addEventListener('click', listener.toJS);
  }

  void _detachDocumentListener() {
    final listener = _docClickListener;
    if (listener != null) {
      web.document.removeEventListener('click', listener.toJS);
      _docClickListener = null;
    }
  }

  void _onMenuChange(web.Event event) {
    final target = event.target;
    if (target is! web.HTMLInputElement || target.type != 'checkbox') return;
    final id = target.getAttribute('data-dd-id');
    if (id == null || id.isEmpty) return;
    _toggle(id, target.checked);
  }

  void _onMenuClick(web.Event event) {
    final target = event.target;
    if (target is! web.Element) return;
    if (target is web.HTMLInputElement) return;
    web.Element? row = target;
    while (row != null && !row.classList.contains('wp-roles-item')) {
      row = row.parentElement;
    }
    if (row == null) return;
    final checkbox = row.querySelector('input[type="checkbox"]')
        as web.HTMLInputElement?;
    final id = checkbox?.getAttribute('data-dd-id');
    if (id == null || id.isEmpty || checkbox == null) return;
    checkbox.checked = !checkbox.checked;
    _toggle(id, checkbox.checked);
  }

  void _toggle(String id, bool checked) {
    final next = Set<String>.from(widget.selectedIds);
    if (checked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
    _syncDisplay();
    _syncWrapState();
    _updateRowInMenu(id, checked);
  }

  void _updateRowInMenu(String id, bool checked) {
    final scroll = _scroll;
    if (scroll == null) return;
    final escaped = WebPortalFilterDropdownDom.escapeAttr(id);
    final row = scroll.querySelector('label[data-dd-id="$escaped"]');
    final checkbox = scroll.querySelector('input[data-dd-id="$escaped"]')
        as web.HTMLInputElement?;
    if (checkbox != null) checkbox.checked = checked;
    if (row is web.Element) {
      if (checked) {
        row.classList.add('selected');
      } else {
        row.classList.remove('selected');
      }
    }
  }

  void _syncDisplay() {
    final chips = _chips;
    if (chips == null) return;

    if (widget.selectedIds.isEmpty) {
      chips.innerHTML = ''.toJS;
      return;
    }

    final labelsById = {
      for (final o in widget.options) o.id: o.label,
    };
    final buf = StringBuffer();
    for (final id in widget.selectedIds) {
      final label = WebPortalFilterDropdownDom.escapeText(
        labelsById[id] ?? id,
      );
      buf.write('<span class="wp-roles-chip">$label</span>');
    }
    chips.innerHTML = buf.toString().toJS;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDisplay();
      _syncWrapState();
      _syncErrorState();
    });
    return HtmlElementView(viewType: _viewType);
  }
}

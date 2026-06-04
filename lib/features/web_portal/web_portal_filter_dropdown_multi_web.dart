import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_dom.dart';
import 'web_portal_styles.dart';

/// Multi-select DOM dropdown — same menu behavior as single-select.
class WebPortalFilterDropdownMulti extends StatefulWidget {
  const WebPortalFilterDropdownMulti({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.menuMaxHeight,
  });

  final String label;
  final List<WebPortalDropdownOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final double menuMaxHeight;

  @override
  State<WebPortalFilterDropdownMulti> createState() =>
      _WebPortalFilterDropdownMultiState();
}

class _MultiMenuArgs {
  const _MultiMenuArgs({required this.rows, required this.selectedIds});
  final List<DomDropdownOptionRow> rows;
  final List<String> selectedIds;
}

String _buildMultiMenuIsolate(_MultiMenuArgs args) {
  return buildMultiMenuHtml(args.rows, args.selectedIds.toSet());
}

class _WebPortalFilterDropdownMultiState extends State<WebPortalFilterDropdownMulti> {
  static int _nextId = 0;

  late final String _viewType;
  web.HTMLDivElement? _root;
  web.HTMLDivElement? _menu;
  web.HTMLDivElement? _scroll;
  web.HTMLInputElement? _searchInput;
  web.HTMLDivElement? _trigger;
  web.HTMLSpanElement? _display;
  web.HTMLButtonElement? _clearBtn;
  bool _registered = false;
  bool _menuOpen = false;
  List<DomDropdownOptionRow>? _lastRows;
  void Function(web.Event)? _docClickListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'wp-filter-dd-multi-${_nextId++}';
    _registerFactory();
    _scheduleMenuSync();
  }

  @override
  void didUpdateWidget(covariant WebPortalFilterDropdownMulti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameOptions(oldWidget.options, widget.options) ||
        oldWidget.selectedIds != widget.selectedIds) {
      _scheduleMenuSync();
    }
    _syncDisplay();
    _updateClearVisibility();
  }

  @override
  void dispose() {
    _detachDocumentListener();
    _menu?.remove();
    super.dispose();
  }

  bool _sameOptions(List<WebPortalDropdownOption> a, List<WebPortalDropdownOption> b) {
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
      if (_menuOpen && _scroll != null) {
        WebPortalFilterDropdownDom.applyMenuSearch(
          _scroll!,
          _searchInput?.value ?? '',
        );
      }
    });
  }

  void _registerFactory() {
    if (_registered) return;
    _registered = true;
    final label = widget.label;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      final root = web.HTMLDivElement()
        ..className = 'wp-dd-root'
        ..style.width = '100%'
        ..style.height = '${WebPortalStyles.filterFieldHeight}px'
        ..style.display = 'flex'
        ..style.alignItems = 'flex-end'
        ..style.boxSizing = 'border-box'
        ..style.overflow = 'hidden';
      root.innerHTML = WebPortalFilterDropdownDom.sharedStyles(
        WebPortalFilterDropdownDom.escapeText(label),
      ).toJS;

      _root = root;
      _menu = root.querySelector('.wp-dd-menu') as web.HTMLDivElement?;
      _scroll = root.querySelector('.wp-dd-scroll') as web.HTMLDivElement?;
      _trigger = root.querySelector('.wp-dd-trigger') as web.HTMLDivElement?;
      _display = root.querySelector('.wp-dd-display') as web.HTMLSpanElement?;
      _clearBtn = root.querySelector('.wp-field-clear') as web.HTMLButtonElement?;

      _trigger?.addEventListener('click', _onTriggerClick.toJS);
      _clearBtn?.addEventListener('click', _onClearClick.toJS);
      _scroll?.addEventListener('click', _onMenuClick.toJS);
      _scroll?.addEventListener('change', _onMenuChange.toJS);
      _searchInput?.addEventListener('input', _onSearchInput.toJS);
      _searchInput?.addEventListener('click', _stopPropagation.toJS);
      _searchInput?.addEventListener('keydown', _onSearchKeydown.toJS);

      _syncDisplay();
      return root;
    });
  }

  void _onClearClick(web.Event event) {
    event.stopPropagation();
    widget.onSelectionChanged({});
    _syncDisplay();
    _updateClearVisibility();
    _closeMenu();
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
    WebPortalFilterDropdownDom.prepareMenuOnOpen(
      searchInput: _searchInput,
      scroll: _scroll,
    );
    _menuOpen = true;
    _attachDocumentListener();
  }

  void _stopPropagation(web.Event event) => event.stopPropagation();

  void _onSearchKeydown(web.Event event) {
    event.stopPropagation();
    if (event is! web.KeyboardEvent || !_menuOpen) return;
    final scroll = _scroll;
    if (scroll == null) return;

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        WebPortalFilterDropdownDom.moveKeyboardFocus(scroll, 1);
      case 'ArrowUp':
        event.preventDefault();
        WebPortalFilterDropdownDom.moveKeyboardFocus(scroll, -1);
      case 'Enter':
        event.preventDefault();
        _activateKeyboardFocusedItem(scroll);
      case 'Escape':
        event.preventDefault();
        _closeMenu();
      default:
        break;
    }
  }

  void _activateKeyboardFocusedItem(web.HTMLDivElement scroll) {
    var item = WebPortalFilterDropdownDom.keyboardFocusedElement(scroll);
    item ??= () {
      final visible = WebPortalFilterDropdownDom.visibleMenuItems(scroll);
      return visible.isEmpty ? null : visible.first;
    }();
    if (item == null) return;
    final checkbox = item.querySelector('input[type="checkbox"]')
        as web.HTMLInputElement?;
    final id = WebPortalFilterDropdownDom.idFromMenuItem(item);
    if (checkbox == null || id == null || id.isEmpty) return;
    checkbox.checked = !checkbox.checked;
    _toggle(id, checkbox.checked);
  }

  void _onSearchInput(web.Event _) {
    final scroll = _scroll;
    if (scroll == null) return;
    WebPortalFilterDropdownDom.applyMenuSearch(
      scroll,
      _searchInput?.value ?? '',
    );
  }

  void _closeMenu() {
    final menu = _menu;
    if (menu == null) return;
    WebPortalFilterDropdownDom.closeMenu(menu);
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
    while (row != null && !row.classList.contains('wp-dd-item-multi')) {
      row = row.parentElement;
    }
    if (row == null) return;
    final checkbox = row.querySelector('input[type="checkbox"]')
        as web.HTMLInputElement?;
    final id = checkbox?.getAttribute('data-dd-id');
    if (id == null || id.isEmpty) return;
    if (checkbox == null) return;
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
  }

  void _syncDisplay() {
    final n = widget.selectedIds.length;
    if (n == 0) {
      WebPortalFilterDropdownDom.setDisplayText(
        _display,
        ' ',
        placeholder: true,
      );
    } else {
      WebPortalFilterDropdownDom.setDisplayText(
        _display,
        '$n ${n == 1 ? 'city' : 'cities'} selected',
        placeholder: false,
      );
    }
    _updateClearVisibility();
  }

  void _updateClearVisibility() {
    WebPortalFilterDropdownDom.setClearVisible(
      _clearBtn,
      widget.selectedIds.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

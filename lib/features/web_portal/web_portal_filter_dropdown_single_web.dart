import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_dom.dart';
import 'web_portal_styles.dart';

/// Single-select DOM dropdown — fast lists, menu width matches field, scroll axes.
class WebPortalFilterDropdownSingle extends StatefulWidget {
  const WebPortalFilterDropdownSingle({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.menuMaxHeight,
  });

  final String label;
  final List<WebPortalDropdownOption> options;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final double menuMaxHeight;

  @override
  State<WebPortalFilterDropdownSingle> createState() =>
      _WebPortalFilterDropdownSingleState();
}

class _SingleMenuArgs {
  const _SingleMenuArgs({required this.rows, required this.selectedId});
  final List<DomDropdownOptionRow> rows;
  final String? selectedId;
}

String _buildSingleMenuIsolate(_SingleMenuArgs args) {
  return buildSingleMenuHtml(args.rows, args.selectedId);
}

class _WebPortalFilterDropdownSingleState
    extends State<WebPortalFilterDropdownSingle> {
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
    _viewType = 'wp-filter-dd-single-${_nextId++}';
    _registerFactory();
    _scheduleMenuSync();
  }

  @override
  void didUpdateWidget(covariant WebPortalFilterDropdownSingle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameOptions(oldWidget.options, widget.options)) {
      _scheduleMenuSync();
    }
    _syncDisplay();
    _highlightSelected();
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
      if (a[i].id != b[i].id || a[i].label != b[i].label || a[i].bold != b[i].bold) {
        return false;
      }
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
    final args = _SingleMenuArgs(rows: rows, selectedId: widget.selectedId);
    compute(_buildSingleMenuIsolate, args).then((html) {
      if (!mounted || !identical(_lastRows, rows)) return;
      _scroll?.innerHTML = html.toJS;
      _highlightSelected();
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
      _searchInput = root.querySelector('.wp-dd-search') as web.HTMLInputElement?;
      _trigger = root.querySelector('.wp-dd-trigger') as web.HTMLDivElement?;
      _display = root.querySelector('.wp-dd-display') as web.HTMLSpanElement?;
      _clearBtn = root.querySelector('.wp-field-clear') as web.HTMLButtonElement?;

      _trigger?.addEventListener('click', _onTriggerClick.toJS);
      _clearBtn?.addEventListener('click', _onClearClick.toJS);
      _scroll?.addEventListener('click', _onMenuClick.toJS);
      _searchInput?.addEventListener('input', _onSearchInput.toJS);
      _searchInput?.addEventListener('click', _stopPropagation.toJS);
      _searchInput?.addEventListener('keydown', _onSearchKeydown.toJS);

      _syncDisplay();
      return root;
    });
  }

  void _onClearClick(web.Event event) {
    event.stopPropagation();
    widget.onSelected(null);
    _syncDisplay();
    _highlightSelected();
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
        _selectKeyboardFocusedItem(scroll);
      case 'Escape':
        event.preventDefault();
        _closeMenu();
      default:
        break;
    }
  }

  void _selectKeyboardFocusedItem(web.HTMLDivElement scroll) {
    var item = WebPortalFilterDropdownDom.keyboardFocusedElement(scroll);
    item ??= () {
      final visible = WebPortalFilterDropdownDom.visibleMenuItems(scroll);
      return visible.isEmpty ? null : visible.first;
    }();
    if (item == null) return;
    final id = WebPortalFilterDropdownDom.idFromMenuItem(item);
    if (id == null || id.isEmpty) return;
    widget.onSelected(id);
    _syncDisplay();
    _highlightSelected();
    _closeMenu();
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

  void _onMenuClick(web.Event event) {
    final target = event.target;
    if (target is! web.Element) return;
    web.Element? el = target;
    while (el != null) {
      final id = el.getAttribute('data-dd-id');
      if (id != null &&
          id.isNotEmpty &&
          el.classList.contains('wp-dd-item')) {
        widget.onSelected(id);
        _syncDisplay();
        _highlightSelected();
        _closeMenu();
        return;
      }
      el = el.parentElement;
    }
  }

  void _syncDisplay() {
    final id = widget.selectedId;
    String text = ' ';
    var placeholder = true;
    if (id != null) {
      for (final o in widget.options) {
        if (o.id == id) {
          text = o.label;
          placeholder = false;
          break;
        }
      }
    }
    WebPortalFilterDropdownDom.setDisplayText(
      _display,
      text,
      placeholder: placeholder,
    );
    _updateClearVisibility();
  }

  void _updateClearVisibility() {
    WebPortalFilterDropdownDom.setClearVisible(
      _clearBtn,
      widget.selectedId != null,
    );
  }

  void _highlightSelected() {
    final scroll = _scroll;
    if (scroll == null) return;
    final selected = widget.selectedId;
    final items = scroll.querySelectorAll('.wp-dd-item');
    for (var i = 0; i < items.length; i++) {
      final item = items.item(i) as web.Element?;
      if (item == null) continue;
      final id = item.getAttribute('data-dd-id');
      if (id == selected) {
        item.classList.add('selected');
      } else {
        item.classList.remove('selected');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDisplay();
    });
    return HtmlElementView(viewType: _viewType);
  }
}

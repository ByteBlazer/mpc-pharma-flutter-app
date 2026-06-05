import 'package:web/web.dart' as web;

import 'web_portal_filter_field_dom.dart';
import 'web_portal_styles.dart';

/// Shared DOM helpers for web filter dropdowns.
abstract final class WebPortalFilterDropdownDom {
  static const keyboardFocusClass = 'keyboard-focus';

  static const menuMaxHeightPx = 280;
  static const menuSearchBarHeightPx = 44;
  static const menuListMaxHeightPx = menuMaxHeightPx - menuSearchBarHeightPx;

  static String escapeText(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String escapeAttr(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('"', '&quot;');

  static String sharedStyles(String safeLabel, {bool dialogForm = false}) {
    final wrapHeight = dialogForm
        ? WebPortalStyles.dialogFormFieldHeight.round()
        : 40;
    final triggerPadding =
        dialogForm ? '0 36px 0 12px' : '0 4px 0 12px';
    final displaySize = dialogForm ? 16 : 14;
    final rootLayout = dialogForm
        ? 'overflow:visible'
        : 'overflow:hidden;display:flex;align-items:flex-end';
    final arrowCss = dialogForm
        ? '.wp-dd-arrow-outside{position:absolute;right:8px;top:50%;transform:translateY(-50%);width:24px;height:24px;color:rgba(0,0,0,0.54);pointer-events:none}'
        : '';
    final triggerHtml = dialogForm
        ? '''
<div class="wp-dd-trigger" role="button" tabindex="0">
<span class="wp-dd-display placeholder"></span>
${WebPortalFilterFieldDom.clearButtonHtml}
</div>
<svg class="wp-dd-arrow-outside" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M7 10l5 5 5-5z"/></svg>
'''
        : '''
<div class="wp-dd-trigger" role="button" tabindex="0">
<span class="wp-dd-display placeholder"></span>
${WebPortalFilterFieldDom.clearButtonHtml}
<svg class="wp-dd-arrow" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M7 10l5 5 5-5z"/></svg>
</div>
''';
    return '''
<style>
${WebPortalFilterFieldDom.clearCss}
.wp-dd-root{position:relative;width:100%;height:100%;font-family:Roboto,Helvetica,Arial,sans-serif;box-sizing:border-box;$rootLayout}
.wp-dd-wrap{position:relative;width:100%;height:${wrapHeight}px;overflow:visible}
.wp-dd-label{position:absolute;top:0;left:12px;transform:translateY(-50%);font-size:12px;color:#757575;background:#fff;padding:0 4px;z-index:2;line-height:1.2;white-space:nowrap;pointer-events:none}
.wp-dd-trigger{width:100%;height:${wrapHeight}px;border:1px solid rgba(0,0,0,0.23);border-radius:4px;background:#fff;box-sizing:border-box;display:flex;align-items:center;padding:$triggerPadding;gap:0;cursor:pointer}
.wp-dd-trigger:hover{border-color:rgba(0,0,0,0.87)}
.wp-dd-display{flex:1;min-width:0;font-size:${displaySize}px;color:#212121;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.wp-dd-display.placeholder{color:#757575}
.wp-dd-arrow{flex-shrink:0;width:20px;height:20px;color:#757575;pointer-events:none}
$arrowCss
.wp-dd-menu{display:none;position:fixed;z-index:10000;background:#fff;border:1px solid #e0e0e0;border-radius:4px;box-shadow:0 4px 12px rgba(0,0,0,.15);box-sizing:border-box;overflow:hidden;flex-direction:column}
.wp-dd-menu.open{display:flex}
.wp-dd-search-wrap{padding:8px 8px 4px;border-bottom:1px solid #e0e0e0;flex-shrink:0;box-sizing:border-box}
.wp-dd-search{width:100%;height:32px;border:1px solid rgba(0,0,0,0.23);border-radius:4px;padding:0 10px;font-size:14px;box-sizing:border-box;outline:none;font-family:inherit;color:#212121}
.wp-dd-search::placeholder{color:#757575}
.wp-dd-search:focus{border-color:#1976d2;border-width:2px;padding:0 9px}
.wp-dd-scroll{max-height:${menuListMaxHeightPx}px;overflow:auto;width:100%;box-sizing:border-box;-webkit-overflow-scrolling:touch;flex:1;min-height:0}
.wp-dd-item{padding:10px 12px;font-size:14px;color:#212121;white-space:nowrap;cursor:pointer;line-height:1.3}
.wp-dd-item:hover{background:rgba(0,0,0,.04)}
.wp-dd-item.selected{background:rgba(25,118,210,.1)}
.wp-dd-item.keyboard-focus{background:rgba(25,118,210,.18);outline:1px solid #1976d2;outline-offset:-1px}
.wp-dd-item.bold{font-weight:700}
.wp-dd-item-multi{display:flex;align-items:center;gap:8px;padding:6px 12px;white-space:nowrap;cursor:pointer;font-size:14px;line-height:1.3}
.wp-dd-item-multi:hover{background:rgba(0,0,0,.04)}
.wp-dd-item-multi.keyboard-focus{background:rgba(25,118,210,.18);outline:1px solid #1976d2;outline-offset:-1px}
.wp-dd-item-multi input{margin:0;cursor:pointer;flex-shrink:0}
.wp-dd-item-multi span{font-weight:inherit}
.wp-dd-item-multi.bold span{font-weight:700}
.wp-dd-empty{padding:16px 12px;color:#757575;font-size:14px}
.wp-dd-no-match{display:none;padding:16px 12px;color:#757575;font-size:14px}
.wp-dd-no-match.visible{display:block}
.wp-dd-trigger.error{border:1px solid #d32f2f}
.wp-dd-trigger.error:hover{border:1px solid #d32f2f}
.wp-dd-label.error{color:#d32f2f}
</style>
<div class="wp-dd-wrap">
<span class="wp-dd-label">$safeLabel</span>
$triggerHtml
</div>
<div class="wp-dd-menu" role="listbox">
<div class="wp-dd-search-wrap">
<input type="text" class="wp-dd-search" placeholder="Search..." autocomplete="off" aria-label="Search options" />
</div>
<div class="wp-dd-scroll"></div>
</div>
''';
  }

  static void positionAndOpenMenu({
    required web.HTMLDivElement root,
    required web.HTMLDivElement menu,
    required web.HTMLDivElement trigger,
  }) {
    // Reparent to body so menu is not clipped by the platform view.
    final body = web.document.body;
    if (body != null && menu.parentElement != body) {
      body.appendChild(menu);
    }
    final rootRect = root.getBoundingClientRect();
    menu.style.left = '${rootRect.left}px';
    menu.style.top = '${rootRect.bottom + 4}px';
    menu.style.width = '${rootRect.width}px';
    menu.style.minWidth = '${rootRect.width}px';
    menu.style.maxWidth = '${rootRect.width}px';
    menu.classList.add('open');
    menu.style.display = 'block';
  }

  static void closeMenu(web.HTMLDivElement menu) {
    menu.classList.remove('open');
    menu.style.display = 'none';
  }

  static void setClearVisible(web.HTMLButtonElement? btn, bool visible) {
    WebPortalFilterFieldDom.setClearVisible(btn, visible);
  }

  static void prepareMenuOnOpen({
    required web.HTMLInputElement? searchInput,
    required web.HTMLDivElement? scroll,
  }) {
    if (searchInput != null) searchInput.value = '';
    if (scroll != null) applyMenuSearch(scroll, '');
    searchInput?.focus();
  }

  static void applyMenuSearch(web.HTMLDivElement scroll, String query) {
    final q = query.trim().toLowerCase();
    final items = scroll.querySelectorAll('.wp-dd-item, .wp-dd-item-multi');
    var visible = 0;
    for (var i = 0; i < items.length; i++) {
      final node = items.item(i);
      if (node is! web.HTMLElement) continue;
      final el = node;
      final label = el.getAttribute('data-dd-label') ?? '';
      final match = q.isEmpty || label.contains(q);
      el.style.display = match ? '' : 'none';
      if (match) visible++;
    }
    clearKeyboardFocus(scroll);
    final noMatch = scroll.querySelector('.wp-dd-no-match');
    if (noMatch != null) {
      if (q.isNotEmpty && visible == 0) {
        noMatch.classList.add('visible');
      } else {
        noMatch.classList.remove('visible');
      }
    }
  }

  static List<web.HTMLElement> visibleMenuItems(web.HTMLDivElement scroll) {
    final nodes = scroll.querySelectorAll('.wp-dd-item, .wp-dd-item-multi');
    final out = <web.HTMLElement>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes.item(i);
      if (node is! web.HTMLElement) continue;
      if (node.style.display == 'none') continue;
      out.add(node);
    }
    return out;
  }

  static int? keyboardFocusedIndex(web.HTMLDivElement scroll) {
    final visible = visibleMenuItems(scroll);
    for (var i = 0; i < visible.length; i++) {
      if (visible[i].classList.contains(keyboardFocusClass)) return i;
    }
    return null;
  }

  static void clearKeyboardFocus(web.HTMLDivElement scroll) {
    final focused = scroll.querySelectorAll('.${keyboardFocusClass}');
    for (var i = 0; i < focused.length; i++) {
      final el = focused.item(i);
      if (el is web.Element) {
        el.classList.remove(keyboardFocusClass);
      }
    }
  }

  static void focusVisibleItemAt(web.HTMLDivElement scroll, int index) {
    final visible = visibleMenuItems(scroll);
    if (visible.isEmpty) return;
    final i = index.clamp(0, visible.length - 1);
    clearKeyboardFocus(scroll);
    visible[i].classList.add(keyboardFocusClass);
    visible[i].scrollIntoView();
  }

  static void moveKeyboardFocus(web.HTMLDivElement scroll, int delta) {
    final visible = visibleMenuItems(scroll);
    if (visible.isEmpty) return;
    var idx = keyboardFocusedIndex(scroll);
    if (idx == null) {
      idx = delta > 0 ? 0 : visible.length - 1;
    } else {
      idx = (idx + delta).clamp(0, visible.length - 1);
    }
    focusVisibleItemAt(scroll, idx);
  }

  static web.HTMLElement? keyboardFocusedElement(web.HTMLDivElement scroll) {
    return scroll.querySelector('.${keyboardFocusClass}')
        as web.HTMLElement?;
  }

  static String? idFromMenuItem(web.HTMLElement item) {
    final direct = item.getAttribute('data-dd-id');
    if (direct != null && direct.isNotEmpty) return direct;
    final checkbox = item.querySelector('input[data-dd-id]');
    return checkbox?.getAttribute('data-dd-id');
  }

  static void setDisplayText(
    web.HTMLSpanElement? display,
    String text, {
    required bool placeholder,
  }) {
    if (display == null) return;
    display.textContent = text;
    if (placeholder) {
      display.classList.add('placeholder');
    } else {
      display.classList.remove('placeholder');
    }
  }
}

/// Serializable row for isolate HTML generation.
class DomDropdownOptionRow {
  const DomDropdownOptionRow({
    required this.id,
    required this.label,
    this.bold = false,
  });

  final String id;
  final String label;
  final bool bold;
}

String buildSingleMenuHtml(List<DomDropdownOptionRow> rows, String? selectedId) {
  if (rows.isEmpty) {
    return '<div class="wp-dd-empty">No options found</div>';
  }
  final buf = StringBuffer();
  for (final r in rows) {
    final selected = r.id == selectedId;
    final classes = <String>['wp-dd-item'];
    if (selected) classes.add('selected');
    if (r.bold) classes.add('bold');
    final id = WebPortalFilterDropdownDom.escapeAttr(r.id);
    final label = WebPortalFilterDropdownDom.escapeText(r.label);
    final searchLabel = WebPortalFilterDropdownDom.escapeAttr(
      r.label.toLowerCase(),
    );
    buf.write(
      '<div class="${classes.join(' ')}" data-dd-id="$id" data-dd-label="$searchLabel" role="option">$label</div>',
    );
  }
  buf.write('<div class="wp-dd-no-match">No matching options</div>');
  return buf.toString();
}

String buildMultiMenuHtml(
  List<DomDropdownOptionRow> rows,
  Set<String> selectedIds,
) {
  if (rows.isEmpty) {
    return '<div class="wp-dd-empty">No options found</div>';
  }
  final buf = StringBuffer();
  for (final r in rows) {
    final checked = selectedIds.contains(r.id);
    final classes = <String>['wp-dd-item-multi'];
    if (r.bold) classes.add('bold');
    final id = WebPortalFilterDropdownDom.escapeAttr(r.id);
    final label = WebPortalFilterDropdownDom.escapeText(r.label);
    final searchLabel = WebPortalFilterDropdownDom.escapeAttr(
      r.label.toLowerCase(),
    );
    final checkedAttr = checked ? ' checked' : '';
    buf.write(
      '<label class="${classes.join(' ')}" data-dd-label="$searchLabel">'
      '<input type="checkbox" data-dd-id="$id"$checkedAttr/>'
      '<span>$label</span></label>',
    );
  }
  buf.write('<div class="wp-dd-no-match">No matching options</div>');
  return buf.toString();
}

import 'package:web/web.dart' as web;

/// Shared DOM/CSS for the clear (×) control inside filter fields.
abstract final class WebPortalFilterFieldDom {
  static const clearCss = '''
.wp-field-clear{display:none;align-items:center;justify-content:center;width:28px;height:28px;border:none;background:transparent;cursor:pointer;color:#757575;border-radius:50%;padding:0;flex-shrink:0}
.wp-field-clear.visible{display:flex}
.wp-field-clear:hover{background:rgba(0,0,0,.04)}
.wp-field-clear svg{width:18px;height:18px;display:block}
''';

  static const clearButtonHtml = '''
<button type="button" class="wp-field-clear" aria-label="Clear">
<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
</button>
''';

  static void setClearVisible(web.HTMLButtonElement? btn, bool visible) {
    if (btn == null) return;
    if (visible) {
      btn.classList.add('visible');
    } else {
      btn.classList.remove('visible');
    }
  }
}

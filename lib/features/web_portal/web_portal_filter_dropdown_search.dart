import 'web_portal_dropdown_option.dart';

/// Client-side filter for dropdown menus (expanded panel search).
abstract final class WebPortalFilterDropdownSearch {
  static const searchBarHeight = 44.0;

  static List<WebPortalDropdownOption> filter(
    List<WebPortalDropdownOption> options,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return options;
    return [
      for (final o in options)
        if (o.label.toLowerCase().contains(q)) o,
    ];
  }

  static String normalizeLabel(String label) => label.toLowerCase();
}

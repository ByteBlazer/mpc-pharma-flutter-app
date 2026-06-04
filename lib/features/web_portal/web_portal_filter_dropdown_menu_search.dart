import 'package:flutter/material.dart';

import 'web_portal_filter_dropdown_search.dart';

/// Search field pinned to the top of a filter dropdown menu (non-web).
class WebPortalFilterDropdownMenuSearch extends StatelessWidget {
  const WebPortalFilterDropdownMenuSearch({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search...',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.23)),
          ),
        ),
      ),
    );
  }

  static double listHeight(double menuMaxHeight) =>
      menuMaxHeight - WebPortalFilterDropdownSearch.searchBarHeight;
}

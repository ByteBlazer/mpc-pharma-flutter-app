import 'package:flutter/material.dart';

import 'web_portal_dropdown_option.dart';
export 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_multi_menu.dart'
    if (dart.library.js_interop) 'web_portal_filter_dropdown_multi_web.dart';
import 'web_portal_filter_dropdown_single_menu.dart'
    if (dart.library.js_interop) 'web_portal_filter_dropdown_single_web.dart';

/// Outlined filter dropdown — menu opens below the field (single or multi-select).
class WebPortalFilterDropdown extends StatelessWidget {
  const WebPortalFilterDropdown._({
    super.key,
    required this.label,
    required this.options,
    this.menuMaxHeight = 280,
    this.selectedId,
    this.onSelected,
    this.selectedIds,
    this.onSelectionChanged,
    this.hasError = false,
    this.dialogForm = false,
    required this.multi,
  });

  /// Single-select dropdown.
  factory WebPortalFilterDropdown({
    Key? key,
    required String label,
    required List<WebPortalDropdownOption> options,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
    double menuMaxHeight = 280,
    bool hasError = false,
    bool dialogForm = false,
  }) {
    return WebPortalFilterDropdown._(
      key: key,
      label: label,
      options: options,
      selectedId: selectedId,
      onSelected: onSelected,
      menuMaxHeight: menuMaxHeight,
      hasError: hasError,
      dialogForm: dialogForm,
      multi: false,
    );
  }

  /// Multi-select dropdown with checkboxes in the menu below the field.
  factory WebPortalFilterDropdown.multi({
    Key? key,
    required String label,
    required List<WebPortalDropdownOption> options,
    required Set<String> selectedIds,
    required ValueChanged<Set<String>> onSelectionChanged,
    double menuMaxHeight = 280,
  }) {
    return WebPortalFilterDropdown._(
      key: key,
      label: label,
      options: options,
      selectedIds: selectedIds,
      onSelectionChanged: onSelectionChanged,
      menuMaxHeight: menuMaxHeight,
      multi: true,
    );
  }

  final bool multi;
  final String label;
  final List<WebPortalDropdownOption> options;
  final double menuMaxHeight;

  final String? selectedId;
  final ValueChanged<String?>? onSelected;

  final Set<String>? selectedIds;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final bool hasError;
  final bool dialogForm;

  @override
  Widget build(BuildContext context) {
    if (multi) {
      return WebPortalFilterDropdownMulti(
        label: label,
        options: options,
        selectedIds: selectedIds ?? const {},
        onSelectionChanged: onSelectionChanged!,
        menuMaxHeight: menuMaxHeight,
      );
    }
    return WebPortalFilterDropdownSingle(
      label: label,
      options: options,
      selectedId: selectedId,
      onSelected: onSelected!,
      menuMaxHeight: menuMaxHeight,
      hasError: hasError,
      dialogForm: dialogForm,
    );
  }
}

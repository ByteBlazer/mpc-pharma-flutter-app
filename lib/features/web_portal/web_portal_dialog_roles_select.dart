import 'package:flutter/material.dart';

import 'web_portal_dropdown_option.dart';
import 'web_portal_dialog_roles_select_impl.dart';
import 'web_portal_styles.dart';

/// Multi-select roles field for MUI dialog forms — chips in the trigger,
/// checkboxes in the menu below the field.
class WebPortalDialogRolesSelect extends StatelessWidget {
  const WebPortalDialogRolesSelect({
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
  Widget build(BuildContext context) {
    return WebPortalStyles.dialogFormFieldSlot(
      child: WebPortalDialogRolesSelectImpl(
        options: options,
        selectedIds: selectedIds,
        onSelectionChanged: onSelectionChanged,
        hasError: hasError,
      ),
    );
  }
}

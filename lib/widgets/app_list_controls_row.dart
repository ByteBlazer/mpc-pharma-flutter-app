import 'package:flutter/material.dart';

import 'app_sort_controls.dart';

class AppListControlsRow extends StatelessWidget {
  const AppListControlsRow({
    super.key,
    required this.sortField,
    required this.sortDirection,
    required this.onSortChanged,
    required this.showInactive,
    required this.onShowInactiveChanged,
    this.nameLabel = 'Name',
  });

  final AppSortField sortField;
  final AppSortDirection sortDirection;
  final ValueChanged<AppSortField> onSortChanged;
  final bool showInactive;
  final ValueChanged<bool> onShowInactiveChanged;
  final String nameLabel;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final isWide = MediaQuery.sizeOf(context).width > 600;

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
        spacing: 16,
        runSpacing: 4,
        children: [
        AppSortControls(
          field: sortField,
          direction: sortDirection,
          onChanged: onSortChanged,
          nameLabel: nameLabel,
        ),
        TextButton(
          onPressed: () => onShowInactiveChanged(!showInactive),
          style: TextButton.styleFrom(
            foregroundColor: color,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            showInactive ? 'Hide inactive' : 'Show inactive',
            style: TextStyle(
              decoration: showInactive ? TextDecoration.underline : null,
              fontWeight: showInactive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        ],
      ),
    );
  }
}

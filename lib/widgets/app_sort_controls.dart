import 'package:flutter/material.dart';

enum AppSortField { name, id }

enum AppSortDirection { ascending, descending }

class AppSortControls extends StatelessWidget {
  const AppSortControls({
    super.key,
    required this.field,
    required this.direction,
    required this.onChanged,
    this.nameLabel = 'Name',
  });

  final AppSortField field;
  final AppSortDirection direction;
  final ValueChanged<AppSortField> onChanged;
  final String nameLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        Text(
          'Sort:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        _SortLink(
          label: nameLabel,
          isSelected: field == AppSortField.name,
          direction: direction,
          onTap: () => onChanged(AppSortField.name),
        ),
        _SortLink(
          label: 'ID',
          isSelected: field == AppSortField.id,
          direction: direction,
          onTap: () => onChanged(AppSortField.id),
        ),
      ],
    );
  }
}

class _SortLink extends StatelessWidget {
  const _SortLink({
    required this.label,
    required this.isSelected,
    required this.direction,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final AppSortDirection direction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: Icon(_icon, size: 16),
      label: Text(
        label,
        style: TextStyle(
          decoration: isSelected ? TextDecoration.underline : null,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  IconData get _icon {
    if (!isSelected) return Icons.swap_vert;
    return switch (direction) {
      AppSortDirection.ascending => Icons.arrow_upward,
      AppSortDirection.descending => Icons.arrow_downward,
    };
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'web_portal_dropdown_option.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_styles.dart';

/// Non-web fallback — MenuAnchor with CheckboxListTile (menu stays open on toggle).
class WebPortalDialogRolesSelectImpl extends StatefulWidget {
  const WebPortalDialogRolesSelectImpl({
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
  State<WebPortalDialogRolesSelectImpl> createState() =>
      _WebPortalDialogRolesSelectImplState();
}

class _WebPortalDialogRolesSelectImplState
    extends State<WebPortalDialogRolesSelectImpl> {
  final _menuController = MenuController();

  void _toggle(String id, bool checked) {
    final next = Set<String>.from(widget.selectedIds);
    if (checked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final inputTheme = Theme.of(context).inputDecorationTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return MenuAnchor(
          controller: _menuController,
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            elevation: const WidgetStatePropertyAll(8),
            backgroundColor: const WidgetStatePropertyAll(Colors.white),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            minimumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, 0),
            ),
            maximumSize: WidgetStatePropertyAll(
              Size(constraints.maxWidth, 280),
            ),
          ),
          menuChildren: widget.options.isEmpty
              ? const [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No roles available'),
                  ),
                ]
              : [
                  SizedBox(
                    height: (widget.options.length * 48.0).clamp(0, 280),
                    child: Scrollbar(
                      thumbVisibility: widget.options.length > 5,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: widget.options.length,
                        itemBuilder: (context, index) {
                          final o = widget.options[index];
                          final checked = widget.selectedIds.contains(o.id);
                          return Material(
                            color: checked
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggle(o.id, !checked),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 7),
                                    Checkbox(
                                      value: checked,
                                      onChanged: (v) =>
                                          _toggle(o.id, v == true),
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    Expanded(
                                      child: Text(
                                        o.label,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
          builder: (context, controller, child) {
            final open = controller.isOpen;
            return InputDecorator(
              isFocused: open,
              isEmpty: widget.selectedIds.isEmpty,
              decoration: WebPortalMuiDialog.outlinedFieldLabel(
                'Roles',
                required: true,
                error: widget.hasError,
              ).copyWith(
                enabledBorder: open
                    ? inputTheme.focusedBorder
                    : inputTheme.enabledBorder,
              ),
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: widget.selectedIds.isEmpty
                          ? const SizedBox(height: 24)
                          : Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: widget.selectedIds.map((id) {
                                final label = widget.options
                                        .where((o) => o.id == id)
                                        .map((o) => o.label)
                                        .firstOrNull ??
                                    id;
                                return Chip(
                                  label: Text(label),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xDE000000),
                                  ),
                                  backgroundColor: const Color(0x14000000),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  labelPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  padding: EdgeInsets.zero,
                                );
                              }).toList(),
                            ),
                    ),
                    Icon(
                      open ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

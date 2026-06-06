import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'web_portal_dropdown_option.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_overlay_dropdown.dart';

/// Multi-select roles field — chips in the trigger, checkboxes in the menu.
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
  final _anchorKey = GlobalKey();
  bool _menuOpen = false;

  @override
  void dispose() {
    WebPortalOverlayDropdown.dismiss();
    super.dispose();
  }

  void _closeMenu() => setState(() => _menuOpen = false);

  void _toggle(String id, bool checked) {
    final next = Set<String>.from(widget.selectedIds);
    if (checked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
  }

  void _toggleMenu() {
    if (_menuOpen) {
      WebPortalOverlayDropdown.dismiss();
      _closeMenu();
      return;
    }

    setState(() => _menuOpen = true);
    WebPortalOverlayDropdown.show(
      context: context,
      anchorKey: _anchorKey,
      onDismiss: _closeMenu,
      buildMenu: (_, close) => _RolesSelectMenu(
        options: widget.options,
        selectedIds: widget.selectedIds,
        onToggle: _toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputTheme = Theme.of(context).inputDecorationTheme;

    return InputDecorator(
      key: _anchorKey,
      isFocused: _menuOpen,
      isEmpty: widget.selectedIds.isEmpty,
      decoration: WebPortalMuiDialog.outlinedFieldLabel(
        'Roles',
        required: true,
        error: widget.hasError,
      ).copyWith(
        enabledBorder:
            _menuOpen ? inputTheme.focusedBorder : inputTheme.enabledBorder,
      ),
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: _toggleMenu,
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
              _menuOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesSelectMenu extends StatefulWidget {
  const _RolesSelectMenu({
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  final List<WebPortalDropdownOption> options;
  final Set<String> selectedIds;
  final void Function(String id, bool checked) onToggle;

  @override
  State<_RolesSelectMenu> createState() => _RolesSelectMenuState();
}

class _RolesSelectMenuState extends State<_RolesSelectMenu> {
  late Set<String> _localIds;

  @override
  void initState() {
    super.initState();
    _localIds = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No roles available'),
      );
    }

    final listHeight = (widget.options.length * 48.0).clamp(0.0, 280.0);

    return SizedBox(
      height: listHeight,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: widget.options.length,
        itemBuilder: (context, index) {
          final o = widget.options[index];
          final checked = _localIds.contains(o.id);
          return Material(
            color: checked
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: InkWell(
              onTap: () {
                final next = !checked;
                setState(() {
                  if (next) {
                    _localIds.add(o.id);
                  } else {
                    _localIds.remove(o.id);
                  }
                });
                widget.onToggle(o.id, next);
              },
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    const SizedBox(width: 7),
                    Checkbox(
                      value: checked,
                      onChanged: (v) {
                        final next = v == true;
                        setState(() {
                          if (next) {
                            _localIds.add(o.id);
                          } else {
                            _localIds.remove(o.id);
                          }
                        });
                        widget.onToggle(o.id, next);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}

import 'package:flutter/material.dart';

import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_menu_search.dart';
import 'web_portal_filter_dropdown_search.dart';
import 'web_portal_overlay_dropdown.dart';
import 'web_portal_styles.dart';

/// Multi-select outlined dropdown — menu opens below the field on all platforms.
class WebPortalFilterDropdownMulti extends StatefulWidget {
  const WebPortalFilterDropdownMulti({
    super.key,
    required this.label,
    required this.options,
    required this.selectedIds,
    required this.onSelectionChanged,
    required this.menuMaxHeight,
  });

  final String label;
  final List<WebPortalDropdownOption> options;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final double menuMaxHeight;

  @override
  State<WebPortalFilterDropdownMulti> createState() =>
      _WebPortalFilterDropdownMultiState();
}

class _WebPortalFilterDropdownMultiState
    extends State<WebPortalFilterDropdownMulti> {
  final _anchorKey = GlobalKey();
  final _searchController = TextEditingController();
  bool _menuOpen = false;

  @override
  void dispose() {
    WebPortalOverlayDropdown.dismiss();
    _searchController.dispose();
    super.dispose();
  }

  String _summaryText() {
    final n = widget.selectedIds.length;
    if (n == 0) return '';
    return '$n ${n == 1 ? 'city' : 'cities'} selected';
  }

  void _toggle(String id, bool checked) {
    final next = Set<String>.from(widget.selectedIds);
    if (checked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
  }

  void _closeMenu() => setState(() => _menuOpen = false);

  void _toggleMenu() {
    if (_menuOpen) {
      WebPortalOverlayDropdown.dismiss();
      _closeMenu();
      return;
    }

    _searchController.clear();
    setState(() => _menuOpen = true);
    WebPortalOverlayDropdown.show(
      context: context,
      anchorKey: _anchorKey,
      onDismiss: _closeMenu,
      buildMenu: (_, close) => _MultiSelectMenu(
        options: widget.options,
        selectedIds: widget.selectedIds,
        menuMaxHeight: widget.menuMaxHeight,
        searchController: _searchController,
        onToggle: _toggle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summaryText();
    final hasSelection = widget.selectedIds.isNotEmpty;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        key: _anchorKey,
        height: 40,
        width: double.infinity,
        child: InkWell(
          onTap: _toggleMenu,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: WebPortalStyles.muiOutlinedField(
              label: widget.label,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasSelection)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => widget.onSelectionChanged({}),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  Icon(
                    WebPortalOverlayDropdown.isOpen
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    size: 20,
                  ),
                ],
              ),
            ).copyWith(
              isCollapsed: true,
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                summary.isEmpty ? ' ' : summary,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: summary.isEmpty
                      ? WebPortalStyles.textSecondary
                      : Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectMenu extends StatefulWidget {
  const _MultiSelectMenu({
    required this.options,
    required this.selectedIds,
    required this.menuMaxHeight,
    required this.searchController,
    required this.onToggle,
  });

  final List<WebPortalDropdownOption> options;
  final Set<String> selectedIds;
  final double menuMaxHeight;
  final TextEditingController searchController;
  final void Function(String id, bool checked) onToggle;

  @override
  State<_MultiSelectMenu> createState() => _MultiSelectMenuState();
}

class _MultiSelectMenuState extends State<_MultiSelectMenu> {
  late Set<String> _localIds;

  @override
  void initState() {
    super.initState();
    _localIds = Set<String>.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = WebPortalFilterDropdownSearch.filter(
      widget.options,
      widget.searchController.text,
    );
    final listHeight = WebPortalFilterDropdownMenuSearch.listHeight(
      widget.menuMaxHeight,
    );

    if (widget.options.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No options found'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WebPortalFilterDropdownMenuSearch(
          controller: widget.searchController,
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(
          height: listHeight,
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'No matching options',
                    style: TextStyle(
                      color: WebPortalStyles.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final o = filtered[index];
                    final checked = _localIds.contains(o.id);
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        o.label,
                        style: TextStyle(
                          fontWeight:
                              o.bold ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}

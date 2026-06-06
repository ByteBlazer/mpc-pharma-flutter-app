import 'package:flutter/material.dart';

import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_menu_search.dart';
import 'web_portal_filter_dropdown_search.dart';
import 'web_portal_overlay_dropdown.dart';
import 'web_portal_styles.dart';

/// Single-select outlined dropdown — menu opens below the field on all platforms.
class WebPortalFilterDropdownSingle extends StatefulWidget {
  const WebPortalFilterDropdownSingle({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.menuMaxHeight,
    this.hasError = false,
    this.dialogForm = false,
  });

  final String label;
  final List<WebPortalDropdownOption> options;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final double menuMaxHeight;
  final bool hasError;
  final bool dialogForm;

  @override
  State<WebPortalFilterDropdownSingle> createState() =>
      _WebPortalFilterDropdownSingleState();
}

class _WebPortalFilterDropdownSingleState
    extends State<WebPortalFilterDropdownSingle> {
  final _anchorKey = GlobalKey();
  final _searchController = TextEditingController();
  bool _menuOpen = false;

  @override
  void dispose() {
    WebPortalOverlayDropdown.dismiss();
    _searchController.dispose();
    super.dispose();
  }

  String? _labelForId(String? id) {
    if (id == null) return null;
    for (final o in widget.options) {
      if (o.id == id) return o.label;
    }
    return null;
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
      buildMenu: (menuContext, close) => _SingleSelectMenu(
        options: widget.options,
        selectedId: widget.selectedId,
        menuMaxHeight: widget.menuMaxHeight,
        searchController: _searchController,
        onSelected: (id) {
          close();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onSelected(id);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _labelForId(widget.selectedId);
    final hasSelection = widget.selectedId != null;
    final fieldHeight = widget.dialogForm
        ? WebPortalStyles.dialogFormFieldHeight
        : 40.0;

    return SizedBox(
      key: _anchorKey,
      height: fieldHeight,
      width: double.infinity,
      child: Align(
        alignment:
            widget.dialogForm ? Alignment.center : Alignment.bottomCenter,
        child: SizedBox(
          height: fieldHeight,
          width: double.infinity,
          child: InkWell(
            onTap: _toggleMenu,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: WebPortalStyles.muiOutlinedField(
                label: widget.label,
                error: widget.hasError,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasSelection)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => widget.onSelected(null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    Icon(
                      _menuOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 20,
                    ),
                  ],
                ),
              ).copyWith(
                isCollapsed: !widget.dialogForm,
                constraints: widget.dialogForm
                    ? BoxConstraints(
                        minHeight: fieldHeight,
                        maxHeight: fieldHeight,
                      )
                    : const BoxConstraints(minHeight: 40, maxHeight: 40),
                contentPadding: widget.dialogForm
                    ? const EdgeInsets.fromLTRB(12, 0, 36, 0)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  selectedLabel ?? ' ',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.dialogForm ? 16 : 14,
                    color: selectedLabel == null
                        ? WebPortalStyles.textSecondary
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SingleSelectMenu extends StatefulWidget {
  const _SingleSelectMenu({
    required this.options,
    required this.selectedId,
    required this.menuMaxHeight,
    required this.searchController,
    required this.onSelected,
  });

  final List<WebPortalDropdownOption> options;
  final String? selectedId;
  final double menuMaxHeight;
  final TextEditingController searchController;
  final ValueChanged<String> onSelected;

  @override
  State<_SingleSelectMenu> createState() => _SingleSelectMenuState();
}

class _SingleSelectMenuState extends State<_SingleSelectMenu> {
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
                    final selected = o.id == widget.selectedId;
                    return ListTile(
                      dense: true,
                      selected: selected,
                      title: Text(
                        o.label,
                        style: TextStyle(
                          fontWeight:
                              o.bold ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () => widget.onSelected(o.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

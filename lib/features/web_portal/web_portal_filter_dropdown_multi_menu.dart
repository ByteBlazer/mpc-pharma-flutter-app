import 'package:flutter/material.dart';

import 'web_portal_dropdown_option.dart';
import 'web_portal_filter_dropdown_menu_search.dart';
import 'web_portal_filter_dropdown_search.dart';
import 'web_portal_styles.dart';

/// Multi-select fallback (non-web).
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

class _WebPortalFilterDropdownMultiState extends State<WebPortalFilterDropdownMulti> {
  final _menuController = MenuController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetSearch() => _searchController.clear();

  void _toggle(String id, bool checked) {
    final next = Set<String>.from(widget.selectedIds);
    if (checked) {
      next.add(id);
    } else {
      next.remove(id);
    }
    widget.onSelectionChanged(next);
  }

  String _summaryText() {
    final n = widget.selectedIds.length;
    if (n == 0) return '';
    return '$n ${n == 1 ? 'city' : 'cities'} selected';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summaryText();
    final hasSelection = widget.selectedIds.isNotEmpty;
    final filtered = WebPortalFilterDropdownSearch.filter(
      widget.options,
      _searchController.text,
    );
    final listHeight = WebPortalFilterDropdownMenuSearch.listHeight(
      widget.menuMaxHeight,
    );

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        padding: WidgetStateProperty.all(EdgeInsets.zero),
        maximumSize: WidgetStateProperty.all(
          Size(double.infinity, widget.menuMaxHeight),
        ),
        minimumSize: WidgetStateProperty.all(const Size(0, 0)),
        backgroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.all(4),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      menuChildren: [
        if (widget.options.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No options found'),
          )
        else ...[
          WebPortalFilterDropdownMenuSearch(
            controller: _searchController,
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
                : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final o = filtered[index];
                        final checked = widget.selectedIds.contains(o.id);
                        return CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Text(
                              o.label,
                              softWrap: false,
                              style: TextStyle(
                                fontWeight: o.bold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          value: checked,
                          onChanged: (v) => _toggle(o.id, v == true),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ],
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: 40,
          width: double.infinity,
          child: InkWell(
            onTap: () {
              if (_menuController.isOpen) {
                _menuController.close();
              } else {
                _resetSearch();
                setState(() {});
                _menuController.open();
              }
            },
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
                    const Icon(Icons.arrow_drop_down, size: 20),
                  ],
                ),
              ).copyWith(
                isCollapsed: true,
                constraints:
                    const BoxConstraints(minHeight: 40, maxHeight: 40),
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
      ),
    );
  }
}

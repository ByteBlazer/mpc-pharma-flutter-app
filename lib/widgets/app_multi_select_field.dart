import 'dart:async';

import 'package:flutter/material.dart';

import 'app_scrollbar.dart';

class AppMultiSelectItem<T> {
  const AppMultiSelectItem({
    required this.value,
    required this.label,
    required this.searchText,
    this.subtitle,
    this.dimmed = false,
  });

  final T value;
  final String label;
  final String searchText;
  final String? subtitle;
  final bool dimmed;
}

/// Formats the closed field as "1 user selected" / "5 users selected".
class AppMultiSelectCountSummary {
  const AppMultiSelectCountSummary({
    required this.singular,
    required this.plural,
  });

  final String singular;
  final String plural;

  String format(int count) {
    return '$count ${count == 1 ? singular : plural} selected';
  }
}

class AppMultiSelectField<T> extends StatelessWidget {
  const AppMultiSelectField({
    super.key,
    required this.fieldLabel,
    required this.dialogTitle,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    this.enabled = true,
    this.emptySelectionText,
    this.countSummary,
    this.selectionSummaryBuilder,
    this.searchLabel = 'Search',
    this.searchHint = 'Type to filter...',
    this.emptyItemsMessage = 'No items available.',
    this.emptySearchMessage = 'No items match the search.',
    this.countLabel = 'items',
    this.itemExtent = 72,
    this.showSearch = true,
  });

  final String fieldLabel;
  final String dialogTitle;
  final List<AppMultiSelectItem<T>> items;
  final Set<T> selectedValues;
  final ValueChanged<Set<T>> onChanged;
  final bool enabled;
  final String? emptySelectionText;
  final AppMultiSelectCountSummary? countSummary;
  final String Function(Set<T> selected, List<AppMultiSelectItem<T>> items)?
  selectionSummaryBuilder;
  final String searchLabel;
  final String searchHint;
  final String emptyItemsMessage;
  final String emptySearchMessage;
  final String countLabel;
  final double itemExtent;
  final bool showSearch;

  String get _fieldSummary {
    if (selectedValues.isEmpty) {
      return emptySelectionText ?? 'Select $fieldLabel';
    }
    if (countSummary != null) {
      return countSummary!.format(selectedValues.length);
    }
    return selectionSummaryBuilder?.call(selectedValues, items) ??
        '${selectedValues.length} selected';
  }

  Future<void> _openPicker(BuildContext context) async {
    final nextSelection = await showDialog<Set<T>>(
      context: context,
      builder: (context) => _AppMultiSelectDialog<T>(
        dialogTitle: dialogTitle,
        items: items,
        initialSelection: selectedValues,
        searchLabel: searchLabel,
        searchHint: searchHint,
        emptyItemsMessage: emptyItemsMessage,
        emptySearchMessage: emptySearchMessage,
        countLabel: countLabel,
        itemExtent: itemExtent,
        showSearch: showSearch,
      ),
    );

    if (nextSelection != null) onChanged(nextSelection);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? () => _openPicker(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: fieldLabel,
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          _fieldSummary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selectedValues.isEmpty ? Colors.black54 : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _AppMultiSelectDialog<T> extends StatefulWidget {
  const _AppMultiSelectDialog({
    required this.dialogTitle,
    required this.items,
    required this.initialSelection,
    required this.searchLabel,
    required this.searchHint,
    required this.emptyItemsMessage,
    required this.emptySearchMessage,
    required this.countLabel,
    required this.itemExtent,
    required this.showSearch,
  });

  final String dialogTitle;
  final List<AppMultiSelectItem<T>> items;
  final Set<T> initialSelection;
  final String searchLabel;
  final String searchHint;
  final String emptyItemsMessage;
  final String emptySearchMessage;
  final String countLabel;
  final double itemExtent;
  final bool showSearch;

  @override
  State<_AppMultiSelectDialog<T>> createState() =>
      _AppMultiSelectDialogState<T>();
}

class _AppMultiSelectDialogState<T> extends State<_AppMultiSelectDialog<T>> {
  late final Set<T> _selection;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _selectionCount = ValueNotifier<int>(0);
  Timer? _searchDebounce;
  String _searchQuery = '';
  late List<AppMultiSelectItem<T>> _filteredItems;

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
    _selectionCount.value = _selection.length;
    _filteredItems = List<AppMultiSelectItem<T>>.from(widget.items);
    if (widget.showSearch) {
      _searchController.addListener(_handleSearchChange);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    if (widget.showSearch) {
      _searchController.removeListener(_handleSearchChange);
      _searchController.dispose();
    }
    _scrollController.dispose();
    _selectionCount.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final query = _searchController.text.trim().toLowerCase();
      setState(() {
        _searchQuery = _searchController.text;
        _filteredItems = widget.items.where((item) {
          if (query.isEmpty) return true;
          return item.searchText.toLowerCase().contains(query);
        }).toList();
      });
    });
  }

  void _toggleItem(T value) {
    if (_selection.contains(value)) {
      _selection.remove(value);
    } else {
      _selection.add(value);
    }
    _selectionCount.value = _selection.length;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFiltering = _searchQuery.trim().isNotEmpty;

    return AlertDialog(
      title: ValueListenableBuilder<int>(
        valueListenable: _selectionCount,
        builder: (context, count, _) {
          return Text('${widget.dialogTitle} ($count selected)');
        },
      ),
      content: SizedBox(
        width: 520,
        height: 460,
        child: widget.items.isEmpty
            ? Center(
                child: Text(
                  widget.emptyItemsMessage,
                  style: const TextStyle(color: Colors.black),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.showSearch) ...[
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: widget.searchLabel,
                        prefixIcon: const Icon(Icons.search),
                        hintText: widget.searchHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    isFiltering
                        ? '${_filteredItems.length} of ${widget.items.length} ${widget.countLabel} shown'
                        : '${widget.items.length} ${widget.countLabel}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? Center(
                            child: Text(
                              widget.emptySearchMessage,
                              style: const TextStyle(color: Colors.black),
                            ),
                          )
                        : AppScrollbar(
                            controller: _scrollController,
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(right: 20),
                              itemExtent: widget.itemExtent,
                              cacheExtent: 480,
                              itemCount: _filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                return _AppMultiSelectListItem(
                                  key: ValueKey(item.value),
                                  item: item,
                                  isSelected: _selection.contains(item.value),
                                  onToggle: () => _toggleItem(item.value),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selection),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }
}

class _AppMultiSelectListItem<T> extends StatelessWidget {
  const _AppMultiSelectListItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggle,
  });

  final AppMultiSelectItem<T> item;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textColor = item.dimmed ? Colors.black54 : Colors.black;
    final subtitle = item.subtitle;

    return InkWell(
      onTap: onToggle,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Checkbox(
            value: isSelected,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (_) => onToggle(),
          ),
        ],
      ),
    );
  }
}

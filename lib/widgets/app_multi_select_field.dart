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
    this.singleSelect = false,
    this.showSearch = true,
    this.itemExtent,
    this.showClearButton = true,
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

  /// When true, picking an item selects it immediately (like a dropdown).
  final bool singleSelect;
  final bool showSearch;

  /// Optional fixed row height. Multi-select defaults to 72; single-select
  /// defaults to null so rows can grow when labels wrap on narrow screens.
  final double? itemExtent;

  /// When true, shows a clear control when [selectedValues] is not empty.
  final bool showClearButton;

  double? get _resolvedItemExtent =>
      itemExtent ?? (singleSelect ? null : 72);

  String get _fieldSummary {
    if (selectedValues.isEmpty) {
      return emptySelectionText ?? 'Select $fieldLabel';
    }
    if (singleSelect) {
      final selected = selectedValues.first;
      for (final item in items) {
        if (item.value == selected) return item.label;
      }
      return selected.toString();
    }
    if (countSummary != null) {
      return countSummary!.format(selectedValues.length);
    }
    return selectionSummaryBuilder?.call(selectedValues, items) ??
        '${selectedValues.length} selected';
  }

  Future<void> _openPicker(BuildContext context) async {
    if (singleSelect) {
      final result = await showDialog<Set<T>>(
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
          itemExtent: _resolvedItemExtent,
          showSearch: showSearch,
          singleSelect: singleSelect,
        ),
      );
      if (result != null) {
        onChanged(result);
      }
      return;
    }

    await showDialog<void>(
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
        itemExtent: _resolvedItemExtent,
        showSearch: showSearch,
        singleSelect: singleSelect,
        onSelectionChanged: onChanged,
      ),
    );
  }

  void _clearSelection() {
    onChanged({});
  }

  Widget? _buildSuffixIcon(BuildContext context) {
    final openPicker = enabled ? () => _openPicker(context) : null;
    final dropdownButton = IconButton(
      icon: const Icon(Icons.arrow_drop_down),
      tooltip: 'Open',
      onPressed: openPicker,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );

    if (!showClearButton || selectedValues.isEmpty || !enabled) {
      return dropdownButton;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.clear, size: 20),
          tooltip: 'Clear selection',
          onPressed: _clearSelection,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        dropdownButton,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final textColor = enabled
        ? onSurface
        : onSurface.withValues(alpha: 0.38);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: fieldLabel,
        enabled: enabled,
        suffixIcon: _buildSuffixIcon(context),
      ),
      child: InkWell(
        onTap: enabled ? () => _openPicker(context) : null,
        child: Text(
          _fieldSummary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor),
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
    required this.singleSelect,
    this.onSelectionChanged,
  });

  final String dialogTitle;
  final List<AppMultiSelectItem<T>> items;
  final Set<T> initialSelection;
  final String searchLabel;
  final String searchHint;
  final String emptyItemsMessage;
  final String emptySearchMessage;
  final String countLabel;
  final double? itemExtent;
  final bool showSearch;
  final bool singleSelect;
  final ValueChanged<Set<T>>? onSelectionChanged;

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
  late final List<AppMultiSelectItem<T>> _orderedItems;
  late List<AppMultiSelectItem<T>> _filteredItems;

  @override
  void initState() {
    super.initState();
    _selection = {...widget.initialSelection};
    _selectionCount.value = _selection.length;
    _orderedItems = _itemsWithInitialSelectionFirst(
      widget.items,
      widget.initialSelection,
    );
    _filteredItems = _filterItems(_orderedItems, _searchQuery);
    if (widget.showSearch) {
      _searchController.addListener(_handleSearchChange);
    }
  }

  /// On open, pin pre-selected values to the top. Order stays fixed for the
  /// rest of this dialog session; reopening re-pins all current selections.
  List<AppMultiSelectItem<T>> _itemsWithInitialSelectionFirst(
    List<AppMultiSelectItem<T>> items,
    Set<T> initialSelection,
  ) {
    if (initialSelection.isEmpty) return List<AppMultiSelectItem<T>>.from(items);

    final selected = <AppMultiSelectItem<T>>[];
    final unselected = <AppMultiSelectItem<T>>[];
    for (final item in items) {
      if (initialSelection.contains(item.value)) {
        selected.add(item);
      } else {
        unselected.add(item);
      }
    }
    return [...selected, ...unselected];
  }

  List<AppMultiSelectItem<T>> _filterItems(
    List<AppMultiSelectItem<T>> items,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return List<AppMultiSelectItem<T>>.from(items);
    return items
        .where((item) => item.searchText.toLowerCase().contains(normalized))
        .toList();
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
      setState(() {
        _searchQuery = _searchController.text;
        _filteredItems = _filterItems(_orderedItems, _searchQuery);
      });
    });
  }

  void _toggleItem(T value) {
    if (widget.singleSelect) {
      _searchDebounce?.cancel();
      Navigator.of(context).pop({value});
      return;
    }
    if (_selection.contains(value)) {
      _selection.remove(value);
    } else {
      _selection.add(value);
    }
    _selectionCount.value = _selection.length;
    widget.onSelectionChanged?.call({..._selection});
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isFiltering = _searchQuery.trim().isNotEmpty;

    return AlertDialog(
      title: widget.singleSelect
          ? Text(widget.dialogTitle)
          : ValueListenableBuilder<int>(
              valueListenable: _selectionCount,
              builder: (context, count, _) {
                return Text('${widget.dialogTitle} ($count selected)');
              },
            ),
      content: SizedBox(
        width: widget.singleSelect ? 480 : 520,
        height: widget.singleSelect ? 420 : 460,
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
                      decoration: InputDecoration(
                        labelText: widget.searchLabel,
                        prefixIcon: const Icon(Icons.search),
                        hintText: widget.searchHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (!widget.singleSelect) ...[
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
                  ],
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
                                  singleSelect: widget.singleSelect,
                                  onToggle: () => _toggleItem(item.value),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
      ),
      actions: widget.singleSelect
          ? null
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
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
    required this.singleSelect,
    required this.onToggle,
  });

  final AppMultiSelectItem<T> item;
  final bool isSelected;
  final bool singleSelect;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final textColor = item.dimmed ? Colors.black54 : Colors.black;
    final subtitle = item.subtitle;
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: singleSelect ? 8 : 0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: singleSelect ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Text(
                    item.label,
                    maxLines: singleSelect ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: singleSelect ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.dimmed ? Colors.black38 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (singleSelect)
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? primary : Colors.black26,
              )
            else
              Checkbox(
                value: isSelected,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (_) => onToggle(),
              ),
          ],
        ),
      ),
    );
  }
}

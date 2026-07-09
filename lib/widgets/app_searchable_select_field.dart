import 'dart:async';

import 'package:flutter/material.dart';

import 'app_multi_select_field.dart';
import 'app_scrollbar.dart';

class AppSearchableSelectField<T> extends StatelessWidget {
  const AppSearchableSelectField({
    super.key,
    required this.fieldLabel,
    required this.dialogTitle,
    required this.items,
    required this.selectedValue,
    required this.onChanged,
    this.enabled = true,
    this.emptySelectionText,
    this.searchLabel = 'Search',
    this.searchHint = 'Type to filter...',
    this.emptyItemsMessage = 'No items available.',
    this.emptySearchMessage = 'No items match the search.',
    this.itemExtent = 72,
    this.showSearch = true,
  });

  final String fieldLabel;
  final String dialogTitle;
  final List<AppMultiSelectItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final String? emptySelectionText;
  final String searchLabel;
  final String searchHint;
  final String emptyItemsMessage;
  final String emptySearchMessage;
  final double itemExtent;
  final bool showSearch;

  String get _fieldSummary {
    if (selectedValue == null) {
      return emptySelectionText ?? 'Select $fieldLabel';
    }
    for (final item in items) {
      if (item.value == selectedValue) return item.label;
    }
    return selectedValue.toString();
  }

  Future<void> _openPicker(BuildContext context) async {
    final nextValue = await showDialog<T>(
      context: context,
      builder: (context) => _AppSearchableSelectDialog<T>(
        dialogTitle: dialogTitle,
        items: items,
        initialValue: selectedValue,
        searchLabel: searchLabel,
        searchHint: searchHint,
        emptyItemsMessage: emptyItemsMessage,
        emptySearchMessage: emptySearchMessage,
        itemExtent: itemExtent,
        showSearch: showSearch,
      ),
    );

    if (nextValue != null) onChanged(nextValue);
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
            color: selectedValue == null ? Colors.black54 : Colors.black,
          ),
        ),
      ),
    );
  }
}

class _AppSearchableSelectDialog<T> extends StatefulWidget {
  const _AppSearchableSelectDialog({
    required this.dialogTitle,
    required this.items,
    required this.initialValue,
    required this.searchLabel,
    required this.searchHint,
    required this.emptyItemsMessage,
    required this.emptySearchMessage,
    required this.itemExtent,
    required this.showSearch,
  });

  final String dialogTitle;
  final List<AppMultiSelectItem<T>> items;
  final T? initialValue;
  final String searchLabel;
  final String searchHint;
  final String emptyItemsMessage;
  final String emptySearchMessage;
  final double itemExtent;
  final bool showSearch;

  @override
  State<_AppSearchableSelectDialog<T>> createState() =>
      _AppSearchableSelectDialogState<T>();
}

class _AppSearchableSelectDialogState<T>
    extends State<_AppSearchableSelectDialog<T>> {
  late T? _selection;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selection = widget.initialValue;
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
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  List<AppMultiSelectItem<T>> get _filteredItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where((item) => item.searchText.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final isFiltering = _searchQuery.trim().isNotEmpty;

    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
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
              const SizedBox(height: 12),
            ],
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyItemsMessage,
                        style: const TextStyle(color: Colors.black),
                      ),
                    )
                  : filteredItems.isEmpty
                  ? Center(
                      child: Text(
                        isFiltering
                            ? widget.emptySearchMessage
                            : widget.emptyItemsMessage,
                        style: const TextStyle(color: Colors.black),
                      ),
                    )
                  : AppScrollbar(
                      controller: _scrollController,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemExtent: widget.itemExtent,
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final isSelected = _selection == item.value;
                          return ListTile(
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: item.dimmed ? Colors.black54 : Colors.black,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: item.subtitle == null
                                ? null
                                : Text(
                                    item.subtitle!,
                                    style: TextStyle(
                                      color: item.dimmed
                                          ? Colors.black38
                                          : Colors.black54,
                                    ),
                                  ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                            onTap: () => setState(() => _selection = item.value),
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
        FilledButton(
          onPressed: _selection == null
              ? null
              : () => Navigator.of(context).pop(_selection),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

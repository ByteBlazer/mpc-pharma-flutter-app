import 'dart:math' show max, min;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_providers.dart';
import 'web_portal_styles.dart';
import 'web_portal_theme.dart';

enum _LocationSortField { id, name }

const _pagePaddingWide = 24.0;
const _pagePaddingNarrow = 12.0;
const _toolbarStackBreakpoint = 720.0;
const _tableMaxHeight = 500.0;
const _editWidth = 72.0;
const _idWidth = 112.0;
const _rowHeight = 52.0;
const _minColName = 200.0;
const _flexName = 1;

double _pagePadding(double width) =>
    width >= 600 ? _pagePaddingWide : _pagePaddingNarrow;

double _tableMinWidth() => _editWidth + _idWidth + _minColName;

class _LocationFormErrors {
  bool name = false;

  void clear() => name = false;

  bool get hasAny => name;
}

class WebPortalBaseLocationsScreen extends ConsumerStatefulWidget {
  const WebPortalBaseLocationsScreen({super.key});

  @override
  ConsumerState<WebPortalBaseLocationsScreen> createState() =>
      _WebPortalBaseLocationsScreenState();
}

class _WebPortalBaseLocationsScreenState
    extends ConsumerState<WebPortalBaseLocationsScreen> {
  final _searchController = TextEditingController();
  final _nameController = TextEditingController();
  _LocationSortField _sortField = _LocationSortField.id;
  bool _sortAsc = false;
  WebPortalBaseLocation? _editingLocation;
  bool _isAdding = false;
  bool _saving = false;
  bool _hasAttemptedSubmit = false;
  final _formErrors = _LocationFormErrors();

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _resetFormState() {
    _nameController.clear();
    _hasAttemptedSubmit = false;
    _formErrors.clear();
  }

  void _openAdd() {
    setState(() {
      _isAdding = true;
      _editingLocation = null;
      _resetFormState();
    });
  }

  void _openEdit(WebPortalBaseLocation location) {
    setState(() {
      _isAdding = false;
      _editingLocation = location;
      _hasAttemptedSubmit = false;
      _formErrors.clear();
      _nameController.text = location.name;
    });
  }

  bool _fieldErrorVisible(bool fieldError) =>
      _isAdding ? (_hasAttemptedSubmit && fieldError) : fieldError;

  bool _validateFormForSubmit() {
    final trimmed = _nameController.text.trim();
    _formErrors.name = trimmed.isEmpty || trimmed.length > 50;
    return !_formErrors.hasAny;
  }

  List<WebPortalBaseLocation> _filterAndSort(List<WebPortalBaseLocation> list) {
    final q = _searchController.text.trim().toLowerCase();
    var filtered = list.where((l) {
      if (q.isEmpty) return true;
      return l.id.toLowerCase().contains(q) || l.name.toLowerCase().contains(q);
    }).toList();

    int idKey(String id) => int.tryParse(id) ?? 0;

    filtered.sort((a, b) {
      final cmp = switch (_sortField) {
        _LocationSortField.id => idKey(a.id).compareTo(idKey(b.id)),
        _LocationSortField.name =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return _sortAsc ? cmp : -cmp;
    });
    return filtered;
  }

  Future<void> _submitLocation(
    BuildContext dialogContext,
    StateSetter setDialogState,
  ) async {
    setDialogState(() {
      if (_isAdding) _hasAttemptedSubmit = true;
      _validateFormForSubmit();
    });
    if (_formErrors.hasAny) return;

    setState(() => _saving = true);
    setDialogState(() {});
    try {
      final api = ref.read(apiClientProvider);
      final name = _nameController.text.trim();
      if (_editingLocation != null) {
        await api.updatePortalBaseLocation(_editingLocation!.id, name: name);
      } else {
        await api.createPortalBaseLocation(name: name);
      }
      ref.invalidate(portalBaseLocationsProvider);
      if (!mounted) return;
      final wasAdding = _isAdding;
      Navigator.of(dialogContext).pop();
      setState(() {
        _saving = false;
        _isAdding = false;
        _editingLocation = null;
        _resetFormState();
      });
      await WebPortalMuiDialog.showResultDialog(
        context: context,
        title: 'Success',
        message: wasAdding
            ? 'Base location created successfully!'
            : 'Base location updated successfully!',
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      setDialogState(() {});
      await WebPortalMuiDialog.showResultDialog(
        context: context,
        title: 'Error',
        message: ApiClient.parseError(e),
      );
    }
  }

  Future<void> _showLocationDialog({WebPortalBaseLocation? location}) {
    if (location != null) {
      _openEdit(location);
    } else {
      _openAdd();
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: !_saving,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Theme(
        data: WebPortalTheme.dialogForm(),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final submitLabel = _saving
                ? (_isAdding ? 'Creating...' : 'Updating...')
                : (_isAdding
                    ? 'Create Base Location'
                    : 'Update Base Location');
            final savingMessage = _isAdding
                ? 'Creating Base Location...'
                : 'Updating Base Location...';
            final screenSize = MediaQuery.sizeOf(ctx);
            final dialogInset = screenSize.width < 480 ? 12.0 : 24.0;

            return Dialog(
              backgroundColor: Colors.white,
              elevation: 24,
              insetPadding: EdgeInsets.all(dialogInset),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: min(600, screenSize.width - dialogInset * 2),
                  maxHeight: min(400, screenSize.height - dialogInset * 2),
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Text(
                            _isAdding
                                ? 'Add Base Location'
                                : 'Edit Base Location',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                              letterSpacing: 0.15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            clipBehavior: Clip.none,
                            padding: const EdgeInsets.fromLTRB(
                              24,
                              WebPortalStyles.dialogFormContentTop,
                              24,
                              20,
                            ),
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 16),
                              decoration:
                                  WebPortalMuiDialog.outlinedFieldLabel(
                                'Name',
                                required: true,
                                error: _fieldErrorVisible(_formErrors.name),
                              ),
                              maxLength: 50,
                              buildCounter: (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              onChanged: (v) => setDialogState(() {
                                final valid =
                                    v.trim().isNotEmpty && v.trim().length <= 50;
                                _formErrors.name = !valid && v.isNotEmpty;
                              }),
                            ),
                          ),
                        ),
                        WebPortalMuiDialog.dialogActionsBar([
                          WebPortalMuiDialog.cancelActionButton(
                            dialogContext,
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(dialogContext).pop(),
                          ),
                          WebPortalMuiDialog.containedActionButton(
                            label: submitLabel,
                            onPressed: _saving
                                ? null
                                : () => _submitLocation(
                                      dialogContext,
                                      setDialogState,
                                    ),
                          ),
                        ]),
                      ],
                    ),
                    if (_saving)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.85),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(
                                  savingMessage,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(portalBaseLocationsProvider);

    return locationsAsync.when(
      loading: () => const LoadingOverlay(message: 'Loading base locations...'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(portalBaseLocationsProvider),
      ),
      data: (locations) {
        final filtered = _filterAndSort(locations);
        const headerHeight = 48.0;
        final bodyHeight = filtered.length * _rowHeight;
        final tableHeight = min(headerHeight + bodyHeight, _tableMaxHeight);
        final tableScrolls = headerHeight + bodyHeight > _tableMaxHeight;
        final pageWidth = MediaQuery.sizeOf(context).width;
        final pagePadding = _pagePadding(pageWidth);
        final stackToolbar = pageWidth < _toolbarStackBreakpoint;
        final tableMinWidth = _tableMinWidth();

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (stackToolbar) ...[
                  Text(
                    'Base Locations',
                    style: WebPortalStyles.pageTitle(context),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _AddBaseLocationButton(
                      onPressed: () => _showLocationDialog(),
                    ),
                  ),
                ] else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Base Locations',
                          style: WebPortalStyles.pageTitle(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _AddBaseLocationButton(
                        onPressed: () => _showLocationDialog(),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search base locations by ID or name...',
                    hintStyle: const TextStyle(
                      color: WebPortalStyles.textSecondary,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = max(
                      constraints.maxWidth,
                      tableMinWidth,
                    );
                    return _LocationsTableScrollPanel(
                      viewportWidth: constraints.maxWidth,
                      tableWidth: tableWidth,
                      tableHeight: tableHeight,
                      scrollsVertically: tableScrolls,
                      locations: filtered,
                      sortField: _sortField,
                      sortAsc: _sortAsc,
                      onSort: (field) => setState(() {
                        if (_sortField == field) {
                          _sortAsc = !_sortAsc;
                        } else {
                          _sortField = field;
                          _sortAsc = field == _LocationSortField.id
                              ? false
                              : true;
                        }
                      }),
                      onEdit: (loc) => _showLocationDialog(location: loc),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AddBaseLocationButton extends StatefulWidget {
  const _AddBaseLocationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_AddBaseLocationButton> createState() => _AddBaseLocationButtonState();
}

class _AddBaseLocationButtonState extends State<_AddBaseLocationButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _hovered
                ? WebPortalStyles.usersPrimaryDark
                : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: const Center(
            child: Text(
              'ADD BASE LOCATION',
              style: WebPortalStyles.usersAddUserLabelStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationsTableScrollPanel extends StatefulWidget {
  const _LocationsTableScrollPanel({
    required this.viewportWidth,
    required this.tableWidth,
    required this.tableHeight,
    required this.scrollsVertically,
    required this.locations,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.onEdit,
  });

  final double viewportWidth;
  final double tableWidth;
  final double tableHeight;
  final bool scrollsVertically;
  final List<WebPortalBaseLocation> locations;
  final _LocationSortField sortField;
  final bool sortAsc;
  final void Function(_LocationSortField field) onSort;
  final void Function(WebPortalBaseLocation location) onEdit;

  @override
  State<_LocationsTableScrollPanel> createState() =>
      _LocationsTableScrollPanelState();
}

class _LocationsTableScrollPanelState extends State<_LocationsTableScrollPanel> {
  late final ScrollController _horizontalController = ScrollController();
  late final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollsHorizontally = widget.tableWidth > widget.viewportWidth;

    Widget table = SizedBox(
      width: widget.tableWidth,
      height: widget.tableHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LocationsTableHeader(
            sortField: widget.sortField,
            sortAsc: widget.sortAsc,
            onSort: widget.onSort,
          ),
          if (widget.scrollsVertically)
            Expanded(
              child: Scrollbar(
                controller: _verticalController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _verticalController,
                  itemCount: widget.locations.length,
                  itemBuilder: (context, index) {
                    final loc = widget.locations[index];
                    return _LocationTableRow(
                      location: loc,
                      onEdit: () => widget.onEdit(loc),
                    );
                  },
                ),
              ),
            )
          else
            Column(
              children: widget.locations
                  .map(
                    (loc) => _LocationTableRow(
                      location: loc,
                      onEdit: () => widget.onEdit(loc),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );

    if (scrollsHorizontally) {
      table = SizedBox(
        width: widget.viewportWidth,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        ),
      );
    }

    return WebPortalPaper(padding: EdgeInsets.zero, child: table);
  }
}

class _LocationsTableHeader extends StatelessWidget {
  const _LocationsTableHeader({
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
  });

  final _LocationSortField sortField;
  final bool sortAsc;
  final void Function(_LocationSortField field) onSort;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WebPortalStyles.usersTableHeaderBg,
        border: Border(
          bottom: BorderSide(color: WebPortalStyles.borderColor),
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(width: _editWidth),
            SizedBox(
              width: _idWidth,
              child: _sortableHeader('ID', _LocationSortField.id),
            ),
            Expanded(
              flex: _flexName,
              child: _sortableHeader('Name', _LocationSortField.name),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortableHeader(String label, _LocationSortField field) {
    final active = sortField == field;
    return InkWell(
      onTap: () => onSort(field),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  style: WebPortalStyles.usersTableHeaderStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(
                  sortAsc ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: WebPortalStyles.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationTableRow extends StatefulWidget {
  const _LocationTableRow({
    required this.location,
    required this.onEdit,
  });

  final WebPortalBaseLocation location;
  final VoidCallback onEdit;

  @override
  State<_LocationTableRow> createState() => _LocationTableRowState();
}

class _LocationTableRowState extends State<_LocationTableRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _hovered
              ? WebPortalStyles.usersTableHoverBg
              : Colors.white,
          border: const Border(
            bottom: BorderSide(color: WebPortalStyles.borderColor),
          ),
        ),
        child: SizedBox(
          height: _rowHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _editWidth,
                child: Center(
                  child: _RowEditButton(onPressed: widget.onEdit),
                ),
              ),
              SizedBox(
                width: _idWidth,
                child: _dataCell(widget.location.id),
              ),
              Expanded(
                flex: _flexName,
                child: _dataCell(widget.location.name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dataCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: WebPortalStyles.usersTableCellStyle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _RowEditButton extends StatefulWidget {
  const _RowEditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_RowEditButton> createState() => _RowEditButtonState();
}

class _RowEditButtonState extends State<_RowEditButton> {
  bool _btnHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _btnHovered = true),
      onExit: (_) => setState(() => _btnHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _btnHovered
                ? WebPortalStyles.usersPrimaryDark
                : AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit_outlined, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text('EDIT', style: WebPortalStyles.usersRowEditLabelStyle),
            ],
          ),
        ),
      ),
    );
  }
}

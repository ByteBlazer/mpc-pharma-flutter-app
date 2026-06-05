import 'dart:math' show max, min;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common_widgets.dart';
import 'web_portal_dialog_roles_select.dart';
import 'web_portal_filter_dropdown.dart';
import 'web_portal_mui_dialog.dart';
import 'web_portal_providers.dart';
import 'web_portal_styles.dart';
import 'web_portal_theme.dart';
import 'web_portal_utils.dart';

enum _UserSortField { id, personName, baseLocationName }

const _usersPagePaddingWide = 24.0;
const _usersPagePaddingNarrow = 12.0;
const _usersToolbarStackBreakpoint = 720.0;
const _usersTableMaxHeight = 500.0;
const _usersEditWidth = 72.0;
const _usersIdWidth = 112.0;
const _usersRowHeight = 52.0;
const _minColPerson = 120.0;
const _minColBaseLoc = 110.0;
const _minColMobile = 100.0;
const _minColVehicle = 120.0;
const _minColCreated = 140.0;
const _minColActive = 72.0;
const _minColRole = 88.0;

double _usersPagePadding(double width) =>
    width >= 600 ? _usersPagePaddingWide : _usersPagePaddingNarrow;

double _usersTableMinWidth({required bool showRoles, required int roleCount}) {
  var width = _usersEditWidth +
      _usersIdWidth +
      _minColPerson +
      _minColBaseLoc +
      _minColMobile +
      _minColVehicle +
      _minColCreated +
      _minColActive;
  if (showRoles) width += roleCount * _minColRole;
  return width;
}
const _flexPerson = 20;
const _flexBaseLoc = 18;
const _flexMobile = 14;
const _flexVehicle = 16;
const _flexCreated = 22;
const _flexActive = 10;
const _flexRole = 12;

class _UserFormErrors {
  bool personName = false;
  bool mobile = false;
  bool baseLocationId = false;
  bool roles = false;
  bool vehicleNbr = false;

  void clear() {
    personName = false;
    mobile = false;
    baseLocationId = false;
    roles = false;
    vehicleNbr = false;
  }

  bool get hasAny =>
      personName || mobile || baseLocationId || roles || vehicleNbr;
}

class WebPortalUsersScreen extends ConsumerStatefulWidget {
  const WebPortalUsersScreen({super.key});

  @override
  ConsumerState<WebPortalUsersScreen> createState() =>
      _WebPortalUsersScreenState();
}

class _WebPortalUsersScreenState extends ConsumerState<WebPortalUsersScreen> {
  final _searchController = TextEditingController();
  _UserSortField _sortField = _UserSortField.id;
  bool _sortAsc = false;
  bool _showRoles = false;
  bool _hideInactive = true;
  WebPortalUser? _editingUser;
  bool _isAdding = false;
  bool _saving = false;
  bool _hasAttemptedSubmit = false;
  final _formErrors = _UserFormErrors();

  final _personName = TextEditingController();
  final _mobile = TextEditingController();
  final _vehicleNbr = TextEditingController();
  String? _baseLocationId;
  final Set<String> _selectedRoles = {};
  bool _isActive = true;

  @override
  void dispose() {
    _searchController.dispose();
    _personName.dispose();
    _mobile.dispose();
    _vehicleNbr.dispose();
    super.dispose();
  }

  void _resetFormState() {
    _personName.clear();
    _mobile.clear();
    _vehicleNbr.clear();
    _baseLocationId = null;
    _selectedRoles.clear();
    _isActive = true;
    _hasAttemptedSubmit = false;
    _formErrors.clear();
  }

  void _openAdd() {
    setState(() {
      _isAdding = true;
      _editingUser = null;
      _resetFormState();
    });
  }

  void _openEdit(WebPortalUser user) {
    setState(() {
      _isAdding = false;
      _editingUser = user;
      _hasAttemptedSubmit = false;
      _formErrors.clear();
      _personName.text = user.personName;
      _mobile.text = user.mobile;
      _vehicleNbr.text = user.vehicleNbr;
      _baseLocationId = user.baseLocationId;
      _selectedRoles
        ..clear()
        ..addAll(user.roles.map((r) => r.roleName));
      _isActive = user.isActive;
    });
  }

  bool _fieldErrorVisible(bool fieldError) =>
      _isAdding ? (_hasAttemptedSubmit && fieldError) : fieldError;

  bool _validateFormForSubmit() {
    _formErrors.personName = _personName.text.trim().isEmpty ||
        _personName.text.trim().length > 25;
    _formErrors.mobile = _mobile.text.trim().isEmpty ||
        !RegExp(r'^\d{10}$').hasMatch(_mobile.text.trim());
    _formErrors.baseLocationId =
        _baseLocationId == null || _baseLocationId!.isEmpty;
    _formErrors.roles = _selectedRoles.isEmpty;
    _formErrors.vehicleNbr = _vehicleNbr.text.length > 15;
    return !_formErrors.hasAny;
  }

  Future<void> _submitUser(
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
      final data = WebPortalUserFormData(
        mobile: _mobile.text.trim(),
        personName: _personName.text.trim(),
        baseLocationId: _baseLocationId!,
        vehicleNbr: _vehicleNbr.text,
        roles: _selectedRoles.toList(),
        isActive: _isActive,
      );
      if (_editingUser != null) {
        await api.updatePortalUser(_editingUser!.id, data);
      } else {
        await api.createPortalUser(data);
      }
      ref.invalidate(portalUsersProvider);
      if (!mounted) return;
      final wasAdding = _isAdding;
      Navigator.of(dialogContext).pop();
      setState(() {
        _saving = false;
        _isAdding = false;
        _editingUser = null;
        _resetFormState();
      });
      await WebPortalMuiDialog.showResultDialog(
        context: context,
        title: 'Success',
        message: wasAdding
            ? 'User created successfully!'
            : 'User updated successfully!',
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

  List<WebPortalUser> _filterAndSort(List<WebPortalUser> users) {
    final q = _searchController.text.trim().toLowerCase();
    var list = users.where((u) {
      if (_hideInactive && !u.isActive) return false;
      if (q.isEmpty) return true;
      final fields = [
        u.id,
        u.personName,
        u.baseLocationName,
        u.mobile,
        u.vehicleNbr,
        ...u.roles.map((r) => r.roleName),
      ];
      return fields.any((f) => f.toLowerCase().contains(q));
    }).toList();

    list.sort((a, b) {
      String av;
      String bv;
      switch (_sortField) {
        case _UserSortField.personName:
          av = a.personName;
          bv = b.personName;
        case _UserSortField.baseLocationName:
          av = a.baseLocationName;
          bv = b.baseLocationName;
        case _UserSortField.id:
          av = a.id;
          bv = b.id;
      }
      final cmp = av.compareTo(bv);
      return _sortAsc ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(portalUsersProvider);
    final rolesAsync = ref.watch(portalUserRolesListProvider);
    final locationsAsync = ref.watch(portalBaseLocationsProvider);

    return usersAsync.when(
      loading: () => const LoadingOverlay(message: 'Loading users...'),
      error: (e, _) => ErrorView(
        message: e.toString(),
        onRetry: () => ref.invalidate(portalUsersProvider),
      ),
      data: (users) => rolesAsync.when(
        loading: () => const LoadingOverlay(message: 'Loading roles...'),
        error: (e, _) => ErrorView(message: e.toString()),
        data: (allRoles) => locationsAsync.when(
          loading: () => const LoadingOverlay(message: 'Loading locations...'),
          error: (e, _) => ErrorView(message: e.toString()),
          data: (locations) {
            final filtered = _filterAndSort(users);
            final headerHeight = _showRoles ? 88.0 : 48.0;
            final bodyHeight = filtered.length * _usersRowHeight;
            final tableHeight =
                min(headerHeight + bodyHeight, _usersTableMaxHeight);
            final tableScrolls =
                headerHeight + bodyHeight > _usersTableMaxHeight;

            final pageWidth = MediaQuery.sizeOf(context).width;
            final pagePadding = _usersPagePadding(pageWidth);
            final stackToolbar = pageWidth < _usersToolbarStackBreakpoint;
            final tableMinWidth = _usersTableMinWidth(
              showRoles: _showRoles,
              roleCount: allRoles.length,
            );

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Users',
                                style: WebPortalStyles.pageTitle(context),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _UsersAddUserButton(
                              onPressed: () => _showUserDialog(
                                context,
                                allRoles,
                                locations,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (stackToolbar) ...[
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText:
                                  'Search users by ID, name, location, mobile, vehicle number, or roles...',
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
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _ShowRolesToggle(
                              showRoles: _showRoles,
                              onToggle: () =>
                                  setState(() => _showRoles = !_showRoles),
                            ),
                          ),
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search users by ID, name, location, mobile, vehicle number, or roles...',
                                    hintStyle: const TextStyle(
                                      color: WebPortalStyles.textSecondary,
                                    ),
                                    suffixIcon:
                                        _searchController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {});
                                                },
                                              )
                                            : null,
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 16),
                              _ShowRolesToggle(
                                showRoles: _showRoles,
                                onToggle: () =>
                                    setState(() => _showRoles = !_showRoles),
                              ),
                            ],
                          ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final tableWidth = max(
                              constraints.maxWidth,
                              tableMinWidth,
                            );
                            return _UsersTableScrollPanel(
                              viewportWidth: constraints.maxWidth,
                              tableWidth: tableWidth,
                              tableHeight: tableHeight,
                              scrollsVertically: tableScrolls,
                              users: filtered,
                              showRoles: _showRoles,
                              allRoles: allRoles,
                              sortField: _sortField,
                              sortAsc: _sortAsc,
                              onSort: (field) => setState(() {
                                if (_sortField == field) {
                                  _sortAsc = !_sortAsc;
                                } else {
                                  _sortField = field;
                                  _sortAsc = true;
                                }
                              }),
                              onEditUser: (user) => _showUserDialog(
                                context,
                                allRoles,
                                locations,
                                user: user,
                              ),
                            );
                          },
                        ),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _hideInactive,
                          onChanged: (v) =>
                              setState(() => _hideInactive = v ?? true),
                          title: const Text(
                            'Hide Inactive Users',
                            style: TextStyle(fontSize: 14),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showUserDialog(
    BuildContext context,
    List<WebPortalUserRole> allRoles,
    List<WebPortalBaseLocation> locations, {
    WebPortalUser? user,
  }) {
    if (user != null) {
      _openEdit(user);
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
                : (_isAdding ? 'Create User' : 'Update User');

            final savingMessage =
                _isAdding ? 'Creating User...' : 'Updating User...';

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
                  maxHeight: min(
                    640,
                    screenSize.height - dialogInset * 2,
                  ),
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
                        _isAdding ? 'Add User' : 'Edit User',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _personName,
                              style: const TextStyle(fontSize: 16),
                              decoration: WebPortalMuiDialog.outlinedFieldLabel(
                                'Person Name',
                                required: true,
                                error: _fieldErrorVisible(
                                  _formErrors.personName,
                                ),
                              ),
                              maxLength: 25,
                              buildCounter: (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              onChanged: (v) => setDialogState(() {
                                final valid = v.trim().isNotEmpty &&
                                    v.trim().length <= 25;
                                _formErrors.personName =
                                    !valid && v.isNotEmpty;
                              }),
                            ),
                            const SizedBox(
                              height: WebPortalStyles.dialogFormFieldGap,
                            ),
                            TextField(
                              controller: _mobile,
                              style: const TextStyle(fontSize: 16),
                              decoration: WebPortalMuiDialog.outlinedFieldLabel(
                                'Mobile',
                                required: true,
                                error: _fieldErrorVisible(_formErrors.mobile),
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 10,
                              buildCounter: (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (v) => setDialogState(() {
                                final valid =
                                    v.length == 10 && RegExp(r'^\d{10}$').hasMatch(v);
                                _formErrors.mobile = !valid && v.isNotEmpty;
                              }),
                            ),
                            const SizedBox(
                              height: WebPortalStyles.dialogFormFieldGap,
                            ),
                            WebPortalStyles.dialogFormFieldSlot(
                              child: WebPortalFilterDropdown(
                                label: 'Base Location *',
                                dialogForm: true,
                                hasError: _fieldErrorVisible(
                                  _formErrors.baseLocationId,
                                ),
                                options: [
                                  for (final loc in locations)
                                    WebPortalDropdownOption(
                                      id: loc.id,
                                      label: loc.name,
                                    ),
                                ],
                                selectedId: _baseLocationId,
                                onSelected: (v) => setDialogState(
                                  () => _baseLocationId = v,
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: WebPortalStyles.dialogFormFieldGap,
                            ),
                            TextField(
                              controller: _vehicleNbr,
                              style: const TextStyle(fontSize: 16),
                              decoration: WebPortalMuiDialog.outlinedFieldLabel(
                                'Vehicle Number',
                                error: _fieldErrorVisible(
                                  _formErrors.vehicleNbr,
                                ),
                              ),
                              maxLength: 15,
                              buildCounter: (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              onChanged: (v) => setDialogState(() {
                                _formErrors.vehicleNbr =
                                    v.length > 15;
                              }),
                            ),
                            const SizedBox(
                              height: WebPortalStyles.dialogFormFieldGap,
                            ),
                            WebPortalDialogRolesSelect(
                              hasError: _fieldErrorVisible(_formErrors.roles),
                              options: [
                                for (final role in allRoles)
                                  WebPortalDropdownOption(
                                    id: role.roleName,
                                    label: role.roleName,
                                  ),
                              ],
                              selectedIds: _selectedRoles,
                              onSelectionChanged: (roles) => setDialogState(() {
                                _selectedRoles
                                  ..clear()
                                  ..addAll(roles);
                              }),
                            ),
                            if (_editingUser != null) ...[
                              const SizedBox(
                                height: WebPortalStyles.dialogFormFieldGap,
                              ),
                              DropdownButtonFormField<String>(
                                value: _isActive ? 'yes' : 'no',
                                isExpanded: true,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                                decoration:
                                    WebPortalMuiDialog.outlinedFieldLabel(
                                  'Active',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'yes',
                                    child: Text('Yes'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'no',
                                    child: Text('No'),
                                  ),
                                ],
                                onChanged: (v) => setDialogState(
                                  () => _isActive = v == 'yes',
                                ),
                              ),
                            ],
                          ],
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
                            : () => _submitUser(dialogContext, setDialogState),
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
}

/// MUI contained `Button` — default size, uppercase, hover `primary.dark`.
class _UsersAddUserButton extends StatefulWidget {
  const _UsersAddUserButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_UsersAddUserButton> createState() => _UsersAddUserButtonState();
}

class _UsersAddUserButtonState extends State<_UsersAddUserButton> {
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
            child: Text('ADD USER', style: WebPortalStyles.usersAddUserLabelStyle),
          ),
        ),
      ),
    );
  }
}

/// MUI `ToggleButton` `size="small"` — React hover: light fill or dark when selected.
class _ShowRolesToggle extends StatefulWidget {
  const _ShowRolesToggle({
    required this.showRoles,
    required this.onToggle,
  });

  final bool showRoles;
  final VoidCallback onToggle;

  @override
  State<_ShowRolesToggle> createState() => _ShowRolesToggleState();
}

class _ShowRolesToggleState extends State<_ShowRolesToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.showRoles;
    final bg = selected
        ? (_hovered ? WebPortalStyles.usersPrimaryDark : AppColors.primary)
        : (_hovered ? WebPortalStyles.usersPrimaryLight : Colors.transparent);
    final fg = selected || _hovered ? Colors.white : AppColors.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.primary),
          ),
          child: Center(
            child: Text(
              selected ? 'HIDE ROLES' : 'SHOW ROLES',
              style: WebPortalStyles.usersRolesToggleLabelStyle(
                selected: selected,
              ).copyWith(color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Table with linked horizontal/vertical scroll controllers for narrow viewports.
class _UsersTableScrollPanel extends StatefulWidget {
  const _UsersTableScrollPanel({
    required this.viewportWidth,
    required this.tableWidth,
    required this.tableHeight,
    required this.scrollsVertically,
    required this.users,
    required this.showRoles,
    required this.allRoles,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
    required this.onEditUser,
  });

  final double viewportWidth;
  final double tableWidth;
  final double tableHeight;
  final bool scrollsVertically;
  final List<WebPortalUser> users;
  final bool showRoles;
  final List<WebPortalUserRole> allRoles;
  final _UserSortField sortField;
  final bool sortAsc;
  final void Function(_UserSortField field) onSort;
  final void Function(WebPortalUser user) onEditUser;

  @override
  State<_UsersTableScrollPanel> createState() => _UsersTableScrollPanelState();
}

class _UsersTableScrollPanelState extends State<_UsersTableScrollPanel> {
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
          _UsersTableHeader(
            showRoles: widget.showRoles,
            allRoles: widget.allRoles,
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
                  itemCount: widget.users.length,
                  itemBuilder: (context, index) {
                    final user = widget.users[index];
                    return _UserTableRow(
                      user: user,
                      showRoles: widget.showRoles,
                      allRoles: widget.allRoles,
                      onEdit: () => widget.onEditUser(user),
                    );
                  },
                ),
              ),
            )
          else
            Column(
              children: widget.users
                  .map(
                    (user) => _UserTableRow(
                      user: user,
                      showRoles: widget.showRoles,
                      allRoles: widget.allRoles,
                      onEdit: () => widget.onEditUser(user),
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

    return WebPortalPaper(
      padding: EdgeInsets.zero,
      child: table,
    );
  }
}

/// Shared flex column layout — MUI `Table` fullWidth column distribution.
class _UsersTableRowLayout extends StatelessWidget {
  const _UsersTableRowLayout({
    required this.editCell,
    required this.idCell,
    required this.personName,
    required this.baseLocation,
    required this.mobile,
    required this.vehicle,
    required this.createdAt,
    required this.active,
    this.showRoles = false,
    this.roleCells = const [],
  });

  final Widget editCell;
  final Widget idCell;
  final Widget personName;
  final Widget baseLocation;
  final Widget mobile;
  final Widget vehicle;
  final Widget createdAt;
  final Widget active;
  final bool showRoles;
  final List<Widget> roleCells;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: _usersEditWidth, child: editCell),
        SizedBox(width: _usersIdWidth, child: idCell),
        Expanded(flex: _flexPerson, child: personName),
        Expanded(flex: _flexBaseLoc, child: baseLocation),
        Expanded(flex: _flexMobile, child: mobile),
        Expanded(flex: _flexVehicle, child: vehicle),
        Expanded(flex: _flexCreated, child: createdAt),
        Expanded(flex: _flexActive, child: active),
        if (showRoles)
          ...roleCells.map(
            (cell) => Expanded(flex: _flexRole, child: cell),
          ),
      ],
    );
  }
}

Widget _usersHeaderCell(String label) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: WebPortalStyles.usersTableHeaderStyle,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    ),
  );
}

Widget _usersDataCell(String text) {
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

class _UsersTableHeader extends StatelessWidget {
  const _UsersTableHeader({
    required this.showRoles,
    required this.allRoles,
    required this.sortField,
    required this.sortAsc,
    required this.onSort,
  });

  final bool showRoles;
  final List<WebPortalUserRole> allRoles;
  final _UserSortField sortField;
  final bool sortAsc;
  final void Function(_UserSortField field) onSort;

  @override
  Widget build(BuildContext context) {
    const topRowHeight = 48.0;
    const bottomRowHeight = 40.0;
    final totalHeight = showRoles ? topRowHeight + bottomRowHeight : topRowHeight;

    if (!showRoles) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          color: WebPortalStyles.usersTableHeaderBg,
          border: Border(
            bottom: BorderSide(color: WebPortalStyles.borderColor),
          ),
        ),
        child: SizedBox(
          height: totalHeight,
          child: _UsersTableRowLayout(
            editCell: const SizedBox.shrink(),
            idCell: _sortableHeader('ID', _UserSortField.id),
            personName: _sortableHeader('Person Name', _UserSortField.personName),
            baseLocation:
                _sortableHeader('Base Location', _UserSortField.baseLocationName),
            mobile: _usersHeaderCell('Mobile'),
            vehicle: _usersHeaderCell('Vehicle Number'),
            createdAt: _usersHeaderCell('Created At'),
            active: _usersHeaderCell('Active'),
          ),
        ),
      );
    }

    final rolesColSpan = allRoles.length * _flexRole;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WebPortalStyles.usersTableHeaderBg,
        border: Border(
          bottom: BorderSide(color: WebPortalStyles.borderColor),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: topRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: _usersEditWidth),
                SizedBox(
                  width: _usersIdWidth,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _sortableHeader('ID', _UserSortField.id),
                  ),
                ),
                Expanded(
                  flex: _flexPerson,
                  child: _sortableHeader('Person Name', _UserSortField.personName),
                ),
                Expanded(
                  flex: _flexBaseLoc,
                  child: _sortableHeader(
                    'Base Location',
                    _UserSortField.baseLocationName,
                  ),
                ),
                Expanded(flex: _flexMobile, child: _usersHeaderCell('Mobile')),
                Expanded(
                  flex: _flexVehicle,
                  child: _usersHeaderCell('Vehicle Number'),
                ),
                Expanded(
                  flex: _flexCreated,
                  child: _usersHeaderCell('Created At'),
                ),
                Expanded(flex: _flexActive, child: _usersHeaderCell('Active')),
                Expanded(
                  flex: rolesColSpan,
                  child: const Center(
                    child: Text(
                      'Roles',
                      style: WebPortalStyles.usersTableHeaderStyle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: bottomRowHeight,
            child: Row(
              children: [
                const SizedBox(width: _usersEditWidth),
                SizedBox(width: _usersIdWidth),
                const Expanded(flex: _flexPerson, child: SizedBox()),
                const Expanded(flex: _flexBaseLoc, child: SizedBox()),
                const Expanded(flex: _flexMobile, child: SizedBox()),
                const Expanded(flex: _flexVehicle, child: SizedBox()),
                const Expanded(flex: _flexCreated, child: SizedBox()),
                const Expanded(flex: _flexActive, child: SizedBox()),
                ...allRoles.map(
                  (role) => Expanded(
                    flex: _flexRole,
                    child: Center(
                      child: Text(
                        role.roleName,
                        style: WebPortalStyles.usersTableHeaderStyle,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortableHeader(String label, _UserSortField field) {
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

class _UserTableRow extends StatefulWidget {
  const _UserTableRow({
    required this.user,
    required this.showRoles,
    required this.allRoles,
    required this.onEdit,
  });

  final WebPortalUser user;
  final bool showRoles;
  final List<WebPortalUserRole> allRoles;
  final VoidCallback onEdit;

  @override
  State<_UserTableRow> createState() => _UserTableRowState();
}

class _UserTableRowState extends State<_UserTableRow> {
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
          height: _usersRowHeight,
          child: _UsersTableRowLayout(
            showRoles: widget.showRoles,
            editCell: Center(
              child: _UsersRowEditButton(onPressed: widget.onEdit),
            ),
            idCell: _usersDataCell(widget.user.id),
            personName: _usersDataCell(widget.user.personName),
            baseLocation: _usersDataCell(widget.user.baseLocationName),
            mobile: _usersDataCell(widget.user.mobile),
            vehicle: _usersDataCell(widget.user.vehicleNbr),
            createdAt: _usersDataCell(
              WebPortalUtils.formatUserCreatedAt(widget.user.createdAt),
            ),
            active: _usersDataCell(widget.user.isActive ? 'Yes' : 'No'),
            roleCells: widget.showRoles
                ? widget.allRoles.map((role) {
                    final has = widget.user.roles
                        .any((r) => r.roleName == role.roleName);
                    return Center(
                      child: Icon(
                        has ? Icons.check_circle : Icons.cancel,
                        color: has ? Colors.green : Colors.red,
                        size: 20,
                      ),
                    );
                  }).toList()
                : const [],
          ),
        ),
      ),
    );
  }
}

/// MUI `Button` `size="small"` contained — `px: 1`, hover `primary.dark`.
class _UsersRowEditButton extends StatefulWidget {
  const _UsersRowEditButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_UsersRowEditButton> createState() => _UsersRowEditButtonState();
}

class _UsersRowEditButtonState extends State<_UsersRowEditButton> {
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

import 'package:flutter/material.dart';

import '../../../app_theme.dart';
import '../../../api/api_client.dart';
import '../../../auth/app_role.dart';
import '../../customers/customer_models.dart';
import '../../leave_requests/leave_helpers.dart';
import '../../users/user_models.dart';
import '../../../utils/download_file.dart';
import '../../../widgets/app_load_error_state.dart';
import '../../../widgets/app_multi_select_field.dart';
import '../../../widgets/app_screen_scaffold.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/app_surface.dart';
import 'delivery_report_helpers.dart';
import 'delivery_report_models.dart';
import 'widgets/delivery_report_table.dart';

const _mobileLayoutBreakpoint = 768.0;
const _noDateSelectedLabel = 'No date selected';

class DeliveryReportScreen extends StatefulWidget {
  const DeliveryReportScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<DeliveryReportScreen> createState() => _DeliveryReportScreenState();
}

class _DeliveryReportScreenState extends State<DeliveryReportScreen> {
  late DateTime? _fromDate;
  late DateTime? _toDate;
  String? _customerId;
  String? _route;
  String? _originWarehouse;
  String? _tripStartLocation;
  String? _driverUserId;
  final _selectedCities = <String>{};
  final _docIdController = TextEditingController();
  final _tripIdController = TextEditingController();

  Future<_DeliveryReportFormData>? _formDataFuture;
  int? _matchedCount;
  List<DeliveryReportRow> _rows = const [];
  _DeliveryReportStatus? _resultStatus;
  bool _loadingCount = false;
  bool _loadingData = false;
  bool _downloadingExcel = false;

  @override
  void initState() {
    super.initState();
    _resetDatesToDefault();
    _formDataFuture = _loadFormData();
  }

  @override
  void dispose() {
    _docIdController.dispose();
    _tripIdController.dispose();
    super.dispose();
  }

  bool get _hasReportFeedback => _resultStatus != null;

  void _dismissReportFeedback() {
    _resultStatus = null;
    _rows = const [];
    _matchedCount = null;
  }

  void _onFiltersChanged(VoidCallback update) {
    setState(() {
      update();
      if (_hasReportFeedback || _rows.isNotEmpty || _matchedCount != null) {
        _dismissReportFeedback();
      }
    });
  }

  void _resetDatesToDefault() {
    final defaults = defaultDeliveryReportDateRange();
    _fromDate = defaults.$1;
    _toDate = defaults.$2;
  }

  Future<_DeliveryReportFormData> _loadFormData() async {
    final results = await Future.wait([
      widget.apiClient.getCustomersLightweight(),
      widget.apiClient.getRoutes(),
      widget.apiClient.getOriginWarehouses(),
      widget.apiClient.getBaseLocations(),
      widget.apiClient.getUsers(),
    ]);

    final customers = results[0] as List<CustomerSummary>;
    final routes = results[1] as List<String>;
    final warehouses = results[2] as List<String>;
    final baseLocations = results[3] as List<BaseLocation>;
    final users = results[4] as List<UserAccount>;

    final cities =
        customers
            .map((customer) => customer.city.trim())
            .where((city) => city.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();

    final drivers = users
        .where(
          (user) => user.isActive && user.roles.hasRole(AppRole.appTripDriver),
        )
        .toList(growable: false);

    return _DeliveryReportFormData(
      customers: customers,
      routes: routes,
      warehouses: warehouses,
      baseLocations: baseLocations,
      drivers: drivers,
      cities: cities,
    );
  }

  Map<String, String> _currentQueryParameters() {
    return buildDeliveryReportQueryParameters(
      fromDate: _fromDate,
      toDate: _toDate,
      customerId: _customerId,
      docId: _docIdController.text,
      route: _route,
      originWarehouse: _originWarehouse,
      tripStartLocation: _tripStartLocation,
      driverUserId: _driverUserId,
      customerCities: _selectedCities,
      tripId: _tripIdController.text,
    );
  }

  String? _validateFilters() {
    return validateDeliveryReportFilters(
      fromDate: _fromDate,
      toDate: _toDate,
      customerId: _customerId,
      docId: _docIdController.text,
      route: _route,
      originWarehouse: _originWarehouse,
      tripStartLocation: _tripStartLocation,
      driverUserId: _driverUserId,
      customerCities: _selectedCities,
      tripId: _tripIdController.text,
    );
  }

  Future<void> _handleApiError(Object error) async {
    if (!mounted) return;
    showAppSnackBar(
      context,
      message: error.toString(),
      type: AppSnackBarType.error,
    );
  }

  Future<void> _viewReport({required bool allowGrid}) async {
    final validationError = _validateFilters();
    if (validationError != null) {
      showAppSnackBar(
        context,
        message: validationError,
        type: AppSnackBarType.error,
      );
      return;
    }

    setState(() {
      _loadingCount = true;
      _resultStatus = null;
      _rows = const [];
      _matchedCount = null;
    });

    try {
      final query = _currentQueryParameters();
      final countResponse = await widget.apiClient.getDeliveryReportCount(
        queryParameters: query,
      );
      if (!mounted) return;

      final count = countResponse.totalRecords;
      setState(() {
        _matchedCount = count;
        _loadingCount = false;
      });

      if (count == 0) {
        setState(() {
          _resultStatus = const _DeliveryReportStatus(
            kind: _DeliveryReportStatusKind.noResults,
          );
        });
        return;
      }

      if (!allowGrid) {
        setState(() {
          _resultStatus = _DeliveryReportStatus(
            kind: _DeliveryReportStatusKind.mobileOnly,
            matchedCount: count,
          );
        });
        return;
      }

      if (count > deliveryReportMaxOnScreenRows) {
        setState(() {
          _resultStatus = _DeliveryReportStatus(
            kind: _DeliveryReportStatusKind.tooManyForGrid,
            matchedCount: count,
          );
        });
        return;
      }

      setState(() => _loadingData = true);
      final dataResponse = await widget.apiClient.getDeliveryReportData(
        queryParameters: query,
      );
      if (!mounted) return;

      setState(() {
        _rows = dataResponse.rows;
        _loadingData = false;
        _resultStatus = _DeliveryReportStatus(
          kind: _DeliveryReportStatusKind.loaded,
          matchedCount: dataResponse.totalRecords,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCount = false;
        _loadingData = false;
      });
      await _handleApiError(error);
    }
  }

  Future<void> _downloadExcel() async {
    final validationError = _validateFilters();
    if (validationError != null) {
      showAppSnackBar(
        context,
        message: validationError,
        type: AppSnackBarType.error,
      );
      return;
    }

    if (_matchedCount != null &&
        _matchedCount! >= deliveryReportLargeExportWarningThreshold) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Large export'),
          content: Text(
            'This export may include ${formatDeliveryReportCount(_matchedCount!)} records and could take a '
            'while to download. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    setState(() => _downloadingExcel = true);
    try {
      final download = await widget.apiClient.downloadDeliveryReportExcel(
        queryParameters: _currentQueryParameters(),
      );
      await downloadFile(
        fileName: download.fileName,
        bytes: download.bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (error) {
      if (mounted) await _handleApiError(error);
    } finally {
      if (mounted) setState(() => _downloadingExcel = false);
    }
  }

  void _resetFilters() {
    setState(() {
      _resetDatesToDefault();
      _customerId = null;
      _route = null;
      _originWarehouse = null;
      _tripStartLocation = null;
      _driverUserId = null;
      _selectedCities.clear();
      _docIdController.clear();
      _tripIdController.clear();
      _dismissReportFeedback();
    });
  }

  Future<void> _pickFromDate() async {
    final initial = _fromDate ?? istToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Document date from',
    );
    if (picked == null || !mounted) return;
    _onFiltersChanged(() {
      _fromDate = picked;
      if (_toDate == null || _toDate!.isBefore(picked)) {
        _toDate = picked;
      }
    });
  }

  Future<void> _pickToDate() async {
    final initialFrom = _fromDate ?? istToday();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? initialFrom,
      firstDate: initialFrom,
      lastDate: DateTime(2100),
      helpText: 'Document date to',
    );
    if (picked == null || !mounted) return;
    _onFiltersChanged(() {
      _toDate = picked;
      if (_fromDate == null || _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
    });
  }

  void _clearDates() {
    _onFiltersChanged(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _mobileLayoutBreakpoint;
    final isBusy = _loadingCount || _loadingData || _downloadingExcel;

    return AppScreenScaffold(
      appBar: AppBar(title: const Text('Delivery Report')),
      body: SafeArea(
        child: FutureBuilder<_DeliveryReportFormData>(
          future: _formDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Failed to load report filters',
                message: snapshot.error.toString(),
                onRetry: () =>
                    setState(() => _formDataFuture = _loadFormData()),
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final formData =
                snapshot.data ?? const _DeliveryReportFormData.empty();
            final showTable = isWide && _rows.isNotEmpty && !_loadingData;
            final showTableLoading = isWide && _loadingData;

            final filtersAndActions = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FiltersCard(
                  formData: formData,
                  fromDate: _fromDate,
                  toDate: _toDate,
                  customerId: _customerId,
                  route: _route,
                  originWarehouse: _originWarehouse,
                  tripStartLocation: _tripStartLocation,
                  driverUserId: _driverUserId,
                  selectedCities: _selectedCities,
                  docIdController: _docIdController,
                  tripIdController: _tripIdController,
                  isWide: isWide,
                  enabled: !isBusy,
                  onPickFromDate: _pickFromDate,
                  onPickToDate: _pickToDate,
                  onClearDates: _clearDates,
                  onCustomerChanged: (value) =>
                      _onFiltersChanged(() => _customerId = value),
                  onRouteChanged: (value) =>
                      _onFiltersChanged(() => _route = value),
                  onOriginWarehouseChanged: (value) =>
                      _onFiltersChanged(() => _originWarehouse = value),
                  onTripStartLocationChanged: (value) =>
                      _onFiltersChanged(() => _tripStartLocation = value),
                  onDriverChanged: (value) =>
                      _onFiltersChanged(() => _driverUserId = value),
                  onCitiesChanged: (values) => _onFiltersChanged(() {
                    _selectedCities
                      ..clear()
                      ..addAll(values);
                  }),
                  onFilterEdited: () => _onFiltersChanged(() {}),
                ),
                const SizedBox(height: 16),
                _ActionsRow(
                  isBusy: isBusy,
                  loadingCount: _loadingCount,
                  loadingData: _loadingData,
                  downloadingExcel: _downloadingExcel,
                  onViewReport: () => _viewReport(allowGrid: isWide),
                  onDownloadExcel: _downloadExcel,
                  onReset: _resetFilters,
                ),
                if (_resultStatus != null) ...[
                  const SizedBox(height: 16),
                  _DeliveryReportStatusBanner(status: _resultStatus!),
                ],
              ],
            );

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showTable || showTableLoading)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: filtersAndActions,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: filtersAndActions,
                          ),
                        ),
                      ),
                    ),
                  if (showTable) ...[
                    const SizedBox(height: 16),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: DeliveryReportTable(
                            rows: _rows,
                            apiClient: widget.apiClient,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (showTableLoading) ...[
                    const SizedBox(height: 16),
                    const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeliveryReportFormData {
  const _DeliveryReportFormData({
    required this.customers,
    required this.routes,
    required this.warehouses,
    required this.baseLocations,
    required this.drivers,
    required this.cities,
  });

  const _DeliveryReportFormData.empty()
    : customers = const [],
      routes = const [],
      warehouses = const [],
      baseLocations = const [],
      drivers = const [],
      cities = const [];

  final List<CustomerSummary> customers;
  final List<String> routes;
  final List<String> warehouses;
  final List<BaseLocation> baseLocations;
  final List<UserAccount> drivers;
  final List<String> cities;
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.formData,
    required this.fromDate,
    required this.toDate,
    required this.customerId,
    required this.route,
    required this.originWarehouse,
    required this.tripStartLocation,
    required this.driverUserId,
    required this.selectedCities,
    required this.docIdController,
    required this.tripIdController,
    required this.isWide,
    required this.enabled,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onClearDates,
    required this.onCustomerChanged,
    required this.onRouteChanged,
    required this.onOriginWarehouseChanged,
    required this.onTripStartLocationChanged,
    required this.onDriverChanged,
    required this.onCitiesChanged,
    required this.onFilterEdited,
  });

  final _DeliveryReportFormData formData;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? customerId;
  final String? route;
  final String? originWarehouse;
  final String? tripStartLocation;
  final String? driverUserId;
  final Set<String> selectedCities;
  final TextEditingController docIdController;
  final TextEditingController tripIdController;
  final bool isWide;
  final bool enabled;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onClearDates;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<String?> onOriginWarehouseChanged;
  final ValueChanged<String?> onTripStartLocationChanged;
  final ValueChanged<String?> onDriverChanged;
  final ValueChanged<Set<String>> onCitiesChanged;
  final VoidCallback onFilterEdited;

  @override
  Widget build(BuildContext context) {
    final fieldWidth = isWide ? 280.0 : double.infinity;

    Widget field(Widget child) {
      if (isWide) {
        return SizedBox(width: fieldWidth, child: child);
      }
      return child;
    }

    return AppSurface(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filters by document date, not delivery timestamp. Maximum allowed date range is 1 month.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _DateFilterRow(
              isWide: isWide,
              fieldWidth: fieldWidth,
              fromDate: fromDate,
              toDate: toDate,
              enabled: enabled,
              onPickFromDate: onPickFromDate,
              onPickToDate: onPickToDate,
              onClearDates: onClearDates,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Customer',
                    dialogTitle: 'Customer',
                    enabled: enabled,
                    singleSelect: true,
                    emptySelectionText: 'All customers',
                    items: formData.customers
                        .map(
                          (customer) => AppMultiSelectItem<String>(
                            value: customer.id,
                            label: customer.firmName,
                            subtitle: customer.id,
                            searchText:
                                '${customer.firmName} ${customer.id} ${customer.city}',
                          ),
                        )
                        .toList(),
                    selectedValues: customerId == null
                        ? const {}
                        : {customerId!},
                    onChanged: (values) =>
                        onCustomerChanged(values.isEmpty ? null : values.first),
                  ),
                ),
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Customer city',
                    dialogTitle: 'Customer city',
                    enabled: enabled,
                    emptySelectionText: 'All cities',
                    countSummary: const AppMultiSelectCountSummary(
                      singular: 'city',
                      plural: 'cities',
                    ),
                    countLabel: 'cities',
                    items: formData.cities
                        .map(
                          (city) => AppMultiSelectItem<String>(
                            value: city,
                            label: city,
                            searchText: city,
                          ),
                        )
                        .toList(),
                    selectedValues: selectedCities,
                    onChanged: onCitiesChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Parent Trip start location',
                    dialogTitle: 'Parent Trip start location',
                    enabled: enabled,
                    singleSelect: true,
                    emptySelectionText: 'All locations',
                    items: formData.baseLocations
                        .map(
                          (location) => AppMultiSelectItem<String>(
                            value: location.id,
                            label: location.name,
                            searchText: '${location.name} ${location.id}',
                          ),
                        )
                        .toList(),
                    selectedValues: tripStartLocation == null
                        ? const {}
                        : {tripStartLocation!},
                    onChanged: (values) => onTripStartLocationChanged(
                      values.isEmpty ? null : values.first,
                    ),
                  ),
                ),
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Route',
                    dialogTitle: 'Route',
                    enabled: enabled,
                    singleSelect: true,
                    emptySelectionText: 'All routes',
                    items: formData.routes
                        .map(
                          (value) => AppMultiSelectItem<String>(
                            value: value,
                            label: value,
                            searchText: value,
                          ),
                        )
                        .toList(),
                    selectedValues: route == null ? const {} : {route!},
                    onChanged: (values) =>
                        onRouteChanged(values.isEmpty ? null : values.first),
                  ),
                ),
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Origin warehouse',
                    dialogTitle: 'Origin warehouse',
                    enabled: enabled,
                    singleSelect: true,
                    emptySelectionText: 'All warehouses',
                    items: formData.warehouses
                        .map(
                          (value) => AppMultiSelectItem<String>(
                            value: value,
                            label: value,
                            searchText: value,
                          ),
                        )
                        .toList(),
                    selectedValues: originWarehouse == null
                        ? const {}
                        : {originWarehouse!},
                    onChanged: (values) => onOriginWarehouseChanged(
                      values.isEmpty ? null : values.first,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                field(
                  AppMultiSelectField<String>(
                    fieldLabel: 'Driver',
                    dialogTitle: 'Driver',
                    enabled: enabled,
                    singleSelect: true,
                    emptySelectionText: 'All drivers',
                    items: formData.drivers
                        .map(
                          (driver) => AppMultiSelectItem<String>(
                            value: driver.id,
                            label: driver.personName,
                            subtitle: driver.id,
                            searchText:
                                '${driver.personName} ${driver.id} ${driver.baseLocationName}',
                          ),
                        )
                        .toList(),
                    selectedValues: driverUserId == null
                        ? const {}
                        : {driverUserId!},
                    onChanged: (values) =>
                        onDriverChanged(values.isEmpty ? null : values.first),
                  ),
                ),
                field(
                  TextField(
                    controller: tripIdController,
                    enabled: enabled,
                    onChanged: (_) => onFilterEdited(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Trip ID',
                      hintText: 'Trip ID',
                    ),
                  ),
                ),
                field(
                  TextField(
                    controller: docIdController,
                    enabled: enabled,
                    onChanged: (_) => onFilterEdited(),
                    decoration: const InputDecoration(
                      labelText: 'Doc ID (Last 3 or more digits)',
                      hintText: 'Last 3 or more digits',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  const _DateFilterRow({
    required this.isWide,
    required this.fieldWidth,
    required this.fromDate,
    required this.toDate,
    required this.enabled,
    required this.onPickFromDate,
    required this.onPickToDate,
    required this.onClearDates,
  });

  final bool isWide;
  final double fieldWidth;
  final DateTime? fromDate;
  final DateTime? toDate;
  final bool enabled;
  final VoidCallback onPickFromDate;
  final VoidCallback onPickToDate;
  final VoidCallback onClearDates;

  Widget _clearDatesButton({required bool alignWithField}) {
    return Padding(
      padding: EdgeInsets.only(bottom: alignWithField ? 16 : 0),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: enabled ? onClearDates : null,
        child: const Text('Clear dates'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fromField = _DateField(
      label: 'From date',
      date: fromDate,
      enabled: enabled,
      onTap: onPickFromDate,
    );
    final toField = _DateField(
      label: 'To date',
      date: toDate,
      enabled: enabled,
      onTap: onPickToDate,
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: fieldWidth, child: fromField),
          const SizedBox(width: 12),
          SizedBox(width: fieldWidth, child: toField),
          const SizedBox(width: 4),
          _clearDatesButton(alignWithField: true),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        fromField,
        const SizedBox(height: 12),
        toField,
        Align(
          alignment: Alignment.centerLeft,
          child: _clearDatesButton(alignWithField: false),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          hasDate ? formatDeliveryReportDocDate(date) : _noDateSelectedLabel,
          style: TextStyle(color: hasDate ? Colors.black : Colors.black54),
        ),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.isBusy,
    required this.loadingCount,
    required this.loadingData,
    required this.downloadingExcel,
    required this.onViewReport,
    required this.onDownloadExcel,
    required this.onReset,
  });

  final bool isBusy;
  final bool loadingCount;
  final bool loadingData;
  final bool downloadingExcel;
  final VoidCallback onViewReport;
  final VoidCallback onDownloadExcel;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final actionButtonStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: isBusy ? null : onViewReport,
              style: actionButtonStyle,
              icon: loadingCount || loadingData
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.table_chart_outlined, size: 20),
              label: Text(
                loadingCount || loadingData ? 'Loading...' : 'View report',
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: isBusy ? null : onDownloadExcel,
              style: actionButtonStyle,
              icon: downloadingExcel
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined, size: 20),
              label: Text(
                downloadingExcel ? 'Downloading...' : 'Download Excel',
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: isBusy ? null : onReset,
          child: const Text('Reset filters'),
        ),
      ],
    );
  }
}

enum _DeliveryReportStatusKind { noResults, tooManyForGrid, mobileOnly, loaded }

class _DeliveryReportStatus {
  const _DeliveryReportStatus({required this.kind, this.matchedCount});

  final _DeliveryReportStatusKind kind;
  final int? matchedCount;
}

class _DeliveryReportStatusBanner extends StatelessWidget {
  const _DeliveryReportStatusBanner({required this.status});

  final _DeliveryReportStatus status;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final accent = AppTheme.primaryGlyph(primary);
    final background = primary.withValues(alpha: 0.08);
    final matchedCount = status.matchedCount;

    final ({IconData icon, String title, String? subtitle})
    presentation = switch (status.kind) {
      _DeliveryReportStatusKind.noResults => (
        icon: Icons.search_off_outlined,
        title: 'No records found for the selected filters.',
        subtitle: null,
      ),
      _DeliveryReportStatusKind.tooManyForGrid => (
        icon: Icons.table_rows_outlined,
        title:
            '${formatDeliveryReportCount(matchedCount ?? 0)} records match. '
            'Too many to display on screen (limit '
            '${formatDeliveryReportCount(deliveryReportMaxOnScreenRows)}).',
        subtitle:
            'Add filters to narrow the result, or click Download Excel button above '
            'to export all matching records.',
      ),
      _DeliveryReportStatusKind.mobileOnly => (
        icon: Icons.phone_android_outlined,
        title: '${formatDeliveryReportCount(matchedCount ?? 0)} records match.',
        subtitle:
            'Click Download Excel button above to view results on this device.',
      ),
      _DeliveryReportStatusKind.loaded => (
        icon: Icons.check_circle_outline,
        title:
            '${formatDeliveryReportCount(matchedCount ?? 0)} records loaded.',
        subtitle: null,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.gradientPageSurfaceBorder(primary),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
        child: Row(
          crossAxisAlignment: presentation.subtitle == null
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                presentation.icon,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    presentation.title,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (presentation.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      presentation.subtitle!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

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
  String? _resultMessage;
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

    final cities = customers
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
    return validateDeliveryReportDateRange(
      fromDate: _fromDate,
      toDate: _toDate,
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
      _resultMessage = null;
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
          _resultMessage = 'No records found for the selected filters.';
        });
        return;
      }

      if (!allowGrid) {
        setState(() {
          _resultMessage =
              '$count records match. Download the Excel report to view results on this device.';
        });
        return;
      }

      if (count > deliveryReportMaxOnScreenRows) {
        setState(() {
          _resultMessage =
              '$count records match. Too many to display on screen (limit '
              '$deliveryReportMaxOnScreenRows). Add filters to narrow the result, '
              'or download the full Excel report.';
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
        _resultMessage = '${dataResponse.totalRecords} records loaded.';
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
            'This export may include $_matchedCount records and could take a '
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
      _matchedCount = null;
      _rows = const [];
      _resultMessage = null;
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
    setState(() {
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
    setState(() {
      _toDate = picked;
      if (_fromDate == null || _fromDate!.isAfter(picked)) {
        _fromDate = picked;
      }
    });
  }

  void _clearDates() {
    setState(() {
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
                onRetry: () => setState(() => _formDataFuture = _loadFormData()),
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final formData = snapshot.data ?? const _DeliveryReportFormData.empty();
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
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
                                    setState(() => _customerId = value),
                                onRouteChanged: (value) =>
                                    setState(() => _route = value),
                                onOriginWarehouseChanged: (value) =>
                                    setState(() => _originWarehouse = value),
                                onTripStartLocationChanged: (value) => setState(
                                  () => _tripStartLocation = value,
                                ),
                                onDriverChanged: (value) =>
                                    setState(() => _driverUserId = value),
                                onCitiesChanged: (values) => setState(() {
                                  _selectedCities
                                    ..clear()
                                    ..addAll(values);
                                }),
                              ),
                              const SizedBox(height: 16),
                              _ActionsRow(
                                isBusy: isBusy,
                                loadingCount: _loadingCount,
                                loadingData: _loadingData,
                                downloadingExcel: _downloadingExcel,
                                onViewReport: () =>
                                    _viewReport(allowGrid: isWide),
                                onDownloadExcel: _downloadExcel,
                                onReset: _resetFilters,
                              ),
                              if (_resultMessage != null) ...[
                                const SizedBox(height: 16),
                                AppSurface(
                                  child: Text(
                                    _resultMessage!,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              if (isWide &&
                                  _rows.isNotEmpty &&
                                  !_loadingData) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 520,
                                  child: DeliveryReportTable(
                                    rows: _rows,
                                    apiClient: widget.apiClient,
                                  ),
                                ),
                              ],
                              if (_loadingData) ...[
                                const SizedBox(height: 24),
                                const Center(child: CircularProgressIndicator()),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Document date'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              field(
                _DateField(
                  label: 'From date',
                  value: fromDate == null
                      ? 'Use server default'
                      : formatDeliveryReportDocDate(fromDate),
                  enabled: enabled,
                  onTap: onPickFromDate,
                ),
              ),
              field(
                _DateField(
                  label: 'To date',
                  value: toDate == null
                      ? 'Use server default'
                      : formatDeliveryReportDocDate(toDate),
                  enabled: enabled,
                  onTap: onPickToDate,
                ),
              ),
              TextButton(
                onPressed: enabled ? onClearDates : null,
                child: const Text('Clear dates'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Filters document date, not delivery timestamp. Maximum range is '
            '$deliveryReportMaxDateRangeDays days when both dates are set.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Location & routing'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              field(
                AppMultiSelectField<String>(
                  fieldLabel: 'Trip start location',
                  dialogTitle: 'Trip start location',
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
                  selectedValues:
                      originWarehouse == null ? const {} : {originWarehouse!},
                  onChanged: (values) => onOriginWarehouseChanged(
                    values.isEmpty ? null : values.first,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'People & customer'),
          const SizedBox(height: 8),
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
                  selectedValues:
                      customerId == null ? const {} : {customerId!},
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
                  selectedValues:
                      driverUserId == null ? const {} : {driverUserId!},
                  onChanged: (values) =>
                      onDriverChanged(values.isEmpty ? null : values.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: 'Document / trip'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              field(
                TextField(
                  controller: docIdController,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    labelText: 'Doc ID (partial search)',
                    hintText: 'Doc ID (partial search)',
                    helperText:
                        'Partial search. Without dates, use at least 3 characters for a wider lookup window.',
                  ),
                ),
              ),
              field(
                TextField(
                  controller: tripIdController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Trip ID',
                    hintText: 'Trip ID',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value,
          style: TextStyle(
            color: value.contains('default') ? Colors.black54 : Colors.black,
          ),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: isBusy ? null : onViewReport,
          icon: loadingCount || loadingData
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.table_chart_outlined),
          label: Text(loadingCount || loadingData ? 'Loading...' : 'View report'),
        ),
        OutlinedButton.icon(
          onPressed: isBusy ? null : onDownloadExcel,
          icon: downloadingExcel
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: Text(downloadingExcel ? 'Downloading...' : 'Download Excel'),
        ),
        TextButton(onPressed: isBusy ? null : onReset, child: const Text('Reset filters')),
      ],
    );
  }
}

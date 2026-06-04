import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/models.dart';
import '../../../core/models/web_portal_models.dart';
import '../web_portal_filter_dropdown.dart';
import '../delivery_report_filter_section.dart';
import '../web_portal_providers.dart';
import 'delivery_report_controller.dart';

/// Filter form — local state only; never watches report results.
class DeliveryReportFilters extends ConsumerStatefulWidget {
  const DeliveryReportFilters({super.key});

  @override
  ConsumerState<DeliveryReportFilters> createState() =>
      _DeliveryReportFiltersState();
}

class _DeliveryReportFiltersState extends ConsumerState<DeliveryReportFilters> {
  final _docIdController = TextEditingController();
  final _tripIdController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _customerId;
  final Set<String> _selectedCities = {};
  String? _originWarehouse;
  String? _route;
  String? _driverUserId;
  String? _tripStartLocation;

  List<WebPortalDropdownOption>? _customerOptions;
  List<WebPortalDropdownOption>? _driverOptions;
  List<String>? _cities;
  Object? _customersCacheKey;
  Object? _driversCacheKey;

  @override
  void initState() {
    super.initState();
    _docIdController.addListener(_rebuild);
    _tripIdController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _docIdController
      ..removeListener(_rebuild)
      ..dispose();
    _tripIdController
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  WebPortalDeliveryReportFilters _buildFilters() {
    return WebPortalDeliveryReportFilters(
      fromDate: _fromDate != null ? _formatApiDate(_fromDate!) : null,
      toDate: _toDate != null ? _formatApiDate(_toDate!) : null,
      docId: _docIdController.text.trim().isEmpty
          ? null
          : _docIdController.text.trim(),
      customerId: _customerId,
      customerCity:
          _selectedCities.isEmpty ? null : _selectedCities.join(','),
      originWarehouse: _originWarehouse,
      tripId: int.tryParse(_tripIdController.text.trim()),
      driverUserId: _driverUserId,
      route: _route,
      tripStartLocation: _tripStartLocation,
    );
  }

  String _formatApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String? _validateDates() {
    final hasFrom = _fromDate != null;
    final hasTo = _toDate != null;
    if (hasFrom && !hasTo) {
      return 'To Date is required when From Date is provided';
    }
    if (!hasFrom && hasTo) {
      return 'From Date is required when To Date is provided';
    }
    if (hasFrom && hasTo) {
      if (_fromDate!.isAfter(_toDate!)) {
        return 'From date cannot be after To date';
      }
      if (_toDate!.difference(_fromDate!).inDays > 30) {
        return 'Date range cannot exceed 30 days';
      }
    }
    return null;
  }

  void _search() {
    final err = _validateDates();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ref.read(deliveryReportControllerProvider.notifier).search(_buildFilters());
  }

  void _clear() {
    setState(() {
      _fromDate = null;
      _toDate = null;
      _docIdController.clear();
      _tripIdController.clear();
      _customerId = null;
      _selectedCities.clear();
      _originWarehouse = null;
      _route = null;
      _driverUserId = null;
      _tripStartLocation = null;
    });
    ref.read(deliveryReportControllerProvider.notifier).clear();
  }

  void _syncCustomerOptions(List<WebPortalLightweightCustomer> customers) {
    final key = customers.length;
    if (_customersCacheKey == key && _customerOptions != null) return;
    _customersCacheKey = key;
    _customerOptions = customers
        .map(
          (c) => WebPortalDropdownOption(
            id: c.id,
            label: '${c.firmName} (${c.id})',
          ),
        )
        .toList(growable: false);
    final citySet = <String>{};
    for (final c in customers) {
      if (c.city != null && c.city!.isNotEmpty) citySet.add(c.city!);
    }
    _cities = citySet.toList()..sort();
  }

  void _syncDriverOptions(List<Driver> drivers) {
    final key = drivers.length;
    if (_driversCacheKey == key && _driverOptions != null) return;
    _driversCacheKey = key;
    _driverOptions = drivers
        .where((d) => d.userId != null && d.userId!.isNotEmpty)
        .map(
          (d) => WebPortalDropdownOption(
            id: d.userId!,
            label: '${d.driverName} - ${d.baseLocationName}',
            bold: d.sameLocation == true,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(portalLightweightCustomersProvider).valueOrNull;
    final routes = ref.watch(portalRoutesProvider).valueOrNull ?? [];
    final warehouses =
        ref.watch(portalOriginWarehousesProvider).valueOrNull ?? [];
    final drivers = ref.watch(portalDriversProvider).valueOrNull?.drivers ?? [];
    final locations =
        ref.watch(portalBaseLocationsProvider).valueOrNull ?? [];

    if (customers != null) _syncCustomerOptions(customers);
    _syncDriverOptions(drivers);

    return DeliveryReportFilterSection(
      fromDate: _fromDate,
      toDate: _toDate,
      docIdController: _docIdController,
      tripIdController: _tripIdController,
      customerId: _customerId,
      selectedCities: _selectedCities,
      originWarehouse: _originWarehouse,
      route: _route,
      driverUserId: _driverUserId,
      tripStartLocation: _tripStartLocation,
      validationError: _validateDates(),
      customerOptions: _customerOptions ?? const [],
      cities: _cities ?? const [],
      originWarehouses: warehouses,
      routes: routes,
      driverOptions: _driverOptions ?? const [],
      baseLocations: locations,
      onFromDateChanged: (d) => setState(() => _fromDate = d),
      onToDateChanged: (d) => setState(() => _toDate = d),
      onCustomerChanged: (v) => setState(() => _customerId = v),
      onCitiesChanged: (v) => setState(() {
        _selectedCities
          ..clear()
          ..addAll(v);
      }),
      onOriginWarehouseChanged: (v) => setState(() => _originWarehouse = v),
      onRouteChanged: (v) => setState(() => _route = v),
      onDriverChanged: (v) => setState(() => _driverUserId = v),
      onTripStartLocationChanged: (v) =>
          setState(() => _tripStartLocation = v),
      onDocIdClear: () => setState(_docIdController.clear),
      onTripIdClear: () => setState(_tripIdController.clear),
      onSearch: _search,
      onClear: _clear,
    );
  }
}

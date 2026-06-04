import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../config/app_constants.dart';
import '../../core/api/api_client.dart';
import '../../core/models/web_portal_models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';
import 'web_portal_providers.dart';
import 'web_portal_utils.dart';

class WebPortalDeliveryReportScreen extends ConsumerStatefulWidget {
  const WebPortalDeliveryReportScreen({super.key});

  @override
  ConsumerState<WebPortalDeliveryReportScreen> createState() =>
      _WebPortalDeliveryReportScreenState();
}

class _WebPortalDeliveryReportScreenState
    extends ConsumerState<WebPortalDeliveryReportScreen> {
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

  @override
  void dispose() {
    _docIdController.dispose();
    _tripIdController.dispose();
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
    if (hasFrom && !hasTo) return 'To Date is required when From Date is provided';
    if (!hasFrom && hasTo) return 'From Date is required when To Date is provided';
    if (hasFrom && hasTo) {
      if (_fromDate!.isAfter(_toDate!)) {
        return 'From date cannot be after To date';
      }
      final days = _toDate!.difference(_fromDate!).inDays;
      if (days > 30) return 'Date range cannot exceed 30 days';
    }
    return null;
  }

  bool _show30DayNote(WebPortalDeliveryReportFilters f) {
    return f.fromDate == null &&
        f.toDate == null &&
        (f.docId == null || f.docId!.length < 3) &&
        f.customerId == null;
  }

  void _search() {
    final err = _validateDates();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ref.read(deliveryReportQueryProvider.notifier).state = _buildFilters();
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
    ref.read(deliveryReportQueryProvider.notifier).state = null;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _showSignature(String docId) async {
    try {
      final sig = await ref.read(apiClientProvider).getDocSignature(docId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Signature - $docId'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.memory(
                  base64Decode(sig.signature),
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                Text(
                  'Timestamp: ${WebPortalUtils.formatDateString(sig.lastUpdatedAt)}',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    }
  }

  void _exportCsv(List<WebPortalDeliveryReportItem> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Doc ID,Doc Date,Firm Name,Address,City,Status,Comment,Trip ID,Route,Trip Creator,Trip Creator Location,Driver,Vehicle,Origin Warehouse',
    );
    for (final row in rows) {
      String esc(String? v) {
        final s = v ?? '';
        if (s.contains(',') || s.contains('"')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      buffer.writeln([
        row.docId,
        WebPortalUtils.formatDateString(row.docDate),
        esc(row.firmName),
        esc(row.address),
        esc(row.city),
        WebPortalUtils.docStatusLabel(row.status),
        esc(row.comment),
        row.tripId,
        esc(row.route),
        esc(row.createdByPersonName),
        esc(row.createdByLocation),
        esc(row.driverName),
        esc(row.vehicleNbr),
        esc(row.originWarehouse),
      ].join(','));
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV Export'),
        content: SizedBox(
          height: 200,
          width: 400,
          child: SingleChildScrollView(child: SelectableText(buffer.toString())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(portalLightweightCustomersProvider);
    final routesAsync = ref.watch(portalRoutesProvider);
    final warehousesAsync = ref.watch(portalOriginWarehousesProvider);
    final driversAsync = ref.watch(portalDriversProvider);
    final locationsAsync = ref.watch(portalBaseLocationsProvider);
    final reportAsync = ref.watch(deliveryReportDataProvider);
    final query = ref.watch(deliveryReportQueryProvider);
    final dateError = _validateDates();

    final cities = customersAsync.maybeWhen(
      data: (list) {
        final set = <String>{};
        for (final c in list) {
          if (c.city != null && c.city!.isNotEmpty) set.add(c.city!);
        }
        return set.toList()..sort();
      },
      orElse: () => <String>[],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go(AppRoutes.workflowWebReports),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
              const SizedBox(width: 12),
              Text(
                'Delivery Report',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (dateError != null) ...[
                    const SizedBox(height: 8),
                    Text(dateError, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: () => _pickDate(isFrom: true),
                        child: Text(
                          _fromDate == null
                              ? 'From Date'
                              : DateFormat('dd MMM yyyy').format(_fromDate!),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _pickDate(isFrom: false),
                        child: Text(
                          _toDate == null
                              ? 'To Date'
                              : DateFormat('dd MMM yyyy').format(_toDate!),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _docIdController,
                          decoration: const InputDecoration(
                            labelText: 'Doc ID',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: customersAsync.when(
                          data: (customers) => DropdownButtonFormField<String>(
                            value: _customerId,
                            decoration: const InputDecoration(
                              labelText: 'Customer',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: customers
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      '${c.firmName} (${c.id})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _customerId = v),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Customers unavailable'),
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Customer City',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: cities
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              if (_selectedCities.contains(v)) {
                                _selectedCities.remove(v);
                              } else {
                                _selectedCities.add(v);
                              }
                            });
                          },
                        ),
                      ),
                      if (_selectedCities.isNotEmpty)
                        Text('${_selectedCities.length} cities selected'),
                      warehousesAsync.when(
                        data: (w) => SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            value: _originWarehouse,
                            decoration: const InputDecoration(
                              labelText: 'Origin Warehouse',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: w
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _originWarehouse = v),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      routesAsync.when(
                        data: (routes) => SizedBox(
                          width: 140,
                          child: DropdownButtonFormField<String>(
                            value: _route,
                            decoration: const InputDecoration(
                              labelText: 'Route',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: routes
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _route = v),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _tripIdController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Trip ID',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      driversAsync.when(
                        data: (resp) => SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            value: _driverUserId,
                            decoration: const InputDecoration(
                              labelText: 'Driver',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: (resp.drivers ?? [])
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d.userId,
                                    child: Text(
                                      '${d.driverName} - ${d.baseLocationName}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _driverUserId = v),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      locationsAsync.when(
                        data: (locs) => SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            value: _tripStartLocation,
                            decoration: const InputDecoration(
                              labelText: 'Trip Originated From',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: locs
                                .map(
                                  (l) => DropdownMenuItem(
                                    value: l.id,
                                    child: Text(l.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _tripStartLocation = v),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      FilledButton.icon(
                        onPressed: dateError != null ? null : _search,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (query == null)
            const EmptyState(message: 'Set filters and tap Search to load data.')
          else
            reportAsync.when(
              loading: () => const LoadingOverlay(message: 'Loading report...'),
              error: (e, _) => ErrorView(message: e.toString()),
              data: (report) {
                if (report == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Results: ${report.totalRecords} records',
                            style: Theme.of(context).textTheme.titleMedium),
                        if (_show30DayNote(query)) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(last 30 days only)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const Spacer(),
                        if (report.data.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () => _exportCsv(report.data),
                            icon: const Icon(Icons.download),
                            label: const Text('Export CSV'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (report.data.isEmpty)
                      const EmptyState(message: 'No records found.')
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Doc ID')),
                            DataColumn(label: Text('Doc Date')),
                            DataColumn(label: Text('Customer')),
                            DataColumn(label: Text('City')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Comment')),
                            DataColumn(label: Text('Trip')),
                            DataColumn(label: Text('Route')),
                            DataColumn(label: Text('Driver')),
                            DataColumn(label: Text('Vehicle')),
                            DataColumn(label: Text('Warehouse')),
                          ],
                          rows: report.data.map((row) {
                            return DataRow(
                              cells: [
                                DataCell(Text(row.docId)),
                                DataCell(
                                  Text(WebPortalUtils.formatDateString(row.docDate)),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        row.firmName ?? '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (row.address != null)
                                        Text(
                                          row.address!,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(row.city ?? '-')),
                                DataCell(
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Chip(
                                        label: Text(
                                          WebPortalUtils.docStatusLabel(row.status),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor:
                                            row.status == AppConstants.docStatusDelivered
                                                ? Colors.green.shade100
                                                : Colors.red.shade100,
                                      ),
                                      if (row.status ==
                                          AppConstants.docStatusDelivered)
                                        TextButton(
                                          onPressed: () => _showSignature(row.docId),
                                          child: const Text('View Signature'),
                                        ),
                                      if (row.status ==
                                          AppConstants.docStatusUndelivered)
                                        TextButton(
                                          onPressed: () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text('Comment - ${row.docId}'),
                                                content: Text(row.comment ?? 'No comment'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('Close'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: const Text('View Comment'),
                                        ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(row.comment ?? '')),
                                DataCell(Text('${row.tripId}')),
                                DataCell(Text(row.route ?? '-')),
                                DataCell(Text(row.driverName ?? '-')),
                                DataCell(Text(row.vehicleNbr ?? '-')),
                                DataCell(Text(row.originWarehouse ?? '-')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

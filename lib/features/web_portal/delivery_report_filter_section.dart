import 'package:flutter/material.dart';

import '../../core/models/web_portal_models.dart';
import 'web_portal_date_field.dart';
import 'web_portal_filter_dropdown.dart';
import 'web_portal_filter_text_field.dart';
import 'web_portal_styles.dart';

/// MUI filter grid for Delivery Report — fixed columns via [Table] (stable on web).
class DeliveryReportFilterSection extends StatelessWidget {
  const DeliveryReportFilterSection({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.docIdController,
    required this.tripIdController,
    required this.customerId,
    required this.selectedCities,
    required this.originWarehouse,
    required this.route,
    required this.driverUserId,
    required this.tripStartLocation,
    required this.validationError,
    required this.customerOptions,
    required this.cities,
    required this.originWarehouses,
    required this.routes,
    required this.driverOptions,
    required this.baseLocations,
    required this.onFromDateChanged,
    required this.onToDateChanged,
    required this.onCustomerChanged,
    required this.onCitiesChanged,
    required this.onOriginWarehouseChanged,
    required this.onRouteChanged,
    required this.onDriverChanged,
    required this.onTripStartLocationChanged,
    required this.onDocIdClear,
    required this.onTripIdClear,
    required this.onSearch,
    required this.onClear,
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final TextEditingController docIdController;
  final TextEditingController tripIdController;
  final String? customerId;
  final Set<String> selectedCities;
  final String? originWarehouse;
  final String? route;
  final String? driverUserId;
  final String? tripStartLocation;
  final String? validationError;
  final List<WebPortalDropdownOption> customerOptions;
  final List<String> cities;
  final List<String> originWarehouses;
  final List<String> routes;
  final List<WebPortalDropdownOption> driverOptions;
  final List<WebPortalBaseLocation> baseLocations;
  final ValueChanged<DateTime?> onFromDateChanged;
  final ValueChanged<DateTime?> onToDateChanged;
  final ValueChanged<String?> onCustomerChanged;
  final ValueChanged<Set<String>> onCitiesChanged;
  final ValueChanged<String?> onOriginWarehouseChanged;
  final ValueChanged<String?> onRouteChanged;
  final ValueChanged<String?> onDriverChanged;
  final ValueChanged<String?> onTripStartLocationChanged;
  final VoidCallback onDocIdClear;
  final VoidCallback onTripIdClear;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  static int _columnsForWidth(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 2;
    return 1;
  }

  List<WebPortalDropdownOption> get _locationOptions => [
        for (final l in baseLocations)
          WebPortalDropdownOption(id: l.id, label: l.name),
      ];

  @override
  Widget build(BuildContext context) {
    return WebPortalPaper(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Filters', style: WebPortalStyles.filterSectionTitle),
          if (validationError != null) ...[
            const SizedBox(height: 12),
            Material(
              color: WebPortalStyles.errorMain.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: WebPortalStyles.errorMain,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        validationError!,
                        style: const TextStyle(
                          color: WebPortalStyles.errorMain,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = _columnsForWidth(constraints.maxWidth);
              const gap = 12.0;
              final cellW = (constraints.maxWidth - gap * (cols - 1)) / cols;

              final columnWidths = <int, TableColumnWidth>{
                for (var i = 0; i < cols; i++) i: FixedColumnWidth(cellW),
              };

              Widget cell(Widget child) => SizedBox(
                    height: WebPortalStyles.filterFieldHeight,
                    width: cellW,
                    child: child,
                  );

              Widget padCell(Widget child) => Padding(
                    padding: EdgeInsets.only(
                      right: gap,
                      bottom: gap,
                    ),
                    child: cell(child),
                  );

              TableRow tableRow(List<Widget> fields) {
                final cells = <Widget>[];
                for (var i = 0; i < cols; i++) {
                  final isLastCol = i == cols - 1;
                  final field = i < fields.length ? fields[i] : const SizedBox.shrink();
                  final wrapped = isLastCol
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: gap),
                          child: cell(field),
                        )
                      : padCell(field);
                  cells.add(wrapped);
                }
                return TableRow(children: cells);
              }

              return Table(
                columnWidths: columnWidths,
                defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
                children: [
                  tableRow([
                    WebPortalDateField(
                      label: 'From Date',
                      value: fromDate,
                      max: toDate,
                      onChanged: onFromDateChanged,
                    ),
                    WebPortalDateField(
                      label: 'To Date',
                      value: toDate,
                      min: fromDate,
                      onChanged: onToDateChanged,
                    ),
                    WebPortalFilterTextField(
                      controller: docIdController,
                      label: 'Doc ID',
                      hint: 'Last 3 digits or more',
                      onCleared: onDocIdClear,
                    ),
                    WebPortalFilterDropdown(
                      label: 'Customer',
                      options: customerOptions,
                      selectedId: customerId,
                      onSelected: onCustomerChanged,
                    ),
                  ]),
                  tableRow([
                    WebPortalFilterDropdown.multi(
                      label: 'Customer City',
                      options: WebPortalDropdownOption.fromStrings(cities),
                      selectedIds: selectedCities,
                      onSelectionChanged: onCitiesChanged,
                    ),
                    WebPortalFilterDropdown(
                      label: 'Origin Warehouse',
                      options:
                          WebPortalDropdownOption.fromStrings(originWarehouses),
                      selectedId: originWarehouse,
                      onSelected: onOriginWarehouseChanged,
                    ),
                    WebPortalFilterDropdown(
                      label: 'Route',
                      options: WebPortalDropdownOption.fromStrings(routes),
                      selectedId: route,
                      onSelected: onRouteChanged,
                    ),
                    WebPortalFilterTextField(
                      controller: tripIdController,
                      label: 'Trip ID',
                      keyboardType: TextInputType.number,
                      onCleared: onTripIdClear,
                    ),
                  ]),
                  tableRow([
                    WebPortalFilterDropdown(
                      label: 'Driver',
                      options: driverOptions,
                      selectedId: driverUserId,
                      onSelected: onDriverChanged,
                    ),
                    WebPortalFilterDropdown(
                      label: 'Parent Trip Originated From',
                      options: _locationOptions,
                      selectedId: _locationOptions.any((o) => o.id == tripStartLocation)
                          ? tripStartLocation
                          : null,
                      onSelected: onTripStartLocationChanged,
                    ),
                    _actionButtons(),
                  ]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Search + Clear share one grid cell (React: `display:flex; gap: 8px`).
  Widget _actionButtons() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: WebPortalStyles.filterButtonHeight,
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: validationError != null ? null : onSearch,
                style: WebPortalStyles.filterGridFilledButton(),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Search'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onClear,
                style: WebPortalStyles.filterGridOutlinedButton(),
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

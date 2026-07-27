import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../utils/download_file.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_view_details_button.dart';
import 'customer_detail_screen.dart';
import 'customer_models.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  late Future<_CustomersData> _dataFuture;
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Future<_CustomersData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getCustomersLightweight(),
      _loadHasWebAccess(),
    ]);

    return _CustomersData(
      customers: results[0] as List<CustomerSummary>,
      hasWebAccess: results[1] as bool,
    );
  }

  Future<bool> _loadHasWebAccess() => JwtPayload.currentUserHasWebAccess();

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _viewCustomer(CustomerSummary customer) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(
          apiClient: widget.apiClient,
          customerId: customer.id,
          onLoginAgain: widget.onLoginAgain,
        ),
      ),
    );
  }

  Future<void> _downloadCustomers() async {
    setState(() => _isDownloading = true);
    try {
      final customers = await widget.apiClient.getCustomersFull();
      final fileName =
          'mpc-pharma-customers-${DateTime.now().millisecondsSinceEpoch}.csv';
      await downloadFile(
        fileName: fileName,
        bytes: utf8.encode(_customersToCsv(customers)),
        mimeType: 'text/csv;charset=utf-8',
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  String _customersToCsv(List<Customer> customers) {
    final rows = <List<String>>[
      [
        'ID',
        'Firm Name',
        'Address',
        'City',
        'Pincode',
        'Phone',
        'Latitude',
        'Longitude',
        'Created At',
        'Last Updated At',
      ],
      ...customers.map(
        (customer) => [
          customer.id,
          customer.firmName,
          customer.address,
          customer.city,
          customer.pincode,
          customer.phone,
          customer.geoLatitude,
          customer.geoLongitude,
          customer.createdAt?.toUtc().toIso8601String() ?? '',
          customer.lastUpdatedAt?.toUtc().toIso8601String() ?? '',
        ],
      ),
    ];

    return rows.map((row) => row.map(_csvCell).join(',')).join('\n');
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_CustomersData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Failed to load Customers',
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final data = snapshot.data ?? _CustomersData.empty();
            final filteredCustomers = data.customers
                .where((customer) => customer.matchesSearch(_searchQuery))
                .toList();

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchAndActions(
                        controller: _searchController,
                        shownCount: filteredCustomers.length,
                        totalCount: data.customers.length,
                        isDownloading: _isDownloading,
                        onDownloadCustomers: _downloadCustomers,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _CustomersSection(
                          customers: filteredCustomers,
                          canViewDetails: data.hasWebAccess,
                          onViewCustomer: _viewCustomer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SearchAndActions extends StatelessWidget {
  const _SearchAndActions({
    required this.controller,
    required this.shownCount,
    required this.totalCount,
    required this.isDownloading,
    required this.onDownloadCustomers,
  });

  final TextEditingController controller;
  final int shownCount;
  final int totalCount;
  final bool isDownloading;
  final VoidCallback onDownloadCustomers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CustomersCountText(shownCount: shownCount, totalCount: totalCount),
        const SizedBox(height: 8),
        AppSearchField(
          controller: controller,
          labelText: 'Search customers',
          hintText: 'ID, firm name, city...',
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: isDownloading ? null : onDownloadCustomers,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Download'),
          ),
        ),
      ],
    );
  }
}

class _CustomersCountText extends StatelessWidget {
  const _CustomersCountText({
    required this.shownCount,
    required this.totalCount,
  });

  final int shownCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$shownCount of $totalCount customers',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CustomersSection extends StatefulWidget {
  const _CustomersSection({
    required this.customers,
    required this.canViewDetails,
    required this.onViewCustomer,
  });

  final List<CustomerSummary> customers;
  final bool canViewDetails;
  final ValueChanged<CustomerSummary> onViewCustomer;

  @override
  State<_CustomersSection> createState() => _CustomersSectionState();
}

class _CustomersSectionState extends State<_CustomersSection> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.customers.isEmpty) {
      return const _EmptyState(message: 'No customers match the search.');
    }

    return AppScrollbar(
      controller: _scrollController,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(right: 20),
        itemExtent: 120,
        cacheExtent: 600,
        itemCount: widget.customers.length,
        itemBuilder: (context, index) {
          final customer = widget.customers[index];
          return _CustomerListItem(
            key: ValueKey(customer.id),
            customer: customer,
            canViewDetails: widget.canViewDetails,
            onViewMore: () => widget.onViewCustomer(customer),
          );
        },
      ),
    );
  }
}

class _CustomerListItem extends StatelessWidget {
  const _CustomerListItem({
    super.key,
    required this.customer,
    required this.canViewDetails,
    required this.onViewMore,
  });

  final CustomerSummary customer;
  final bool canViewDetails;
  final VoidCallback onViewMore;

  @override
  Widget build(BuildContext context) {
    final city = customer.city.trim();

    return SizedBox(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AppSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        customer.firmName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (city.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (canViewDetails) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppViewDetailsButton(onPressed: onViewMore),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}


class _CustomersData {
  const _CustomersData({
    required this.customers,
    required this.hasWebAccess,
  });

  factory _CustomersData.empty() {
    return const _CustomersData(customers: [], hasWebAccess: false);
  }

  final List<CustomerSummary> customers;
  final bool hasWebAccess;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../auth/jwt_payload.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_scrollbar.dart';
import '../../widgets/app_surface.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../customers/customer_models.dart';
import '../users/user_models.dart';

enum _ImpersonateTarget { employee, customer }

class ImpersonateScreen extends StatefulWidget {
  const ImpersonateScreen({
    super.key,
    required this.apiClient,
    required this.onSessionReplaced,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final VoidCallback onSessionReplaced;
  final Future<void> Function() onLoginAgain;

  @override
  State<ImpersonateScreen> createState() => _ImpersonateScreenState();
}

class _ImpersonateScreenState extends State<ImpersonateScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  late Future<_ImpersonateData> _dataFuture;
  Timer? _searchDebounce;
  String _searchQuery = '';
  _ImpersonateTarget _target = _ImpersonateTarget.employee;
  String? _impersonatingId;
  String? _currentUserId;
  bool _isVerifyingAccess = true;
  bool _canImpersonate = false;
  bool _isImpersonating = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _searchController.addListener(_handleSearchChange);
    _verifyAccess();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_handleSearchChange);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _verifyAccess() async {
    final results = await Future.wait([
      JwtPayload.canStartImpersonation(),
      JwtPayload.currentIsImpersonation(),
      JwtPayload.currentUserId(),
    ]);
    if (!mounted) return;
    setState(() {
      _canImpersonate = results[0] as bool;
      _isImpersonating = results[1] as bool;
      _currentUserId = results[2] as String?;
      _isVerifyingAccess = false;
    });
  }

  void _handleSearchChange() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _searchQuery = _searchController.text);
    });
  }

  Future<_ImpersonateData> _loadData() async {
    final results = await Future.wait([
      widget.apiClient.getUsers(),
      widget.apiClient.getCustomersLightweight(),
    ]);
    return _ImpersonateData(
      employees: results[0] as List<UserAccount>,
      customers: results[1] as List<CustomerSummary>,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _impersonateEmployee(UserAccount employee) async {
    if (_isCurrentUser(employee.id)) {
      _showSelfImpersonationError();
      return;
    }
    await _impersonate(
      title: employee.personName,
      subtitle: 'Employee ID ${employee.id}',
      employeeId: employee.id,
    );
  }

  Future<void> _impersonateCustomer(CustomerSummary customer) async {
    if (_isCurrentUser(customer.id)) {
      _showSelfImpersonationError();
      return;
    }
    await _impersonate(
      title: customer.firmName,
      subtitle: 'Customer ID ${customer.id}',
      customerId: customer.id,
    );
  }

  bool _isCurrentUser(String id) =>
      _currentUserId != null && _currentUserId == id;

  void _showSelfImpersonationError() {
    showAppSnackBar(
      context,
      message: 'You cannot simulate your own account.',
      type: AppSnackBarType.error,
    );
  }

  Future<void> _impersonate({
    required String title,
    required String subtitle,
    String? employeeId,
    String? customerId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Simulate user'),
        content: Text('Sign in as $title?\n$subtitle'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Simulate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _impersonatingId = employeeId ?? customerId);
    try {
      final response = await widget.apiClient.impersonate(
        employeeId: employeeId,
        customerId: customerId,
      );
      if (response.accessToken == null || response.accessToken!.isEmpty) {
        throw Exception(
          'Impersonation succeeded, but no access token was returned.',
        );
      }
      if (!mounted) return;
      widget.onSessionReplaced();
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _impersonatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(title: const Text('Simulate Other User')),
      body: SafeArea(
        child: _isVerifyingAccess
            ? const Center(child: CircularProgressIndicator())
            : _isImpersonating
            ? const _AlreadyImpersonating()
            : !_canImpersonate
            ? const _AccessDenied()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select an employee or customer to simulate their login session.',
                          style: TextStyle(color: Colors.black),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<_ImpersonateTarget>(
                          segments: const [
                            ButtonSegment(
                              value: _ImpersonateTarget.employee,
                              icon: Icon(Icons.badge_outlined),
                              label: Text('Employee'),
                            ),
                            ButtonSegment(
                              value: _ImpersonateTarget.customer,
                              icon: Icon(Icons.storefront_outlined),
                              label: Text('Customer'),
                            ),
                          ],
                          selected: {_target},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _target = selection.first;
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        AppSearchField(
                          controller: _searchController,
                          labelText: _target == _ImpersonateTarget.employee
                              ? 'Search employees'
                              : 'Search customers',
                          hintText: _target == _ImpersonateTarget.employee
                              ? 'Name, mobile, ID...'
                              : 'ID, firm name, city...',
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: FutureBuilder<_ImpersonateData>(
                            future: _dataFuture,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState !=
                                  ConnectionState.done) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return AppLoadErrorState(
                                  title: 'Failed to load people',
                                  message: snapshot.error.toString(),
                                  onRetry: _refresh,
                                  onLoginAgain: widget.onLoginAgain,
                                );
                              }

                              final data =
                                  snapshot.data ??
                                  const _ImpersonateData.empty();
                              if (_target == _ImpersonateTarget.employee) {
                                final employees = data.employees
                                    .where(
                                      (user) =>
                                          user.matchesSearch(_searchQuery),
                                    )
                                    .toList();
                                return _EmployeeList(
                                  employees: employees,
                                  scrollController: _scrollController,
                                  impersonatingId: _impersonatingId,
                                  currentUserId: _currentUserId,
                                  onImpersonate: _impersonateEmployee,
                                );
                              }

                              final customers = data.customers
                                  .where(
                                    (customer) =>
                                        customer.matchesSearch(_searchQuery),
                                  )
                                  .toList();
                              return _CustomerList(
                                customers: customers,
                                scrollController: _scrollController,
                                impersonatingId: _impersonatingId,
                                currentUserId: _currentUserId,
                                onImpersonate: _impersonateCustomer,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.scrollController,
    required this.impersonatingId,
    required this.currentUserId,
    required this.onImpersonate,
  });

  final List<UserAccount> employees;
  final ScrollController scrollController;
  final String? impersonatingId;
  final String? currentUserId;
  final ValueChanged<UserAccount> onImpersonate;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return const Center(
        child: Text(
          'No employees match the search.',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return AppScrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(right: 20),
        itemCount: employees.length,
        itemBuilder: (context, index) {
          final employee = employees[index];
          final isLoading = impersonatingId == employee.id;
          final isSelf = currentUserId != null && currentUserId == employee.id;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AppSurface(
              child: ListTile(
                title: Text(
                  employee.personName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${employee.id} · ${employee.mobile}',
                  style: const TextStyle(color: Colors.black),
                ),
                trailing: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: employee.isActive && !isSelf
                            ? () => onImpersonate(employee)
                            : null,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Simulate'),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({
    required this.customers,
    required this.scrollController,
    required this.impersonatingId,
    required this.currentUserId,
    required this.onImpersonate,
  });

  final List<CustomerSummary> customers;
  final ScrollController scrollController;
  final String? impersonatingId;
  final String? currentUserId;
  final ValueChanged<CustomerSummary> onImpersonate;

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Center(
        child: Text(
          'No customers match the search.',
          style: TextStyle(color: Colors.black),
        ),
      );
    }

    return AppScrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.only(right: 20),
        itemCount: customers.length,
        itemBuilder: (context, index) {
          final customer = customers[index];
          final isLoading = impersonatingId == customer.id;
          final isSelf = currentUserId != null && currentUserId == customer.id;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AppSurface(
              child: ListTile(
                title: Text(
                  customer.firmName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${customer.id} · ${customer.city}',
                  style: const TextStyle(color: Colors.black),
                ),
                trailing: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : FilledButton(
                        onPressed: !isSelf
                            ? () => onImpersonate(customer)
                            : null,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Simulate'),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImpersonateData {
  const _ImpersonateData({required this.employees, required this.customers});

  const _ImpersonateData.empty() : employees = const [], customers = const [];

  final List<UserAccount> employees;
  final List<CustomerSummary> customers;
}

class _AlreadyImpersonating extends StatelessWidget {
  const _AlreadyImpersonating();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Exit simulation mode before simulating another user.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Simulation is available only to employee admins.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import 'customer_models.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    super.key,
    required this.apiClient,
    required this.customerId,
    required this.onLoginAgain,
  });

  final ApiClient apiClient;
  final String customerId;
  final Future<void> Function() onLoginAgain;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final Future<Customer> _customerFuture;

  @override
  void initState() {
    super.initState();
    _customerFuture = widget.apiClient.getCustomer(id: widget.customerId);
  }

  void _refresh() {
    setState(() {
      _customerFuture = widget.apiClient.getCustomer(id: widget.customerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: SafeArea(
        child: FutureBuilder<Customer>(
          future: _customerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
                onLoginAgain: widget.onLoginAgain,
              );
            }

            final customer = snapshot.data;
            if (customer == null) {
              return const Center(
                child: Text(
                  'Customer not found.',
                  style: TextStyle(color: Colors.black),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            customer.firmName,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 20),
                          _InfoRow(label: 'Customer ID', value: customer.id),
                          _InfoRow(label: 'Address', value: customer.address),
                          _InfoRow(label: 'City', value: customer.city),
                          _InfoRow(label: 'Pincode', value: customer.pincode),
                          _InfoRow(label: 'Phone', value: customer.phone),
                          _InfoRow(
                            label: 'Latitude',
                            value: customer.geoLatitude,
                          ),
                          _InfoRow(
                            label: 'Longitude',
                            value: customer.geoLongitude,
                          ),
                          _InfoRow(
                            label: 'Created at',
                            value: _formatDateTime(customer.createdAt),
                          ),
                          _InfoRow(
                            label: 'Last updated at',
                            value: _formatDateTime(customer.lastUpdatedAt),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[local.month - 1];
    final hourOfPeriod = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$month ${local.day} $hourOfPeriod:$minute $period';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(displayValue, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onLoginAgain,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onLoginAgain;

  bool get _isAuthError {
    final normalized = message.toLowerCase();
    return normalized.contains('token') ||
        normalized.contains('expired') ||
        normalized.contains('unauthorized') ||
        normalized.contains('401') ||
        normalized.contains('403') ||
        normalized.contains('forbidden');
  }

  Future<void> _loginAgain(BuildContext context) async {
    await onLoginAgain();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Failed to load customer',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isAuthError
                        ? () => _loginAgain(context)
                        : onRetry,
                    child: Text(_isAuthError ? 'Login Again' : 'Retry'),
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

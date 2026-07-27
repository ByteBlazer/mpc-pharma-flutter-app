import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import '../../utils/open_maps_location.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_snack_bar.dart';
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
  late Future<Customer> _customerFuture;

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

  Future<void> _openCoordinatesInMaps(Customer customer) async {
    final latitude = customer.latitude;
    final longitude = customer.longitude;
    if (latitude == null || longitude == null) return;

    try {
      await openCoordinatesInMaps(
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(title: const Text('Customer')),
      body: SafeArea(
        child: FutureBuilder<Customer>(
          future: _customerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return AppLoadErrorState(
                title: 'Failed to load customer',
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
                          _CoordinatesRow(
                            customer: customer,
                            onOpenMaps: () => _openCoordinatesInMaps(customer),
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
}

class _CoordinatesRow extends StatelessWidget {
  const _CoordinatesRow({
    required this.customer,
    required this.onOpenMaps,
  });

  final Customer customer;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final linkColor = AppTheme.primaryAccentText(primary);
    final lat = customer.geoLatitude.trim();
    final lng = customer.geoLongitude.trim();
    final hasValues = lat.isNotEmpty || lng.isNotEmpty;
    final displayValue = !hasValues
        ? '—'
        : customer.hasCoordinates
        ? '$lat, $lng'
        : [lat, lng].where((part) => part.isNotEmpty).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 132,
            child: Text(
              'Coordinates',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: customer.hasCoordinates
                ? InkWell(
                    onTap: onOpenMaps,
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        color: linkColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: linkColor,
                      ),
                    ),
                  )
                : Text(
                    displayValue,
                    style: const TextStyle(color: Colors.black),
                  ),
          ),
        ],
      ),
    );
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

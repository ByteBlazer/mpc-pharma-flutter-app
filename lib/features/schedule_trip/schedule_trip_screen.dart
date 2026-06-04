import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/providers.dart';
import '../../core/widgets/common_widgets.dart';
import '../../routing/app_routes.dart';

class ScheduleTripScreen extends ConsumerStatefulWidget {
  const ScheduleTripScreen({
    super.key,
    required this.route,
    required this.userIds,
  });

  final String route;
  final List<String> userIds;

  @override
  ConsumerState<ScheduleTripScreen> createState() => _ScheduleTripScreenState();
}

class _ScheduleTripScreenState extends ConsumerState<ScheduleTripScreen> {
  List<Driver> _drivers = [];
  Driver? _selectedDriver;
  final _vehicleController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  @override
  void dispose() {
    _vehicleController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).getDriverList();
      setState(() {
        _drivers = response.drivers ?? [];
        _selectedDriver = _drivers.cast<Driver?>().firstWhere(
              (d) => d?.self == true,
              orElse: () => _drivers.isNotEmpty ? _drivers.first : null,
            );
        if (_selectedDriver?.vehicleNumber?.isNotEmpty == true) {
          _vehicleController.text = _selectedDriver!.vehicleNumber!;
        }
      });
    } on DioException catch (e) {
      setState(() => _error = ApiClient.parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final driver = _selectedDriver;
    if (driver?.userId == null) return;
    if (_vehicleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle number is required')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final response = await ref.read(apiClientProvider).scheduleNewTrip(
            ScheduleNewTripRequest(
              route: widget.route,
              userIds: widget.userIds,
              driverId: driver!.userId!,
              vehicleNbr: _vehicleController.text.trim(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message ?? 'Trip scheduled')),
        );
        context.go('${AppRoutes.home}?tab=trips');
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.parseError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.route} : New Trip'),
      ),
      body: _loading
          ? const LoadingOverlay()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _loadDrivers)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Select Driver',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._drivers.map(
                        (driver) => RadioListTile<Driver>(
                          value: driver,
                          groupValue: _selectedDriver,
                          onChanged: (value) {
                            setState(() {
                              _selectedDriver = value;
                              if (value?.vehicleNumber?.isNotEmpty == true) {
                                _vehicleController.text = value!.vehicleNumber!;
                              }
                            });
                          },
                          title: Text(driver.driverName ?? 'Unknown'),
                          subtitle: Text(
                            '${driver.baseLocationName ?? ''} • ${driver.vehicleNumber ?? ''}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _vehicleController,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Schedule Trip'),
                      ),
                    ],
                  ),
                ),
    );
  }
}

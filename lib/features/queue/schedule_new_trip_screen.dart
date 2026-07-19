import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_load_error_state.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/app_surface.dart';
import '../trips/trips_screen.dart';
import 'queue_models.dart';
import 'schedule_models.dart';

class ScheduleNewTripScreen extends StatefulWidget {
  const ScheduleNewTripScreen({
    super.key,
    required this.apiClient,
    required this.onLoginAgain,
    required this.route,
    required this.batches,
  });

  final ApiClient apiClient;
  final Future<void> Function() onLoginAgain;
  final String route;
  final List<ScheduleBatchSelection> batches;

  @override
  State<ScheduleNewTripScreen> createState() => _ScheduleNewTripScreenState();
}

class _ScheduleNewTripScreenState extends State<ScheduleNewTripScreen> {
  late Future<DriverListResponse> _future;
  TripDriver? _selectedDriver;
  final _vehicleController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _scheduling = false;

  @override
  void initState() {
    super.initState();
    _future = widget.apiClient.getDriverList();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim());
  }

  void _refresh() {
    setState(() {
      _selectedDriver = null;
      _vehicleController.clear();
      _searchController.clear();
      _searchQuery = '';
      _future = widget.apiClient.getDriverList();
    });
  }

  void _selectDriver(TripDriver driver) {
    setState(() {
      if (_selectedDriver?.userId == driver.userId) {
        _selectedDriver = null;
        _vehicleController.clear();
      } else {
        _selectedDriver = driver;
        _vehicleController.text = driver.vehicleNumber;
      }
    });
  }

  List<TripDriver> _filteredDrivers(List<TripDriver> drivers) {
    if (_searchQuery.isEmpty) return drivers;
    final q = _searchQuery.toLowerCase();
    return drivers.where((d) {
      return d.driverName.toLowerCase().contains(q) ||
          d.baseLocationName.toLowerCase().contains(q) ||
          d.vehicleNumber.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _scheduleTrip() async {
    final driver = _selectedDriver;
    if (driver == null || driver.userId.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Please select a driver',
        type: AppSnackBarType.warning,
      );
      return;
    }
    final vehicle = _vehicleController.text.trim();
    if (vehicle.isEmpty) {
      showAppSnackBar(
        context,
        message: 'Please enter vehicle number',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() => _scheduling = true);
    try {
      final userIds = widget.batches
          .map((b) => b.scannedByUserId)
          .where((id) => id.isNotEmpty)
          .toList();
      final result = await widget.apiClient.scheduleNewTrip(
        route: widget.route,
        userIds: userIds,
        driverId: driver.userId,
        vehicleNbr: vehicle,
      );
      if (!mounted) return;

      if (result.statusCode == 401 || result.statusCode == 403) {
        showAppSnackBar(
          context,
          message: result.displayMessage,
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }

      showAppSnackBar(
        context,
        message: result.displayMessage,
        type: result.success
            ? AppSnackBarType.success
            : AppSnackBarType.error,
      );

      if (!result.success) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => TripsScreen(
            apiClient: widget.apiClient,
            onLoginAgain: widget.onLoginAgain,
          ),
        ),
        (route) => route.isFirst,
      );
    } catch (error) {
      if (!mounted) return;
      if (isAuthErrorMessage(error)) {
        showAppSnackBar(
          context,
          message: error.toString(),
          type: AppSnackBarType.error,
        );
        await widget.onLoginAgain();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      }
      showAppSnackBar(
        context,
        message: error.toString(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _scheduling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleEmpty = _vehicleController.text.trim().isEmpty;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AppScreenScaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('${widget.route} : New Trip'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _scheduling ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DriverListResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return AppLoadErrorState(
              title: 'Could not load drivers',
              message: snapshot.error.toString(),
              onRetry: _refresh,
              onLoginAgain: widget.onLoginAgain,
            );
          }

          final response = snapshot.data!;
          final allDrivers = response.drivers;
          if (allDrivers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  response.message.isNotEmpty
                      ? response.message
                      : 'No data found',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          }

          final drivers = _filteredDrivers(allDrivers);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Select a driver for this trip',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSearchField(
                      controller: _searchController,
                      labelText: 'Search drivers',
                      hintText: 'Name, location, or vehicle',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: drivers.isEmpty
                    ? const Center(
                        child: Text(
                          'No data found',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        itemCount: drivers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final driver = drivers[index];
                          return _DriverCard(
                            driver: driver,
                            selected:
                                _selectedDriver?.userId == driver.userId,
                            onTap: _scheduling
                                ? null
                                : () => _selectDriver(driver),
                          );
                        },
                      ),
              ),
              if (_selectedDriver != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    keyboardInset > 0 ? 8 : 28,
                  ),
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _vehicleController,
                            enabled: !_scheduling,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: vehicleEmpty
                                  ? 'Enter Vehicle Number'
                                  : 'Vehicle Number',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _scheduling ? null : _scheduleTrip,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                            child: _scheduling
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Schedule Trip'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({
    required this.driver,
    required this.selected,
    required this.onTap,
  });

  final TripDriver driver;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bold = driver.sameLocation;
    final nameStyle = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
      fontSize: 15,
    );
    final metaStyle = TextStyle(
      color: Colors.black54,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: 13,
    );

    return AppSurface(
      borderRadius: 14,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (driver.baseLocationName.isNotEmpty)
                      Text(
                        driver.baseLocationName,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(driver.driverName, style: nameStyle),
                    if (driver.vehicleNumber.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(driver.vehicleNumber, style: metaStyle),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.black38,
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

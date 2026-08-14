import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../app_theme.dart';
import 'customer_models.dart';

/// Lets an app admin change a customer's complaint SLA (1–7 days).
Future<int?> showEditCustomerSlaDialog({
  required BuildContext context,
  required ApiClient apiClient,
  required String customerId,
  required String customerLabel,
  required int currentSlaHours,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) => _EditCustomerSlaDialog(
      apiClient: apiClient,
      customerId: customerId,
      customerLabel: customerLabel,
      currentSlaHours: currentSlaHours,
    ),
  );
}

class _EditCustomerSlaDialog extends StatefulWidget {
  const _EditCustomerSlaDialog({
    required this.apiClient,
    required this.customerId,
    required this.customerLabel,
    required this.currentSlaHours,
  });

  final ApiClient apiClient;
  final String customerId;
  final String customerLabel;
  final int currentSlaHours;

  @override
  State<_EditCustomerSlaDialog> createState() => _EditCustomerSlaDialogState();
}

class _EditCustomerSlaDialogState extends State<_EditCustomerSlaDialog> {
  late int _slaDays;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final days = (widget.currentSlaHours / CustomerSla.hoursPerDay).round();
    _slaDays = days.clamp(
      CustomerSla.dayOptions.first,
      CustomerSla.dayOptions.last,
    );
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final updated = await widget.apiClient.updateCustomerSla(
        customerId: widget.customerId,
        slaHours: CustomerSla.hoursFromDays(_slaDays),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated.slaHours);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.withCompactButtons(Theme.of(context)),
      child: AlertDialog(
        title: const Text('Edit SLA'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.customerLabel,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _slaDays,
                decoration: const InputDecoration(labelText: 'SLA'),
                items: [
                  for (final days in CustomerSla.dayOptions)
                    DropdownMenuItem(
                      value: days,
                      child: Text(CustomerSla.daysLabel(days)),
                    ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          _slaDays = value;
                          _errorMessage = null;
                        });
                      },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

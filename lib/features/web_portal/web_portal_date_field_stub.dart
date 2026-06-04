import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'web_portal_styles.dart';

/// Mobile/desktop fallback — Material date picker dialog.
class WebPortalDateField extends StatelessWidget {
  const WebPortalDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min,
    this.max,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final DateTime? min;
  final DateTime? max;

  static String formatDisplay(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd MMM yyyy').format(d);
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: min ?? DateTime(2020),
      lastDate: max ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final display = formatDisplay(value);
    final hasValue = value != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 40,
        width: double.infinity,
        child: InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: WebPortalStyles.muiOutlinedField(
              label: label,
              hint: 'Click to select date',
              prefixIcon: const Icon(Icons.calendar_today, size: 18),
              suffixIcon: hasValue
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onChanged(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    )
                  : null,
            ).copyWith(
              isCollapsed: true,
              constraints: const BoxConstraints(minHeight: 40, maxHeight: 40),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              display.isEmpty ? 'Click to select date' : display,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: display.isEmpty
                    ? WebPortalStyles.textSecondary
                    : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

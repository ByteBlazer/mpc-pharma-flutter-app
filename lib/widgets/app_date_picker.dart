import 'package:flutter/material.dart';

DateTime _clampDate(DateTime date, DateTime firstDate, DateTime lastDate) {
  if (date.isBefore(firstDate)) return firstDate;
  if (date.isAfter(lastDate)) return lastDate;
  return date;
}

/// Opens a calendar dialog that closes as soon as the user taps a date.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
}) {
  final selectedInitial = _clampDate(initialDate, firstDate, lastDate);

  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (helpText != null && helpText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    helpText,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              CalendarDatePicker(
                initialDate: selectedInitial,
                firstDate: firstDate,
                lastDate: lastDate,
                onDateChanged: (date) => Navigator.of(context).pop(date),
              ),
            ],
          ),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../leave_models.dart';

class LeaveStatusChip extends StatelessWidget {
  const LeaveStatusChip({super.key, required this.status});

  final LeaveStatus status;

  Color _color(BuildContext context) {
    return switch (status) {
      LeaveStatus.pending => const Color(0xFF1565C0),
      LeaveStatus.approved => const Color(0xFF2E7D32),
      LeaveStatus.rejected => const Color(0xFFC62828),
      LeaveStatus.withdrawn => Colors.black54,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          status.label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

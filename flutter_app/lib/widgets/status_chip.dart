import 'package:flutter/material.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  const StatusChip({super.key, required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppTheme.green : AppTheme.red;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (label.isNotEmpty) ...[
        Text(label, style: AppTheme.ui(size: 13, weight: FontWeight.w500)),
        const SizedBox(width: 8),
      ],
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            ok ? 'Active' : 'Error',
            style: AppTheme.ui(size: 10, weight: FontWeight.w600, color: color),
          ),
        ]),
      ),
    ]);
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const StatCard({super.key, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTheme.ui(size: 9, weight: FontWeight.w600, color: AppTheme.textMute, letterSpacing: 1.2)),
        const SizedBox(height: 6),
        Text(value,
            style: AppTheme.ui(size: 22, weight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final bool ok;
  const StatusChip({super.key, required this.label, required this.ok});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: ok ? AppTheme.green : AppTheme.red, shape: BoxShape.circle)),
      const SizedBox(width: 10),
      Text(label, style: GoogleFonts.dmMono(fontSize: 13, color: AppTheme.textPrim)),
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
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmMono(fontSize: 9, color: AppTheme.textMute, letterSpacing: 1.5)),
        Text(value, style: GoogleFonts.dmMono(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

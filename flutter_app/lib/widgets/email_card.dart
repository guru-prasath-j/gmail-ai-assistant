import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class EmailCard extends StatelessWidget {
  final Map<String, dynamic> email;
  final bool isGenerating;
  final bool hasReply;
  final VoidCallback onGenerateReply;
  final VoidCallback? onViewReply;
  const EmailCard({super.key, required this.email, required this.isGenerating, required this.hasReply, required this.onGenerateReply, this.onViewReply});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: hasReply ? AppTheme.green.withOpacity(0.3) : AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(email['subject'] ?? '(no subject)', style: GoogleFonts.dmMono(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrim), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(email['from'] ?? '', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textSec), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(email['snippet'] ?? '', style: GoogleFonts.dmMono(fontSize: 11, color: AppTheme.textMute), maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [
          const Spacer(),
          isGenerating ? Row(children: [const CircularProgressIndicator(strokeWidth: 2), Text('Generating...', style: GoogleFonts.dmMono(fontSize: 11))])
          : ElevatedButton.icon(icon: Icon(hasReply ? Icons.refresh_rounded : Icons.auto_awesome, size: 14), label: Text(hasReply ? 'Regenerate' : 'Generate Reply', style: GoogleFonts.dmMono(fontSize: 11)), onPressed: onGenerateReply),
        ])),
      ]),
    );
  }
}

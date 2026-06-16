import 'package:flutter/material.dart';
import '../theme.dart';

class EmailCard extends StatelessWidget {
  final Map<String, dynamic> email;
  final bool isGenerating;
  final bool hasReply;
  final VoidCallback onGenerateReply;
  final VoidCallback? onViewReply;

  const EmailCard({
    super.key,
    required this.email,
    required this.isGenerating,
    required this.hasReply,
    required this.onGenerateReply,
    this.onViewReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasReply ? AppTheme.green.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              email['subject'] ?? '(no subject)',
              style: AppTheme.ui(size: 13, weight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              email['from'] ?? '',
              style: AppTheme.ui(size: 11, color: AppTheme.textSec),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              email['snippet'] ?? '',
              style: AppTheme.mono(size: 11, color: AppTheme.textMute),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            const Spacer(),
            isGenerating
                ? Row(children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 8),
                    Text('Generating...', style: AppTheme.ui(size: 11, color: AppTheme.textSec)),
                  ])
                : ElevatedButton.icon(
                    icon: Icon(
                      hasReply ? Icons.refresh_rounded : Icons.auto_awesome,
                      size: 14,
                    ),
                    label: Text(
                      hasReply ? 'Regenerate' : 'Generate Reply',
                      style: AppTheme.ui(size: 11, weight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onGenerateReply,
                  ),
          ]),
        ),
      ]),
    );
  }
}

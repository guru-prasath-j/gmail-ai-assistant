import 'package:flutter/material.dart';
import '../theme.dart';

/// Non-web fallback: renders the plain-text body as selectable text.
class EmailBodyView extends StatelessWidget {
  final String htmlContent;
  final String plainText;
  final String emailId;

  const EmailBodyView({
    super.key,
    required this.htmlContent,
    required this.plainText,
    required this.emailId,
  });

  @override
  Widget build(BuildContext context) {
    final text = plainText.isNotEmpty ? plainText : htmlContent;
    return SelectableText(
      text,
      style: AppTheme.mono(size: 12.5, height: 1.6),
    );
  }
}

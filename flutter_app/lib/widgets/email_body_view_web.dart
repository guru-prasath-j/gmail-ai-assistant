// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import '../theme.dart';

/// Web implementation: renders the HTML email body inside a sandboxed iframe.
class EmailBodyView extends StatefulWidget {
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
  State<EmailBodyView> createState() => _EmailBodyViewState();
}

class _EmailBodyViewState extends State<EmailBodyView> {
  // Prevent duplicate factory registration across rebuilds
  static final Set<String> _registered = {};

  String get _viewId => 'email-iframe-${widget.emailId}';

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  void _registerView() {
    if (_registered.contains(_viewId)) return;
    _registered.add(_viewId);

    final src = widget.htmlContent.isNotEmpty
        ? _wrap(widget.htmlContent)
        : '<pre style="font-family:monospace;padding:8px;white-space:pre-wrap">'
            '${_escape(widget.plainText)}</pre>';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int id) {
      return html.IFrameElement()
        ..srcdoc = src
        ..setAttribute('sandbox', 'allow-same-origin allow-popups')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'auto';
    });
  }

  String _escape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _wrap(String body) => '''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body { margin: 0; padding: 14px 16px; background: #ffffff;
                 font-family: Arial, sans-serif; font-size: 14px; line-height: 1.5; }
    * { max-width: 100% !important; box-sizing: border-box; }
    img { max-width: 100% !important; height: auto !important; display: block; }
    a { color: #1a73e8; }
    table { width: 100% !important; }
  </style>
</head>
<body>$body</body>
</html>''';

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.58;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

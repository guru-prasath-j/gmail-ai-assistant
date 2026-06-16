// Conditional export: uses the iframe-based web implementation on web,
// and falls back to plain-text SelectableText on other platforms.
export 'email_body_view_stub.dart'
    if (dart.library.html) 'email_body_view_web.dart';

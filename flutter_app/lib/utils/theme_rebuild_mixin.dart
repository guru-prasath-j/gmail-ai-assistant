import 'package:flutter/material.dart';
import '../theme.dart';

/// Add `with ThemeRebuildMixin` to any [State] that uses [AppTheme] color
/// getters directly (e.g. `AppTheme.surface`, `AppTheme.textPrim`).
///
/// Without this, those values are captured once when the screen first builds
/// and don't update when the user toggles dark ↔ light mode, because the
/// Navigator keeps route states alive independently of the root widget rebuild.
mixin ThemeRebuildMixin<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }
}

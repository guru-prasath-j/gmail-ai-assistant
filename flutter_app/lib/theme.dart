import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Global theme controller ────────────────────────────────────────────────

/// Call [themeNotifier.toggle()] from anywhere to switch dark ↔ light.
final themeNotifier = _ThemeNotifier();

class _ThemeNotifier extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.dark;
  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}

// ── Color palette ──────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  // Gmail brand colors — identical in both modes
  static const Color accent = Color(0xFF1A73E8); // Google Blue
  static const Color green  = Color(0xFF34A853); // Google Green
  static const Color red    = Color(0xFFEA4335); // Gmail Red
  static const Color purple = Color(0xFF7C5CBF); // Accent purple

  // Dynamic colors — resolved at build time based on current mode
  static bool get _d => themeNotifier.isDark;

  static Color get bg       => _d ? const Color(0xFF0D1117) : const Color(0xFFF6F8FC);
  static Color get surface  => _d ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
  static Color get card     => _d ? const Color(0xFF1C2128) : const Color(0xFFF1F3F4);
  static Color get border   => _d ? const Color(0xFF30363D) : const Color(0xFFDFE1E5);
  static Color get textPrim => _d ? const Color(0xFFE6EDF3) : const Color(0xFF202124);
  static Color get textSec  => _d ? const Color(0xFF8B949E) : const Color(0xFF5F6368);
  static Color get textMute => _d ? const Color(0xFF484F58) : const Color(0xFF9AA0A6);

  // ── Font helpers ─────────────────────────────────────────────────────────

  /// Inter — all UI chrome: labels, headings, buttons, metadata.
  static TextStyle ui({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrim,
        height: height,
        letterSpacing: letterSpacing,
      );

  /// DM Mono — email body text, reply content, code-like values.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) =>
      GoogleFonts.dmMono(
        fontSize: size,
        fontWeight: weight,
        color: color ?? textPrim,
        height: height,
      );

  // ── ThemeData ─────────────────────────────────────────────────────────────

  static ThemeData get dark  => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final d = brightness == Brightness.dark;

    final bgC       = d ? const Color(0xFF0D1117) : const Color(0xFFF6F8FC);
    final surfaceC  = d ? const Color(0xFF161B22) : const Color(0xFFFFFFFF);
    final borderC   = d ? const Color(0xFF30363D) : const Color(0xFFDFE1E5);
    final textPrimC = d ? const Color(0xFFE6EDF3) : const Color(0xFF202124);
    final textSecC  = d ? const Color(0xFF8B949E) : const Color(0xFF5F6368);
    final textMuteC = d ? const Color(0xFF484F58) : const Color(0xFF9AA0A6);
    final inputFill = d ? const Color(0xFF1C2128) : const Color(0xFFF1F3F4);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bgC,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: Colors.white,
        secondary: green,
        onSecondary: Colors.white,
        error: red,
        onError: Colors.white,
        surface: surfaceC,
        onSurface: textPrimC,
        outline: borderC,
      ),
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          displayLarge: TextStyle(color: textPrimC, fontWeight: FontWeight.w700),
          bodyLarge:    TextStyle(color: textPrimC),
          bodyMedium:   TextStyle(color: textSecC),
          labelSmall:   TextStyle(color: textMuteC, letterSpacing: 0.8),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgC,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimC, fontSize: 16, fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textSecC),
      ),
      cardTheme: CardThemeData(
        color: surfaceC,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: borderC),
        ),
      ),
      dividerColor: borderC,
      tabBarTheme: TabBarThemeData(
        indicatorColor: accent,
        labelColor: textPrimC,
        unselectedLabelColor: textMuteC,
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderC),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderC),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecC, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: textMuteC, fontSize: 14),
      ),
    );
  }
}

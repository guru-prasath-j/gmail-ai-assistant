import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg       = Color(0xFF08080F);
  static const Color surface  = Color(0xFF12121F);
  static const Color card     = Color(0xFF1A1A2E);
  static const Color border   = Color(0xFF222233);
  static const Color accent   = Color(0xFFFF6B35);
  static const Color green    = Color(0xFF00D084);
  static const Color red      = Color(0xFFE53E3E);
  static const Color purple   = Color(0xFF7C5CBF);
  static const Color textPrim = Color(0xFFE0E0E0);
  static const Color textSec  = Color(0xFF888899);
  static const Color textMute = Color(0xFF444455);

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent,
      secondary: green,
      surface: surface,
      error: red,
    ),
    textTheme: GoogleFonts.dmMonoTextTheme(
      const TextTheme(
        displayLarge: TextStyle(color: textPrim, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrim),
        bodyMedium: TextStyle(color: textSec),
        labelSmall: TextStyle(color: textMute, letterSpacing: 1.2),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      titleTextStyle: GoogleFonts.dmMono(
        color: textPrim, fontSize: 16, fontWeight: FontWeight.w700,
      ),
      iconTheme: const IconThemeData(color: textSec),
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: border),
      ),
    ),
    dividerColor: border,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: accent),
      ),
      labelStyle: const TextStyle(color: textSec),
      hintStyle: const TextStyle(color: textMute),
    ),
  );
}

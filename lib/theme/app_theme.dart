import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // AM Logistics Brand Colors
  static const Color brandNavy = Color(0xFF0A1628);
  static const Color brandNavyLight = Color(0xFF1A2E4A);
  static const Color brandAccent = Color(0xFFE8500A); // AM Logistics orange
  static const Color brandAccentLight = Color(0xFFFFF0EA);
  static const Color brandAccentStrong = Color(0xFFD44008);

  // Status colors
  static const Color success = Color(0xFF16A34A);
  static const Color successMuted = Color(0xFFDCFCE7);
  static const Color successStrong = Color(0xFF15803D);
  static const Color warning = Color(0xFFD97706);
  static const Color warningMuted = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorMuted = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoMuted = Color(0xFFDBEAFE);

  // Light surfaces
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F4F8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Text
  static const Color textPrimary = Color(0xFF0A1628);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Dark surfaces (kept for darkTheme requirement)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: brandNavy,
      onPrimary: textOnDark,
      primaryContainer: Color(0xFFE8EDF5),
      onPrimaryContainer: brandNavy,
      secondary: brandAccent,
      onSecondary: textOnDark,
      surface: surface,
      onSurface: textPrimary,
      error: error,
      onError: Colors.white,
      outline: border,
      outlineVariant: Color(0xFFF1F4F8),
    ),
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.manropeTextTheme(ThemeData.light().textTheme),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1, space: 0),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandNavy,
        foregroundColor: textOnDark,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandNavy,
        minimumSize: const Size(double.infinity, 56),
        side: const BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: brandAccent,
      onPrimary: textOnDark,
      surface: surfaceDark,
      onSurface: textOnDark,
      error: error,
      onError: Colors.white,
      outline: borderDark,
    ),
    scaffoldBackgroundColor: backgroundDark,
    textTheme: GoogleFonts.manropeTextTheme(
      ThemeData.dark().textTheme.apply(
        bodyColor: textOnDark,
        displayColor: textOnDark,
      ),
    ),
    appBarTheme: const AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(
      color: borderDark,
      thickness: 1,
      space: 0,
    ),
  );
}

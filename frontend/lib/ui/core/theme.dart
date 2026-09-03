import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand Colors (Standard Dark)
const Color _bgDark = Color(0xFF0D0F14);
const Color _surfaceDark = Color(0xFF161A22);
const Color _primaryGreen = Color(0xFF00E676);
const Color _secondaryOrange = Color(0xFFFF6D00);
const Color _textPrimaryDark = Color(0xFFFFFFFF);
const Color _textSecondaryDark = Color(0xFF8A94A6);

// Ramadan Theme Colors (Celestial Midnight Blue & Gold)
class RamadanColors {
  static const Color bgMidnight = Color(0xFF080D1A);
  static const Color bgDark = Color(0xFF050811);
  static const Color surfaceDark = Color(0xFF0E172A);
  static const Color surfaceLight = Color(0xFF16233B);
  static const Color surfaceElevated = Color(0xFF1E2F4D);
  static const Color primaryCyan = Color(0xFF00D2FF);
  static const Color primaryBlue = Color(0xFF38BDF8);
  static const Color accentGold = Color(0xFFFFD166);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textGold = Color(0xFFFFE082);
}

TextTheme _buildUrduTextTheme([Color? textColor, Color? secondaryColor]) {
  final color = textColor ?? Colors.white;
  final secColor = secondaryColor ?? const Color(0xFF8A94A6);
  const fallback = ['JameelNooriNastaleeq'];
  return TextTheme(
    displayLarge: TextStyle(fontFamilyFallback: fallback, color: color),
    displayMedium: TextStyle(fontFamilyFallback: fallback, color: color),
    displaySmall: TextStyle(fontFamilyFallback: fallback, color: color),
    headlineLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.bold, fontSize: 34, color: color),
    headlineMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600, fontSize: 30, color: color),
    headlineSmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600, fontSize: 26, color: color),
    titleLarge: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w600, fontSize: 24, color: color),
    titleMedium: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w500, fontSize: 18, color: color),
    titleSmall: TextStyle(fontFamilyFallback: fallback, fontWeight: FontWeight.w500, fontSize: 16, color: color),
    bodyLarge: TextStyle(fontFamilyFallback: fallback, fontSize: 18, color: color),
    bodyMedium: TextStyle(fontFamilyFallback: fallback, fontSize: 18, color: secColor),
    bodySmall: TextStyle(fontFamilyFallback: fallback, fontSize: 18, color: secColor),
    labelLarge: TextStyle(fontFamilyFallback: fallback, fontSize: 18, color: color),
    labelMedium: TextStyle(fontFamilyFallback: fallback, fontSize: 14, color: secColor),
    labelSmall: TextStyle(fontFamilyFallback: fallback, fontSize: 12, color: secColor),
  );
}

ThemeData buildLightTheme(bool isUrdu) {
  final fallbackFonts = isUrdu ? const ['JameelNooriNastaleeq'] : const <String>[];
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
    fontFamilyFallback: fallbackFonts,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      primary: _primaryGreen,
      secondary: _secondaryOrange,
    ),
    textTheme: isUrdu
        ? _buildUrduTextTheme(Colors.black, Colors.black87)
        : GoogleFonts.interTextTheme().copyWith(
            bodyLarge: GoogleFonts.inter().copyWith(fontFamilyFallback: fallbackFonts),
            bodyMedium: GoogleFonts.inter().copyWith(fontFamilyFallback: fallbackFonts),
            bodySmall: GoogleFonts.inter().copyWith(fontFamilyFallback: fallbackFonts),
            headlineLarge: GoogleFonts.outfit().copyWith(fontFamilyFallback: fallbackFonts),
            headlineMedium: GoogleFonts.outfit().copyWith(fontFamilyFallback: fallbackFonts),
            headlineSmall: GoogleFonts.outfit().copyWith(fontFamilyFallback: fallbackFonts),
            titleLarge: GoogleFonts.outfit().copyWith(fontFamilyFallback: fallbackFonts),
            titleMedium: GoogleFonts.outfit().copyWith(fontFamilyFallback: fallbackFonts),
          ),
  );
}

ThemeData buildDarkTheme(bool isUrdu) {
  final fallbackFonts = isUrdu ? const ['JameelNooriNastaleeq'] : const <String>[];
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
    fontFamilyFallback: fallbackFonts,
    scaffoldBackgroundColor: _bgDark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryGreen,
      secondary: _secondaryOrange,
      surface: _surfaceDark,
      onSurface: _textPrimaryDark,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    textTheme: isUrdu
        ? _buildUrduTextTheme(_textPrimaryDark, _textSecondaryDark)
        : GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme).copyWith(
            headlineLarge: GoogleFonts.outfit(color: _textPrimaryDark, fontWeight: FontWeight.bold).copyWith(fontFamilyFallback: fallbackFonts),
            headlineMedium: GoogleFonts.outfit(color: _textPrimaryDark, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            headlineSmall: GoogleFonts.outfit(color: _textPrimaryDark, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            titleLarge: GoogleFonts.outfit(color: _textPrimaryDark, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            titleMedium: GoogleFonts.outfit(color: _textPrimaryDark, fontWeight: FontWeight.w500).copyWith(fontFamilyFallback: fallbackFonts),
            bodyLarge: GoogleFonts.inter(color: _textPrimaryDark).copyWith(fontFamilyFallback: fallbackFonts),
            bodyMedium: GoogleFonts.inter(color: _textSecondaryDark).copyWith(fontFamilyFallback: fallbackFonts),
            bodySmall: GoogleFonts.inter(color: _textSecondaryDark).copyWith(fontFamilyFallback: fallbackFonts),
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: _bgDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: isUrdu
          ? const TextStyle(color: _textPrimaryDark, fontSize: 22, fontWeight: FontWeight.w600, fontFamily: 'JameelNooriNastaleeq')
          : GoogleFonts.outfit(
              color: _textPrimaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ).copyWith(fontFamilyFallback: fallbackFonts),
      iconTheme: const IconThemeData(color: _textPrimaryDark),
    ),
  );
}

/// Specialized Ramadan Midnight Blue Theme
ThemeData buildRamadanTheme(bool isUrdu) {
  final fallbackFonts = isUrdu ? const ['JameelNooriNastaleeq'] : const <String>[];
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: isUrdu ? 'JameelNooriNastaleeq' : null,
    fontFamilyFallback: fallbackFonts,
    scaffoldBackgroundColor: RamadanColors.bgMidnight,
    colorScheme: const ColorScheme.dark(
      primary: RamadanColors.primaryCyan,
      secondary: RamadanColors.accentGold,
      surface: RamadanColors.surfaceDark,
      onSurface: RamadanColors.textPrimary,
      surfaceContainerHighest: RamadanColors.surfaceLight,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: RamadanColors.surfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x2238BDF8), width: 1),
      ),
    ),
    textTheme: isUrdu
        ? _buildUrduTextTheme(RamadanColors.textPrimary, RamadanColors.textSecondary)
        : GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme).copyWith(
            headlineLarge: GoogleFonts.outfit(color: RamadanColors.textPrimary, fontWeight: FontWeight.bold).copyWith(fontFamilyFallback: fallbackFonts),
            headlineMedium: GoogleFonts.outfit(color: RamadanColors.textPrimary, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            headlineSmall: GoogleFonts.outfit(color: RamadanColors.textPrimary, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            titleLarge: GoogleFonts.outfit(color: RamadanColors.textPrimary, fontWeight: FontWeight.w600).copyWith(fontFamilyFallback: fallbackFonts),
            titleMedium: GoogleFonts.outfit(color: RamadanColors.textPrimary, fontWeight: FontWeight.w500).copyWith(fontFamilyFallback: fallbackFonts),
            bodyLarge: GoogleFonts.inter(color: RamadanColors.textPrimary).copyWith(fontFamilyFallback: fallbackFonts),
            bodyMedium: GoogleFonts.inter(color: RamadanColors.textSecondary).copyWith(fontFamilyFallback: fallbackFonts),
            bodySmall: GoogleFonts.inter(color: RamadanColors.textSecondary).copyWith(fontFamilyFallback: fallbackFonts),
          ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: isUrdu
          ? const TextStyle(color: RamadanColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600, fontFamily: 'JameelNooriNastaleeq')
          : GoogleFonts.outfit(
              color: RamadanColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ).copyWith(fontFamilyFallback: fallbackFonts),
      iconTheme: const IconThemeData(color: RamadanColors.textPrimary),
    ),
  );
}

/// Helper for screen background radial gradients
Decoration getAppBackgroundDecoration(bool isRamadan) {
  if (isRamadan) {
    return const BoxDecoration(
      color: RamadanColors.bgMidnight,
      gradient: RadialGradient(
        center: Alignment(0, -0.75),
        radius: 1.35,
        colors: [
          Color(0xFF132448), // Celestial Navy highlight
          Color(0xFF080D1A), // Deep Midnight background
        ],
      ),
    );
  }
  return const BoxDecoration(
    color: _bgDark,
    gradient: RadialGradient(
      center: Alignment(0, -0.8),
      radius: 1.2,
      colors: [
        Color(0x1400E676),
        _bgDark,
      ],
    ),
  );
}

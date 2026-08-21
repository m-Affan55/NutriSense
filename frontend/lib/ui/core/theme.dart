import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Brand Colors
const Color _bgDark = Color(0xFF0D0F14);
const Color _surfaceDark = Color(0xFF161A22);
const Color _primaryGreen = Color(0xFF00E676);
const Color _secondaryOrange = Color(0xFFFF6D00);
const Color _textPrimaryDark = Color(0xFFFFFFFF);
const Color _textSecondaryDark = Color(0xFF8A94A6);

ThemeData buildLightTheme() {
  const fallbackFonts = ['JameelNooriNastaleeq'];
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primaryGreen,
      primary: _primaryGreen,
      secondary: _secondaryOrange,
    ),
    textTheme: GoogleFonts.interTextTheme().copyWith(
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

ThemeData buildDarkTheme() {
  const fallbackFonts = ['JameelNooriNastaleeq'];
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
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
    textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme).copyWith(
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
      titleTextStyle: GoogleFonts.outfit(
        color: _textPrimaryDark,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ).copyWith(fontFamilyFallback: fallbackFonts),
      iconTheme: const IconThemeData(color: _textPrimaryDark),
    ),
  );
}

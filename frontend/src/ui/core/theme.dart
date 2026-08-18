import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF325735), // Primary from SVG logo
      primary: const Color(0xFF325735),
      secondary: const Color(0xFFD3692D), // Secondary accent from SVG logo
      surface: const Color(0xFFF8F9FA),
    ),
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Colors.black87,
    ),
    scaffoldBackgroundColor: const Color(0xFFF4F6F4), // Clean subtle light greenish tint
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF325735), // Brand seed
      brightness: Brightness.dark,
      primary: const Color(0xFF81C784), // High contrast green for dark mode
      secondary: const Color(0xFFFF8A65), // Brighter coral orange for dark mode
      surface: const Color(0xFF1E1E1E),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF262626),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 0,
      foregroundColor: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
  );
}

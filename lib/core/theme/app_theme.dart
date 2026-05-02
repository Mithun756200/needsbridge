import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Semantic colors (same in both themes) ───────────────────────────────────
class NbColors {
  static const high   = Color(0xFFEF4444);
  static const medium = Color(0xFFF97316);
  static const low    = Color(0xFF22C55E);
  static const info   = Color(0xFF3B82F6);

  // Dark palette
  static const darkBg       = Color(0xFF0D1117);
  static const darkSurface  = Color(0xFF161B27);
  static const darkCard     = Color(0xFF1E2435);
  static const darkBorder   = Color(0xFF2D3348);
  static const darkPrimary  = Color(0xFF4F8EF7);
  static const darkSecondary= Color(0xFFFF6B35);
  static const darkOnSurface= Color(0xFFE8EAF0);
  static const darkMuted    = Color(0xFF8892A4);

  // Light palette
  static const lightBg       = Color(0xFFF0F4FF);
  static const lightSurface  = Color(0xFFFFFFFF);
  static const lightCard     = Color(0xFFFFFFFF);
  static const lightBorder   = Color(0xFFE2E8F0);
  static const lightPrimary  = Color(0xFF1565C0);
  static const lightSecondary= Color(0xFFE64A19);
  static const lightOnSurface= Color(0xFF0D1117);
  static const lightMuted    = Color(0xFF64748B);
}

// ─── Theme Mode Provider (persisted) ─────────────────────────────────────────
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'nb_theme_dark';

  @override
  ThemeMode build() {
    _load();
    return ThemeMode.dark; // default until loaded from prefs
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_key) ?? true;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state == ThemeMode.dark);
  }
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData dark() => ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: NbColors.darkPrimary,
      secondary: NbColors.darkSecondary,
      surface: NbColors.darkSurface,
      onPrimary: Colors.white,
      onSurface: NbColors.darkOnSurface,
    ),
    scaffoldBackgroundColor: NbColors.darkBg,
    cardColor: NbColors.darkCard,
    dividerColor: NbColors.darkBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: NbColors.darkSurface,
      foregroundColor: NbColors.darkOnSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: NbColors.darkCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NbColors.darkBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NbColors.darkCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.darkPrimary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NbColors.darkPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NbColors.darkPrimary,
        side: const BorderSide(color: NbColors.darkPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NbColors.darkCard,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: NbColors.darkBorder),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NbColors.darkPrimary,
      foregroundColor: Colors.white,
    ),
  );

  static ThemeData light() => ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: NbColors.lightPrimary,
      secondary: NbColors.lightSecondary,
      surface: NbColors.lightSurface,
      onPrimary: Colors.white,
      onSurface: NbColors.lightOnSurface,
    ),
    scaffoldBackgroundColor: NbColors.lightBg,
    cardColor: NbColors.lightCard,
    dividerColor: NbColors.lightBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: NbColors.lightSurface,
      foregroundColor: NbColors.lightOnSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: NbColors.lightCard,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: NbColors.lightBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: NbColors.lightPrimary, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: NbColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NbColors.lightPrimary,
        side: const BorderSide(color: NbColors.lightPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: NbColors.lightBg,
      labelStyle: const TextStyle(fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: const BorderSide(color: NbColors.lightBorder),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: NbColors.lightPrimary,
      foregroundColor: Colors.white,
    ),
  );
}

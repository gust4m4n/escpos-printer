import 'package:flutter/material.dart';

/// Color palette sampled from `assets/appicon.png`.
class AppTheme {
  AppTheme._();

  /// Icon background yellow.
  static const Color yellow = Color(0xFFFAD932);

  /// Printer body charcoal.
  static const Color charcoal = Color(0xFF3E3B33);

  /// Printer shadow / vent gray.
  static const Color gray = Color(0xFF6E6E6E);

  /// Receipt paper off-white.
  static const Color paper = Color(0xFFF3F1E9);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: brightness,
    );
    final scheme = base.copyWith(
      primary: yellow,
      onPrimary: charcoal,
      primaryContainer: isDark ? charcoal : const Color(0xFFFFF2B8),
      onPrimaryContainer: isDark ? yellow : charcoal,
      secondary: isDark ? const Color(0xFFD8D3C4) : charcoal,
      onSecondary: isDark ? charcoal : paper,
      secondaryContainer: isDark ? const Color(0xFF4A473D) : paper,
      onSecondaryContainer: isDark ? paper : charcoal,
      surface: isDark ? const Color(0xFF1C1A15) : paper,
      onSurface: isDark ? paper : charcoal,
      outline: gray,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: yellow,
        foregroundColor: charcoal,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: charcoal,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? yellow : charcoal,
          side: BorderSide(color: isDark ? gray : charcoal),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? yellow : charcoal,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF26231D) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: yellow, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: gray.withValues(alpha: 0.3)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? charcoal : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? yellow : null,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: charcoal,
        linearTrackColor: yellow,
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: charcoal,
        selectedTileColor: yellow.withValues(alpha: 0.25),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: yellow,
          selectedForegroundColor: charcoal,
          foregroundColor: isDark ? paper : charcoal,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(color: gray.withValues(alpha: 0.3)),
    );
  }
}

import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff55d49c), // electric mint
    primary: const Color(0xff098553), // darker for light mode contrast
    surface: const Color(0xfff7f7f9),
    brightness: Brightness.light,
  );
  return _buildTheme(scheme, isDark: false);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff55d49c), // electric mint
    primary: const Color(0xff55d49c),
    surface: const Color(0xff12091c), // deep aubergine/ink
    brightness: Brightness.dark,
  );
  return _buildTheme(scheme, isDark: true);
}

ThemeData _buildTheme(ColorScheme scheme, {required bool isDark}) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark
          ? const Color(0xff1f152d)
          : scheme.surfaceContainerHigh, // clear layer of depth
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: isDark
          ? const Color(0xff00ff87).withValues(alpha: 0.16)
          : scheme.primary.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            size: 24,
            color: isDark ? const Color(0xff00ff87) : scheme.primary,
          );
        }
        return IconThemeData(
          size: 24,
          color: isDark ? const Color(0xff928a9f) : const Color(0xff71717a),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xff00ff87) : scheme.primary,
            letterSpacing: -0.1,
          );
        }
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? const Color(0xff928a9f) : const Color(0xff71717a),
          letterSpacing: -0.1,
        );
      }),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: isDark ? Colors.white : scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xff1f1f2e),
      ),
      iconTheme: IconThemeData(
        color: isDark ? Colors.white : const Color(0xff1f1f2e),
      ),
    ),
  );
}

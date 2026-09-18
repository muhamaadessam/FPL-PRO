import 'package:flutter/material.dart';

import 'app_colors.dart';

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.plMint,
    primary: AppColors.plMintDark, // darker for light mode contrast
    surface: AppColors.lightBackground,
    brightness: Brightness.light,
  );
  return _buildTheme(scheme, isDark: false);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.plMint,
    primary: AppColors.plMint,
    surface: AppColors.darkBackground,
    surfaceContainer: AppColors.darkCard,
    surfaceContainerHigh: AppColors.darkCardElevated,
    surfaceContainerHighest: AppColors.darkActiveTab,
    outline: AppColors.darkCardBorder,
    brightness: Brightness.dark,
  );
  return _buildTheme(scheme, isDark: true);
}

ThemeData _buildTheme(ColorScheme scheme, {required bool isDark}) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    dividerTheme: DividerThemeData(
      color: isDark ? AppColors.darkCardBorder : const Color(0xfff0edf6),
      thickness: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppColors.darkCardElevated : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? AppColors.darkCard
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: isDark
            ? const BorderSide(color: AppColors.darkCardBorder)
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: isDark
            ? const BorderSide(color: AppColors.darkCardBorder)
            : BorderSide.none,
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
          ? AppColors.darkCard
          : scheme.surfaceContainerHigh, // clear layer of depth
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark
            ? const BorderSide(color: AppColors.darkCardBorder, width: 1)
            : BorderSide.none,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: Colors.transparent,
      indicatorColor: isDark
          ? AppColors.plMint.withValues(alpha: 0.16)
          : scheme.primary.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(
            size: 24,
            color: isDark ? AppColors.plMint : scheme.primary,
          );
        }
        return IconThemeData(
          size: 24,
          color: isDark ? AppColors.darkIconMuted : const Color(0xff71717a),
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.plMint : scheme.primary,
            letterSpacing: -0.1,
          );
        }
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextMuted : const Color(0xff71717a),
          letterSpacing: -0.1,
        );
      }),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: isDark ? AppColors.darkTextPrimary : scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.darkTextPrimary : const Color(0xff1f1f2e),
      ),
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextPrimary : const Color(0xff1f1f2e),
      ),
    ),
  );
}

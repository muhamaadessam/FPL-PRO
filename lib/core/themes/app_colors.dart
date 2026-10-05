import 'package:flutter/material.dart';

/// Centralized color tokens for FPL Pro app.
/// Provides a unified, high-contrast, premium dark mode palette
/// inspired by the Premier League identity (Midnight Navy & Electric Mint).
abstract final class AppColors {
  // -------------------------------------------------------------
  // Premier League Brand Accents
  // -------------------------------------------------------------
  static const Color plMint = Color(0xff00ff87); // Iconic FPL electric neon mint
  static const Color plMintDark = Color(0xff098553); // Light mode mint contrast
  static const Color plPurple = Color(0xff37003c); // Iconic PL deep purple
  static const Color plCyan = Color(0xff02efff);
  static const Color plMagenta = Color(0xffff005a);
  static const Color plViolet = Color(0xff963cff);

  // -------------------------------------------------------------
  // Dark Mode Palette (Refined FPL Midnight)
  // -------------------------------------------------------------
  static const Color darkBackground = Color(0xff0a0716); // Deep midnight base
  static const Color darkSurface = Color(0xff120e24); // Elevated surface
  static const Color darkCard = Color(0xff18132e); // Card surface
  static const Color darkCardElevated = Color(0xff201a3d); // Bottom sheets / dialogs
  static const Color darkCardBorder = Color(0xff2c2350); // Subtle card border
  static const Color darkActiveTab = Color(0xff271f4b); // Active toggle/pill bg
  static const Color darkNavBg = Color(0xff0f0c20); // Bottom navigation bar bg
  static const Color darkNavBorder = Color(0x1fffffff); // Top border for nav bar

  // Dark Mode Typography & Icons
  static const Color darkTextPrimary = Color(0xffffffff);
  static const Color darkTextSecondary = Color(0xffa59fb8);
  static const Color darkTextMuted = Color(0xff716b85);
  static const Color darkIconMuted = Color(0xff938da6);

  // Dark Mode Badges & Alerts
  static const Color darkAlertWarningBg = Color(0xff2a1b0b);
  static const Color darkAlertWarningBorder = Color(0xff573815);
  static const Color darkAlertWarningText = Color(0xffffb547);

  static const Color darkAlertErrorBg = Color(0xff2d121c);
  static const Color darkAlertErrorBorder = Color(0xff592031);
  static const Color darkAlertErrorText = Color(0xffff6b81);

  static const Color darkBenchBg = Color(0xff15102a);
  static const Color darkBenchBorder = Color(0xff2c2254);

  // -------------------------------------------------------------
  // Light Mode Palette
  // -------------------------------------------------------------
  static const Color lightBackground = Color(0xfff7f7f9);
  static const Color lightCard = Colors.white;
  static const Color lightCardBorder = Color(0xfff0edf6);
  static const Color lightActiveTab = Colors.white;
  static const Color lightTextPrimary = Color(0xff1f1f2e);
  static const Color lightTextSecondary = Color(0xff6b7280);
  static const Color lightTextMuted = Color(0xff9ca3af);

  // -------------------------------------------------------------
  // Context / Helper Resolvers
  // -------------------------------------------------------------
  static Color background(bool isDark) =>
      isDark ? darkBackground : lightBackground;

  static Color card(bool isDark) => isDark ? darkCard : lightCard;

  static Color cardElevated(bool isDark) =>
      isDark ? darkCardElevated : lightCard;

  static Color cardBorder(bool isDark) =>
      isDark ? darkCardBorder : lightCardBorder;

  static Color activeTab(bool isDark) =>
      isDark ? darkActiveTab : lightActiveTab;

  static Color textPrimary(bool isDark) =>
      isDark ? darkTextPrimary : lightTextPrimary;

  static Color textSecondary(bool isDark) =>
      isDark ? darkTextSecondary : lightTextSecondary;

  static Color textMuted(bool isDark) =>
      isDark ? darkTextMuted : lightTextMuted;

  static Color accent(bool isDark) => isDark ? plMint : plPurple;
}

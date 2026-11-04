import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Colour palette: dark, music-inspired, FretFlow lime accent (sampled from
/// the app logo).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0C0E13);
  static const Color surface = Color(0xFF161920);
  static const Color surfaceHigh = Color(0xFF1F232D);
  static const Color outline = Color(0xFF2A2F3B);

  static const Color accent = Color(0xFFB4FF43); // FretFlow lime
  static const Color beat = Color(0xFF6EA8FF); // regular beats
  static const Color good = Color(0xFF38D996); // in tune / completed
  static const Color bad = Color(0xFFFF6B6B); // far out of tune / errors

  static const Color textPrimary = Color(0xFFF3F5F9);
  static const Color textSecondary = Color(0xFF9AA3B2);
}

/// Shared text styles.
class AppText {
  AppText._();

  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  /// Big numerals (BPM, note names, timers). Tabular so digits don't jiggle.
  static TextStyle display(double size, {Color color = AppColors.textPrimary}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: -1,
      color: color,
      fontFeatures: tabularFigures,
    );
  }

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  static const TextStyle overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.textSecondary,
  );
}

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    brightness: Brightness.dark,
  );
  final scheme = base.copyWith(
    primary: AppColors.accent,
    onPrimary: Colors.black,
    secondary: AppColors.good,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.bad,
  );

  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.outline,
    sliderTheme: const SliderThemeData(
      trackHeight: 6,
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.outline,
      thumbColor: AppColors.accent,
      overlayColor: Color(0x29B4FF43),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: buttonShape,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: buttonShape,
        textStyle: buttonText,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.outline, width: 1.5),
      ),
    ),
  );
}

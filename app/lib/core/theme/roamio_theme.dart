import 'package:flutter/material.dart';
import 'package:roamio/core/theme/roamio_colors.dart';

const _font = 'PlusJakartaSans';

/// Builds a style from the design system's px size and em letter spacing.
TextStyle _style(double size, FontWeight weight, double height, double em) =>
    TextStyle(
      fontFamily: _font,
      fontSize: size,
      fontWeight: weight,
      height: height / size,
      letterSpacing: em * size,
      color: RoamioColors.ink,
    );

/// Large tabular figures for split totals (`numeric-split` token).
final TextStyle numericSplit = _style(
  24,
  FontWeight.w800,
  28,
  -0.03,
).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

ThemeData buildRoamioTheme() {
  final textTheme = TextTheme(
    displayLarge: _style(36, FontWeight.w800, 40, -0.035),
    headlineLarge: _style(26, FontWeight.w700, 32, -0.025),
    headlineMedium: _style(22, FontWeight.w700, 28, -0.02),
    headlineSmall: _style(18, FontWeight.w600, 24, -0.015),
    bodyLarge: _style(16, FontWeight.w400, 24, -0.01),
    bodyMedium: _style(14, FontWeight.w400, 20, 0),
    bodySmall: _style(12, FontWeight.w400, 16, 0.01),
    labelLarge: _style(14, FontWeight.w600, 18, -0.01),
    labelMedium: _style(12, FontWeight.w600, 16, 0.02),
    labelSmall: _style(11, FontWeight.w700, 14, 0.04),
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: RoamioColors.ink,
    primary: RoamioColors.ink,
    onPrimary: RoamioColors.surface,
    secondary: RoamioColors.cobalt,
    onSecondary: RoamioColors.surface,
    tertiary: RoamioColors.chartreuse,
    onTertiary: RoamioColors.ink,
    error: RoamioColors.coral,
    surface: RoamioColors.surface,
    onSurface: RoamioColors.ink,
    outline: RoamioColors.hairline,
  );

  const pill = StadiumBorder();

  return ThemeData(
    useMaterial3: true,
    fontFamily: _font,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: RoamioColors.canvas,
    textTheme: textTheme,
    cardTheme: const CardThemeData(
      color: RoamioColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(RoamioRadii.md)),
        side: BorderSide(color: RoamioColors.hairline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: RoamioColors.ink,
        foregroundColor: RoamioColors.surface,
        minimumSize: const Size.fromHeight(56),
        shape: pill,
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: RoamioColors.ink,
        minimumSize: const Size.fromHeight(48),
        shape: pill,
        side: const BorderSide(color: RoamioColors.hairline),
        textStyle: textTheme.labelLarge,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: const BorderSide(color: RoamioColors.hairline),
      backgroundColor: RoamioColors.surface,
      selectedColor: RoamioColors.ink,
      labelStyle: textTheme.labelLarge?.copyWith(color: RoamioColors.slate),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: RoamioColors.surface,
      ),
    ),
    // The pickers' headers default to the large headline style, which
    // overflows a phone-width dialog once a date range is shown.
    datePickerTheme: DatePickerThemeData(
      headerHeadlineStyle: textTheme.headlineMedium,
      rangePickerHeaderHeadlineStyle: textTheme.headlineSmall,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: RoamioColors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: RoamioColors.muted),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(RoamioRadii.base)),
        borderSide: BorderSide(color: RoamioColors.hairline),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(RoamioRadii.base)),
        borderSide: BorderSide(color: RoamioColors.hairline),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(RoamioRadii.base)),
        borderSide: BorderSide(color: RoamioColors.ink, width: 1.5),
      ),
    ),
  );
}

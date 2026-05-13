import 'package:flutter/material.dart';
import 'viv_colors.dart';
import 'viv_spacing.dart';
import 'viv_typography.dart';

class VivTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: VivColors.black,
        secondary: VivColors.lime,
        surface: VivColors.paper,
        onPrimary: VivColors.paper,
        onSecondary: VivColors.black,
        onSurface: VivColors.ink,
        outline: VivColors.lightGrey,
      ),
      scaffoldBackgroundColor: VivColors.paper,
      fontFamily: VivTypography.sansFont,
      textTheme: const TextTheme(
        displayLarge: VivTypography.heroTitle,
        displayMedium: VivTypography.h1,
        displaySmall: VivTypography.h2,
        headlineMedium: VivTypography.h3,
        headlineSmall: VivTypography.h4,
        bodyLarge: VivTypography.lead,
        bodyMedium: VivTypography.body,
        bodySmall: VivTypography.small,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: VivColors.paper,
        elevation: 0,
        iconTheme: IconThemeData(color: VivColors.ink),
        titleTextStyle: VivTypography.h3,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VivColors.lime,
          foregroundColor: VivColors.black,
          textStyle: VivTypography.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(
            horizontal: VivSpacing.space5,
            vertical: VivSpacing.space3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(VivSpacing.radiusMd),
          ),
          elevation: 0,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: VivColors.gray100,
        thickness: 1,
        space: VivSpacing.space4,
      ),
    );
  }
}

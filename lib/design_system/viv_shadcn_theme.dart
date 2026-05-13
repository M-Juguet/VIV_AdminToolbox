import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'viv_colors.dart';
import 'viv_spacing.dart';

class VivShadcnTheme {
  static ShadThemeData get lightTheme {
    final defaultColorScheme = const ShadZincColorScheme.light();
    
    return ShadThemeData(
      colorScheme: defaultColorScheme.copyWith(
        primary: VivColors.lime,
        primaryForeground: VivColors.black,
        ring: VivColors.lime,
      ),
      radius: BorderRadius.circular(VivSpacing.radiusMd),
    );
  }
}

import 'package:flutter/material.dart';
import 'viv_colors.dart';

class VivTypography {
  static const String displayFont = 'Playfair Display';
  static const String sansFont = 'Noto Sans';

  static const TextStyle heroTitle = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: 56.0, // clamp factor estimate
    height: 1.05,
    letterSpacing: -1.4, // -0.025em
    color: VivColors.ink,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: 40.0,
    height: 1.1,
    letterSpacing: -0.8, // -0.02em
    color: VivColors.ink,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: 32.0,
    height: 1.2,
    color: VivColors.ink,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: displayFont,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: 24.0,
    height: 1.2,
    color: VivColors.ink,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w700,
    fontStyle: FontStyle.italic,
    fontSize: 20.0,
    height: 1.3,
    color: VivColors.ink,
  );

  static const TextStyle subtitle = h4;

  static const TextStyle body = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w400,
    fontSize: 16.0,
    height: 1.6,
    color: VivColors.gray400, // Matching var(--fg-2) roughly or gray-400
  );

  static const TextStyle lead = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w400,
    fontSize: 18.0,
    height: 1.6,
    color: VivColors.ink,
  );

  static const TextStyle quote = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    fontSize: 18.0,
    height: 1.55,
    color: VivColors.ink,
  );

  static const TextStyle small = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w300,
    fontSize: 14.0,
    height: 1.6,
    color: VivColors.gray500,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: sansFont,
    fontWeight: FontWeight.w600,
    fontSize: 12.0,
    letterSpacing: 0.96, // 0.08em
    color: VivColors.gray500,
  );
}

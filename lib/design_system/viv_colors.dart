import 'package:flutter/material.dart';

class VivColors {
  // Brand colors - Primary
  static const Color black = Color(0xFF000000);
  static const Color lime = Color(0xFFC1F903);

  // Aliases and variants
  static const Color green = lime;
  static const Color green600 = Color(0xFF63A700);
  static const Color green300 = Color(0xFFDAFB6C);
  static const Color green100 = Color(0xFFF0FDBA);

  // Brand colors - Secondary
  static const Color offWhite = Color(0xFFF9F9F9);
  static const Color lightGrey = Color(0xFFB6B6B6);
  static const Color limeDeep = Color(0xFF63A700);

  // Neutral ramp
  static const Color ink = Color(0xFF000000);
  static const Color ink900 = Color(0xFF0A0A0A);
  static const Color ink800 = Color(0xFF1A1A1A);
  static const Color ink700 = Color(0xFF2B2B2B);

  static const Color gray500 = Color(0xFF6B6B6B);
  static const Color gray400 = Color(0xFF8A8A8A);
  static const Color gray300 = Color(0xFFB6B6B6);
  static const Color gray200 = Color(0xFFD9D9D9);
  static const Color gray100 = Color(0xFFECECEC);
  static const Color gray50 = offWhite;

  static const Color paper = Color(0xFFFFFFFF);

  // Gradients
  static const LinearGradient limeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lime, limeDeep],
  );
}

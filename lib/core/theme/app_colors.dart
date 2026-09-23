import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Background
  static const Color background = Color(0xFFFFF8F0);
  static const Color sectionBackground = Color(0xFFFCE8EC);

  // Surface & Fields
  static const Color surface = Color(0xFFFFFFFF);
  static const Color field = Color(0xFFFFFCF7);

  // Brand / CTA
  static const Color primary = Color(0xFFE9A6B2);

  // Accent
  static const Color accent = Color(0xFFEFAF82);
  static const Color premium = Color(0xFFC9A66B);

  // Semantic — the red already used by the error snack bars and the splash
  // failure state, and by the "log out" button on the profile screen.
  static const Color error = Color(0xFFD9534F);
  static const Color success = Color(0xFF4C9A6A);

  // Text
  static const Color textPrimary = Color(0xFF5B3930);
  static const Color textSecondary = Color(0xFF8A6659);
  static const Color placeholder = Color(0xFFB9A49B);

  // Border
  static const Color border = Color(0xFFE6D8D0);
  static const Color focus = Color(0xFFE9A6B2);

  // Common
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
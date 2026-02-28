import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF2563EB);       // Blue
  static const Color secondary = Color(0xFF7C3AED);     // Purple
  static const Color accent = Color(0xFFF59E0B);        // Amber

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);

  // Borders
  static const Color border = Color(0xFFE2E8F0);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0EA5E9);

  // Task status colours
  static const Color statusDraft = Color(0xFF94A3B8);
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusInProgress = Color(0xFF2563EB);
  static const Color statusCompleted = Color(0xFF16A34A);
  static const Color statusCancelled = Color(0xFFDC2626);
}

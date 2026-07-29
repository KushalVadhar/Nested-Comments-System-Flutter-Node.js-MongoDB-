import 'package:flutter/material.dart';

class AppConstants {
  static const String appTitle = 'Real-Time Comments';

  // Indentation per depth level (pixels)
  static const double indentWidth = 16.0;

  // Max visual indentation level before capping (to prevent squishing on narrow screens)
  static const int maxVisualDepth = 6;

  // Animation Durations
  static const Duration expandAnimationDuration = Duration(milliseconds: 250);
  static const Duration toastDuration = Duration(seconds: 3);

  // Debounce Durations
  static const int likeDebounceMs = 300;
  static const int searchDebounceMs = 400;

  // Colors
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color secondaryColor = Color(0xFF4F46E5);
  static const Color backgroundColor = Color(0xFF0F172A); // Slate Dark
  static const Color cardColor = Color(0xFF1E293B);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color accentColor = Color(0xFF10B981); // Emerald Green
  static const Color dangerColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFBF59E0B); // Amber
  static const Color borderLineColor = Color(0xFF334155);

  // Tree Indentation Guide Line Color
  static const Color indentLineColor = Color(0xFF3B82F6);
}

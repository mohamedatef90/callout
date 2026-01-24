import 'package:flutter/material.dart';

class AppColors {
  // Primary Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF8F9FA);
  static const Color divider = Color(0xFFE5E7EB);

  // Text Colors
  static const Color textPrimary = Color(0xFF1C1C1E);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFFA1A1AA);

  // Intelligence & AI Colors
  static const Color aiPurple = Color(0xFF8A2BE2);
  static const Color aiBlue = Color(0xFF007AFF);
  static const Gradient aiGradient = LinearGradient(
    colors: [Color(0xFF8A2BE2), Color(0xFF4169E1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Functional / Tier Colors
  static const Color tierStarter = Color(0xFFA1A1AA);
  static const Color tierPro = Color(0xFF2DD4BF);
  static const Color tierUnlimited = Color(0xFF18181B);

  // Speaker Label Colors (Pastels)
  static const List<Color> speakerColors = [
    Color(0xFFFFCFD2), // Rose
    Color(0xFFCFE2FF), // Sky
    Color(0xFFD1FFD7), // Mint
    Color(0xFFFFF2CF), // Cream
    Color(0xFFE2D1FF), // Lavender
  ];

  // Utility
  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);
}

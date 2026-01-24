import 'package:flutter/material.dart';
import 'dart:ui';

class WhisperColors {
  // Background gradient - dark slate tones
  static const Color slate900 = Color(0xFF0F172A); // Darkest
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);

  // Cards - frosted glass effect
  static Color get cardBg => Colors.white.withOpacity(0.05);
  static Color get cardBorder => Colors.white.withOpacity(0.1);

  // Accents
  static const Color amber = Color(0xFFF59E0B); // Primary actions, recording
  static const Color purple = Color(0xFF8B5CF6); // AI features
  static const Color emerald = Color(0xFF10B981); // Success, play
  static const Color rose = Color(0xFFF43F5E); // Delete, stop

  // Text
  static const Color textPrimary = Colors.white;
  static Color get textSecondary => Colors.white.withOpacity(0.7);
  static Color get textMuted => Colors.white.withOpacity(0.38);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [slate900, slate800],
  );

  static const LinearGradient amberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
  );

  static const LinearGradient purpleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA78BFA), Color(0xFF8B5CF6)],
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
  );

  static const LinearGradient roseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFB7185), Color(0xFFF43F5E)],
  );

  // Folder colors
  static const List<Color> folderColors = [
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Purple
    Color(0xFF10B981), // Emerald
    Color(0xFF3B82F6), // Blue
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF97316), // Orange
    Color(0xFF06B6D4), // Cyan
  ];

  // Utility
  static Color shimmerBase = Colors.white.withOpacity(0.05);
  static Color shimmerHighlight = Colors.white.withOpacity(0.1);
}

import 'package:flutter/material.dart';

/// Computes soft pastel avatar colors based on the first letter of a name.
class AvatarHelper {
  AvatarHelper._();

  static Color backgroundColor(String name) {
    if (name.isEmpty) return const Color(0xFFF5F5F5);
    final code = name[0].toUpperCase().codeUnitAt(0);
    if (code >= 65 && code <= 69) return const Color(0xFF0EA5E9); // A-E
    if (code >= 70 && code <= 74) return const Color(0xFF059669); // F-J
    if (code >= 75 && code <= 79) return const Color(0xFFB45309); // K-O
    if (code >= 80 && code <= 84) return const Color(0xFF7C3AED); // P-T
    return const Color(0xFFDC2626); // U-Z
  }

  static Color textColor(String name) {
    if (name.isEmpty) return const Color(0xFF111111);
    return Colors.white;
  }
}

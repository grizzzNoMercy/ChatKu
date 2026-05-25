import 'package:flutter/material.dart';

/// Computes soft pastel avatar colors based on the first letter of a name.
class AvatarHelper {
  AvatarHelper._();

  static Color backgroundColor(String name) {
    if (name.isEmpty) return const Color(0xFFF5F5F5);
    final code = name[0].toUpperCase().codeUnitAt(0);
    if (code >= 65 && code <= 69) return const Color(0xFFFFE0E0); // A-E
    if (code >= 70 && code <= 74) return const Color(0xFFFFF3D0); // F-J
    if (code >= 75 && code <= 79) return const Color(0xFFD0F0E0); // K-O
    if (code >= 80 && code <= 84) return const Color(0xFFD0E8FF); // P-T
    return const Color(0xFFE8D0FF); // U-Z
  }

  static Color textColor(String name) {
    if (name.isEmpty) return const Color(0xFF111111);
    final code = name[0].toUpperCase().codeUnitAt(0);
    if (code >= 65 && code <= 69) return const Color(0xFFC0392B);
    if (code >= 70 && code <= 74) return const Color(0xFFD4890B);
    if (code >= 75 && code <= 79) return const Color(0xFF27AE60);
    if (code >= 80 && code <= 84) return const Color(0xFF2980B9);
    return const Color(0xFF8E44AD);
  }
}

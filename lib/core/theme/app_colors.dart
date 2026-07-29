import 'dart:ui';

class AppColors {
  AppColors._();

  // Premium Dark Theme (Black + Muted Crimson + Gold)
  static const Color primary = Color(0xFF8B1E2D); // Muted Crimson
  static const Color primaryLight = Color(0xFFB23A48);

  static const Color darkSurface = Color(0xFF111111); // Charcoal Black

  // Accents
  static const Color accent = Color(0xFF8B1E2D);
  static const Color accentLight = Color(0xFFB23A48);
  static const Color secondaryAccent = Color(0xFFD4AF37); // Gold

  static const Color gold = Color(0xFFD4AF37);

  static const Color green = Color(0xFF2ECC71);
  static const Color red = Color(0xFFD9534F);

  static const Color cardDark = Color(0xFF1A1A1A);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF7F7F9);

  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFB3B3B3);

  static const Color borderDark = Color(0xFF2A2A2A);

  static const Color textOnDark = Color(0xFFF5F5F5);
  static const Color textOnDarkSecondary = Color(0xFFA1A1AA);

  static const Color blue = Color(0xFF33CCFF);
  static const Color purple = Color(0xFF9933FF);
  
  static const Color chipWhite = Color(0xFFF8F9FA);
  static const Color chipRed = Color(0xFFFF3366);
  static const Color chipBlue = Color(0xFF33CCFF);
  static const Color chipGreen = Color(0xFF20E070);
  static const Color chipBlack = Color(0xFF222228);
  static const Color chipPurple = Color(0xFF9933FF);
  static const Color chipOrange = Color(0xFFFF8800);
  static const Color chipYellow = Color(0xFFFFDD00);

  static Color chipColor(String name) {
    switch (name.toLowerCase()) {
      case 'white': return chipWhite;
      case 'red': return chipRed;
      case 'blue': return chipBlue;
      case 'green': return chipGreen;
      case 'black': return chipBlack;
      case 'purple': return chipPurple;
      case 'orange': return chipOrange;
      case 'yellow': return chipYellow;
      default: return chipWhite;
    }
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// پالت رنگی «معمار»: پس‌زمینه تیره، لهجه‌ی طلایی/کهربایی (حس جدیت و پیشرفت)
class AppColors {
  static const background = Color(0xFF0E0F12);
  static const surface = Color(0xFF1A1C21);
  static const surfaceLight = Color(0xFF24262D);
  static const primary = Color(0xFFE0A94A); // طلایی کهربایی
  static const success = Color(0xFF4CAF7D);
  static const danger = Color(0xFFE0574A);
  static const textPrimary = Color(0xFFF2F2F2);
  static const textSecondary = Color(0xFF9A9CA5);
}

class AppTheme {
  static ThemeData get darkTheme {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.primary,
        surface: AppColors.surface,
      ),
      textTheme: GoogleFonts.vazirmatnTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceLight,
      ),
    );
  }
}

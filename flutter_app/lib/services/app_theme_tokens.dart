import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color surface = Color(0xFFF5F7FA);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFD);

  // Brand colors
  static const Color navy = Color(0xFF0B2A4A);
  static const Color navyHover = Color(0xFF12385F);
  static const Color navyPressed = Color(0xFF08213A);
  static const Color orange = Color(0xFFF47C20);
  static const Color orangeHover = Color(0xFFDB6B16);
  static const Color orangePressed = Color(0xFFB85712);

  static const Color navSurface = navy;
  static const Color accent = orange;
  static const Color textPrimary = Color(0xFF10243A);
  static const Color textSecondary = Color(0xFF5C6B7A);
  static const Color textMuted = Color(0xFF6E7C8A);
  static const Color borderSubtle = Color(0xFFE3E8EF);

  static const Color statusSuccess = Color(0xFF16A34A);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusError = Color(0xFFDC2626);
  static const Color statusInfo = Color(0xFF2563EB);
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class AppTypography {
  static TextStyle mobileNavLabel(Color color, {required bool isActive}) {
    return TextStyle(
      color: color,
      fontSize: 12,
      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0.2,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.surface,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardColor: AppColors.surfaceCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class AppButtons {
  static ButtonStyle destructiveOutlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.statusError,
    side: const BorderSide(color: AppColors.statusError),
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  );

  static ButtonStyle destructiveText = TextButton.styleFrom(
    foregroundColor: AppColors.statusError,
    textStyle: const TextStyle(fontWeight: FontWeight.w600),
  );
}

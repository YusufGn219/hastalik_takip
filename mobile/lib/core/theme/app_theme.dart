import 'package:flutter/material.dart';

class AppColors {
  // Ana renk — Mor
  static const primary50  = Color(0xFFEEEDFE);
  static const primary100 = Color(0xFFCECBF6);
  static const primary200 = Color(0xFFAFA9EC);
  static const primary400 = Color(0xFF7F77DD);
  static const primary600 = Color(0xFF534AB7);
  static const primary800 = Color(0xFF3C3489);
  static const primary900 = Color(0xFF26215C);

  // Semptom — Turuncu/Mercan
  static const symptom    = Color(0xFFD85A30);
  static const symptomBg  = Color(0xFFFAECE7);

  // İlaç — Mavi
  static const medication    = Color(0xFF378ADD);
  static const medicationBg  = Color(0xFFE6F1FB);

  // Günlük — Yeşil
  static const daily    = Color(0xFF639922);
  static const dailyBg  = Color(0xFFEAF3DE);

  // Atak — Kırmızı
  static const episode    = Color(0xFFE24B4A);
  static const episodeBg  = Color(0xFFFCEBEB);

  // Şiddet badge renkleri
  static const severityLow    = Color(0xFF639922);   // 1-3
  static const severityMid    = Color(0xFFD85A30);   // 4-6
  static const severityHigh   = Color(0xFFE24B4A);   // 7-10
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary400,
        brightness: Brightness.light,
      ).copyWith(
        primary: AppColors.primary400,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary50,
        onPrimaryContainer: AppColors.primary800,
        secondary: AppColors.primary600,
        surface: Colors.white,
        onSurface: const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F5FA),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1A2E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary50,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary600,
            );
          }
          return const TextStyle(fontSize: 12, color: Colors.grey);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary600, size: 24);
          }
          return const IconThemeData(color: Colors.grey, size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary400,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary400,
          side: const BorderSide(color: AppColors.primary400, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary400, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
        floatingLabelStyle: const TextStyle(color: AppColors.primary400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary400,
        thumbColor: AppColors.primary400,
        inactiveTrackColor: AppColors.primary100,
        overlayColor: Color(0x1A7F77DD),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary50,
        labelStyle: const TextStyle(color: AppColors.primary800, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.black.withOpacity(0.06),
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E)),
        bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFF1A1A2E)),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF4A4A6A)),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF8888AA)),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF8888AA)),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary400,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.primary200,
        onPrimary: AppColors.primary900,
        primaryContainer: AppColors.primary800,
        onPrimaryContainer: AppColors.primary100,
        surface: const Color(0xFF1A1825),
        onSurface: const Color(0xFFEEEDFE),
      ),
      scaffoldBackgroundColor: const Color(0xFF12111C),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF1A1825),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Color(0xFF1A1825),
        foregroundColor: Color(0xFFEEEDFE),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFFEEEDFE),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF1A1825),
        indicatorColor: AppColors.primary800,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary200,
            );
          }
          return TextStyle(fontSize: 12, color: Colors.grey[600]);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary200, size: 24);
          }
          return IconThemeData(color: Colors.grey[600], size: 24);
        }),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary400,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary200,
          side: const BorderSide(color: AppColors.primary200, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF221F30),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary200, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.grey[500]),
        floatingLabelStyle: const TextStyle(color: AppColors.primary200),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary200,
        thumbColor: AppColors.primary200,
        inactiveTrackColor: AppColors.primary800,
        overlayColor: Color(0x1AAFA9EC),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primary800,
        labelStyle: const TextStyle(color: AppColors.primary100, fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.06),
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFFEEEDFE)),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFEEEDFE)),
        titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFEEEDFE)),
        titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFFEEEDFE)),
        bodyLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Color(0xFFEEEDFE)),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFFAFA9EC)),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF7F77DD)),
        labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF7F77DD)),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color background = Color(0xFF0A0D10);
  static const Color backgroundDeep = Color(0xFF050709);
  static const Color surface = Color(0xFF11161B);
  static const Color surfaceElevated = Color(0xFF182028);
  static const Color surfaceHigh = Color(0xFF222C36);

  static const Color border = Color(0x1EFFFFFF);
  static const Color borderStrong = Color(0x38FFFFFF);
  static const Color specularRim = Color(0x4DFFFFFF);

  static const Color glassFill = Color(0x66161D24);
  static const Color glassFillStrong = Color(0x9912181E);
  static const Color glassTint = Color(0x22FFFFFF);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFAEBAC7);
  static const Color textMuted = Color(0xFF73808E);

  // Bespoke Lunarellys Aurora Emerald & Lunar Cyan palette
  static const Color brandGreen = Color(0xFF12D88A);
  static const Color brandGreenBright = Color(0xFF34F5A4);
  static const Color brandDeep = Color(0xFF0B6E4F);
  static const Color lunarCyan = Color(0xFF38BDF8);

  static const Color error = Color(0xFFF87171);
  static const Color success = Color(0xFF12D88A);
}

class AppTheme {
  static ThemeData darkTheme({Color? dynamicSeed}) {
    final accent = dynamicSeed ?? AppColors.brandGreen;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
      primary: accent,
      secondary: AppColors.lunarCyan,
      onPrimary: Colors.black,
    );

    final baseText = GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme);
    final displayStyle = GoogleFonts.plusJakartaSans();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      splashColor: accent.withAlpha(32),
      highlightColor: Colors.white.withAlpha(18),
      textTheme: baseText.copyWith(
        headlineLarge: displayStyle.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          color: AppColors.textPrimary,
        ),
        headlineMedium: displayStyle.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
        ),
        titleLarge: displayStyle.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: AppColors.textPrimary,
        ),
        titleMedium: baseText.titleMedium?.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: baseText.bodyMedium?.copyWith(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        bodySmall: baseText.bodySmall?.copyWith(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: displayStyle.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: AppColors.textPrimary,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brandGreenBright,
          foregroundColor: Colors.black,
          textStyle: displayStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: Colors.white.withAlpha(14),
          side: const BorderSide(color: AppColors.borderStrong),
          textStyle: displayStyle.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withAlpha(20),
        selectedColor: AppColors.brandGreenBright,
        labelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        side: const BorderSide(color: AppColors.border, width: 0.8),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.white.withAlpha(24),
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 23,
            color: selected ? AppColors.brandGreenBright : AppColors.textSecondary,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withAlpha(55),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withAlpha(32),
        trackHeight: 3.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withAlpha(18),
        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.brandGreenBright, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceElevated,
        contentTextStyle: GoogleFonts.dmSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xE612181F),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(color: AppColors.borderStrong, width: 0.9),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xEC141B23),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
  }
}

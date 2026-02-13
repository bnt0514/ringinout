import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════
// 🔥 Ringinout Brand Color System
// ════════════════════════════════════════════════════════════
// Primary Gradient: #FF6A00 → #FF3C00
// Primary Solid:    #FF5A1F
// Background:       #FFF5EE
// Card:             #FFFFFF
// Active State:     #FF5A1F
// Inactive:         #E0E0E0
// Divider:          #F1E4DB
// ════════════════════════════════════════════════════════════

/// 브랜드 컬러 상수 (어디서든 AppColors.xxx 로 접근)
class AppColors {
  AppColors._();

  // ── Primary ──
  static const Color primary = Color(0xFFFF5A1F);
  static const Color primaryLight = Color(0xFFFF6A00);
  static const Color primaryDark = Color(0xFFFF3C00);

  // ── Gradient ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF6A00), Color(0xFFFF3C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Surfaces ──
  static const Color background = Color(0xFFFFF5EE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);

  // ── States ──
  static const Color active = Color(0xFFFF5A1F);
  static const Color inactive = Color(0xFFE0E0E0);

  // ── Divider / Border ──
  static const Color divider = Color(0xFFF1E4DB);
  static const Color border = Color(0xFFF1E4DB);

  // ── Text ──
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Semantic ──
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF1E88E5);

  // ── Weekday ──
  static const Color sunday = Color(0xFFE53935);
  static const Color saturday = Color(0xFF1E88E5);

  // ── Functional ──
  static const Color shimmer = Color(0xFFFFF0E8);
  static const Color toggleTrackOn = Color(0xFFFF5A1F);
  static const Color toggleTrackOff = Color(0xFFE0E0E0);
  static const Color toggleThumb = Color(0xFFFFFFFF);

  // ── Map overlays ──
  static const Color mapCircleFill = Color(0x33FF5A1F); // 20% alpha
  static const Color mapCircleBorder = Color(0xFFFF5A1F);
}

/// 브랜드 스타일 상수 (radius, spacing, shadow)
class AppStyle {
  AppStyle._();

  // ── Border Radius ──
  static const double radiusCard = 20;
  static const double radiusButton = 24;
  static const double radiusToggle = 30;
  static const double radiusInput = 14;
  static const double radiusSmall = 8;
  static const double radiusSheet = 24;

  // ── Spacing ──
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingBase = 16;
  static const double spacingCard = 20;
  static const double spacingLg = 24;
  static const double spacingXl = 32;

  // ── Shadow ──
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      blurRadius: 10,
      offset: const Offset(0, 4),
      color: Colors.black.withValues(alpha: 0.05),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      blurRadius: 12,
      offset: const Offset(0, 3),
      color: AppColors.primary.withValues(alpha: 0.08),
    ),
  ];

  static List<BoxShadow> get fabShadow => [
    BoxShadow(
      blurRadius: 16,
      spreadRadius: 2,
      offset: const Offset(0, 4),
      color: AppColors.primary.withValues(alpha: 0.3),
    ),
  ];
}

/// 앱 전체 ThemeData
class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,

      // ── Color Scheme ──
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.surface,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        outline: AppColors.border,
      ),

      scaffoldBackgroundColor: AppColors.background,

      // ── AppBar ──
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Card ──
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusCard),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: AppStyle.spacingBase,
          vertical: AppStyle.spacingSm,
        ),
      ),

      // ── FAB ──
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusButton),
        ),
      ),

      // ── ElevatedButton ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.spacingLg,
            vertical: AppStyle.spacingMd,
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.radiusButton),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.spacingLg,
            vertical: AppStyle.spacingMd,
          ),
        ),
      ),

      // ── TextButton ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),

      // ── Input ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppStyle.spacingBase,
          vertical: AppStyle.spacingMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusInput),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusInput),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusInput),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusInput),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        hintStyle: const TextStyle(color: AppColors.textHint),
      ),

      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      // ── Bottom Navigation ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.card,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedIconTheme: IconThemeData(size: 26),
        unselectedIconTheme: IconThemeData(size: 22),
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 11),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── ListTile ──
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppStyle.spacingBase,
          vertical: AppStyle.spacingXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusSmall),
        ),
      ),

      // ── Dialog ──
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusCard),
        ),
      ),

      // ── BottomSheet ──
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppStyle.radiusSheet),
          ),
        ),
      ),

      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return AppColors.toggleThumb;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.toggleTrackOn;
          }
          return AppColors.toggleTrackOff;
        }),
      ),

      // ── Checkbox ──
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Chip (for ChoiceChip etc.) ──
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusSmall),
        ),
        side: const BorderSide(color: AppColors.border),
      ),

      // ── SnackBar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(color: AppColors.textOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.radiusSmall),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── TabBar ──
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
      ),

      // ── ProgressIndicator ──
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.inactive,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 테마 선택을 위한 열거형
enum AppThemeStyle {
  softSunrise, // Style 1: 부드러운 따뜻한 느낌
  cleanSignal, // Style 2: 미니멀 기능 중심
  original, // 원본 (indigo 기반)
}

/// 앱 전체 테마 관리 클래스
class AppThemes {
  // ===== 현재 활성 테마 =====
  // 👇 여기서 바꾸면 바로 전환됨! (백업 안전)
  static AppThemeStyle currentTheme = AppThemeStyle.softSunrise;

  // ===== Style 1: Soft Sunrise =====
  // 컬러: 따뜻한 오렌지 + 크림 배경
  // 느낌: 부드럽고 친근한 카드 UI, 둥근 코너
  static ThemeData get softSunriseTheme {
    const primary = Color(0xFFFF8A3D); // 메인 오렌지
    const secondary = Color(0xFFFFB36B); // 서브 오렌지
    const background = Color(0xFFFFF8F2); // 크림 배경
    const surface = Colors.white;
    const onPrimary = Colors.white;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onPrimary: onPrimary,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        error: const Color(0xFFE57373),
      ),
      scaffoldBackgroundColor: background,

      // 앱바 스타일
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onPrimary,
        ),
      ),

      // 카드 스타일 (둥글고 부드러운)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 2,
        shadowColor: primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // 플로팅 버튼
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 4,
      ),

      // 버튼 스타일
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // 텍스트 버튼
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      // 입력 필드
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondary.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),

      // 바텀 네비게이션
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        selectedIconTheme: IconThemeData(size: 28),
        unselectedIconTheme: IconThemeData(size: 22),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // ===== Style 2: Clean Signal =====
  // 컬러: 오렌지 포인트 + 뉴트럴 그레이/화이트
  // 느낌: 삼성 One UI 느낌, 미니멀, 정보 우선
  static ThemeData get cleanSignalTheme {
    const primary = Color(0xFFFF8A3D); // 오렌지 포인트
    const background = Color(0xFFF5F5F5); // 밝은 그레이
    const surface = Colors.white;
    const onPrimary = Colors.white;
    const neutral = Color(0xFF424242); // 다크 그레이

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: neutral,
        surface: surface,
        onPrimary: onPrimary,
        onSecondary: Colors.white,
        onSurface: neutral,
        error: const Color(0xFFD32F2F),
      ),
      scaffoldBackgroundColor: background,

      // 앱바 스타일 (깔끔한 화이트)
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: neutral,
        elevation: 0,
        centerTitle: false, // One UI 스타일
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: neutral,
        ),
      ),

      // 카드 스타일 (최소 장식)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // 플로팅 버튼
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        elevation: 6,
      ),

      // 버튼 스타일 (강조 최소화)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primary),
      ),

      // 입력 필드 (라인 강조)
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),

      // 바텀 네비게이션 (라인 아이콘 강조)
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        selectedIconTheme: IconThemeData(size: 26),
        unselectedIconTheme: IconThemeData(size: 24),
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // ===== 원본 테마 (백업용) =====
  static ThemeData get originalTheme {
    return ThemeData(primarySwatch: Colors.indigo, useMaterial3: true);
  }

  // ===== 현재 선택된 테마 반환 =====
  static ThemeData get theme {
    switch (currentTheme) {
      case AppThemeStyle.softSunrise:
        return softSunriseTheme;
      case AppThemeStyle.cleanSignal:
        return cleanSignalTheme;
      case AppThemeStyle.original:
        return originalTheme;
    }
  }
}

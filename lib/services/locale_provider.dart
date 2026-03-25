import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 지원하는 언어 목록
enum AppLanguage {
  system, // 시스템 기본
  english, // 영어
  korean, // 한국어
  japanese, // 일본어
  chinese, // 중국어
}

extension AppLanguageExtension on AppLanguage {
  String get displayName {
    switch (this) {
      case AppLanguage.system:
        return 'System Default';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.korean:
        return '한국어';
      case AppLanguage.japanese:
        return '日本語';
      case AppLanguage.chinese:
        return '中文';
    }
  }

  String get code {
    switch (this) {
      case AppLanguage.system:
        return 'system';
      case AppLanguage.english:
        return 'en';
      case AppLanguage.korean:
        return 'ko';
      case AppLanguage.japanese:
        return 'ja';
      case AppLanguage.chinese:
        return 'zh';
    }
  }

  Locale? get locale {
    switch (this) {
      case AppLanguage.system:
        return null; // 시스템 기본 사용
      case AppLanguage.english:
        return const Locale('en', 'US');
      case AppLanguage.korean:
        return const Locale('ko', 'KR');
      case AppLanguage.japanese:
        return const Locale('ja', 'JP');
      case AppLanguage.chinese:
        return const Locale('zh', 'CN');
    }
  }

  static AppLanguage fromCode(String code) {
    switch (code) {
      case 'en':
        return AppLanguage.english;
      case 'ko':
        return AppLanguage.korean;
      case 'ja':
        return AppLanguage.japanese;
      case 'zh':
        return AppLanguage.chinese;
      default:
        return AppLanguage.system;
    }
  }
}

/// 언어 설정을 관리하는 Provider
class LocaleProvider extends ChangeNotifier {
  AppLanguage _currentLanguage = AppLanguage.system;
  Locale? _locale;

  AppLanguage get currentLanguage => _currentLanguage;
  Locale? get locale => _locale;

  LocaleProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_language_code') ?? 'system';
    _currentLanguage = AppLanguageExtension.fromCode(code);
    _locale = _currentLanguage.locale;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    _locale = language.locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language_code', language.code);

    notifyListeners();
  }

  /// 실제 적용될 로케일 (시스템 기본인 경우 시스템 로케일 사용)
  Locale getEffectiveLocale(BuildContext context) {
    if (_locale != null) {
      return _locale!;
    }
    // 시스템 기본 로케일
    final systemLocale = Localizations.localeOf(context);
    // 지원하는 언어인지 확인
    if (['ko', 'en', 'ja', 'zh'].contains(systemLocale.languageCode)) {
      return systemLocale;
    }
    // 지원하지 않으면 영어로
    return const Locale('en', 'US');
  }
}

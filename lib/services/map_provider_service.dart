// lib/services/map_provider_service.dart
// 맵 제공자 관리 서비스 (네이버맵 / 구글맵 전환 + 킬스위치)

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/hive_helper.dart';

enum MapProvider { naver, google }

class MapProviderService extends ChangeNotifier {
  static const String _storageKey = 'map_provider';

  MapProvider _provider = MapProvider.naver;
  bool _isKoreanRegion = false;
  String _googleLanguage = 'en';

  MapProvider get provider => _provider;
  bool get isNaver => _provider == MapProvider.naver;
  bool get isGoogle => _provider == MapProvider.google;
  String get googleLanguage => _googleLanguage;

  /// 네이버맵 전환 가능 여부.
  /// Naver Maps is intended for Korea-only use in this app.
  bool get isNaverAvailable => _isKoreanRegion && AppConfig.isNaverMapsEnabled;

  /// 구글맵 사용 가능 여부
  bool get isGoogleAvailable => AppConfig.isGoogleMapsEnabled;

  bool get hasAvailableProvider => availableProviders.isNotEmpty;
  bool get isCurrentProviderAvailable =>
      (_provider == MapProvider.naver && isNaverAvailable) ||
      (_provider == MapProvider.google && isGoogleAvailable);

  /// 현재 한국 로케일 여부 (다이얼로그 문구 분기 등에 사용)
  bool get isKoreanLocale => _isKoreanRegion;

  MapProviderService() {
    _loadFromStorage();
  }

  /// 앱 로케일이 확정된 후 호출
  void initForLocale(String languageCode, {String? countryCode}) {
    final country = countryCode?.toUpperCase();
    _isKoreanRegion =
        country == 'KR' || (country == null && languageCode == 'ko');
    _googleLanguage = _normalizeGoogleLanguage(languageCode);
    if (!isCurrentProviderAvailable) {
      _provider = _preferredProvider();
    }
    _applyKillSwitchFallback();
  }

  void updateRegionFromCoordinates(double latitude, double longitude) {
    final inKorea =
        latitude >= 32.5 &&
        latitude <= 39.5 &&
        longitude >= 124.0 &&
        longitude <= 132.5;
    if (_isKoreanRegion == inKorea) return;
    _isKoreanRegion = inKorea;
    if (!isCurrentProviderAvailable) {
      final next = _preferredProvider();
      if (_provider != next) {
        _provider = next;
        HiveHelper.settingsBox.put(_storageKey, _provider.name);
      }
    }
    notifyListeners();
  }

  /// 킬스위치 변경 후 현재 provider가 비활성이면 사용 가능한 유료 지도 공급자로 폴백
  void applyKillSwitch() {
    _applyKillSwitchFallback();
    notifyListeners();
  }

  void _applyKillSwitchFallback() {
    if (!isCurrentProviderAvailable && hasAvailableProvider) {
      final next = _preferredProvider();
      if (_provider != next) {
        _provider = next;
        HiveHelper.settingsBox.put(_storageKey, _provider.name);
      }
      debugPrint('🗺️ 지도 공급자 폴백 → ${_provider.name}');
      notifyListeners();
    }
  }

  MapProvider _preferredProvider() {
    final ordered =
        _isKoreanRegion
            ? [MapProvider.naver, MapProvider.google]
            : [MapProvider.google];
    return ordered.firstWhere(
      (p) =>
          (p == MapProvider.naver && isNaverAvailable) ||
          (p == MapProvider.google && isGoogleAvailable),
      orElse: () => _isKoreanRegion ? MapProvider.naver : MapProvider.google,
    );
  }

  void _loadFromStorage() {
    try {
      final saved = HiveHelper.settingsBox.get(
        _storageKey,
        defaultValue: 'naver',
      );
      if (saved == 'naver') {
        _provider = MapProvider.naver;
      } else if (saved == 'google') {
        _provider = MapProvider.google;
      } else {
        _provider = MapProvider.naver;
      }
    } catch (e) {
      debugPrint('❌ MapProviderService load error: $e');
      _provider = MapProvider.naver;
      _googleLanguage = 'en';
    }
  }

  void setProvider(MapProvider newProvider) {
    if (newProvider == MapProvider.naver && !isNaverAvailable) {
      debugPrint('Naver Maps not available outside Korean locale');
      return;
    }
    if (newProvider == MapProvider.google && !isGoogleAvailable) {
      debugPrint('🗺️ Google Maps not available (kill switch)');
      return;
    }
    if (_provider == newProvider) return;
    _provider = newProvider;
    HiveHelper.settingsBox.put(_storageKey, newProvider.name);
    notifyListeners();
    debugPrint('🗺️ Map provider → ${newProvider.name}');
  }

  static String _normalizeGoogleLanguage(String languageCode) {
    const supported = {'ko', 'en', 'ja', 'zh', 'de', 'fr', 'es'};
    return supported.contains(languageCode) ? languageCode : 'en';
  }

  List<MapProvider> get availableProviders {
    final preferred =
        _isKoreanRegion
            ? [MapProvider.naver, MapProvider.google]
            : [MapProvider.google];
    return [
      for (final p in preferred)
        if (p == MapProvider.naver && isNaverAvailable ||
            p == MapProvider.google && isGoogleAvailable)
          p,
    ];
  }

  /// 순환 토글 (활성화된 것만)
  void toggle() {
    final available = availableProviders;
    if (available.length <= 1) return;
    final currentIdx = available.indexOf(_provider);
    final nextIdx = (currentIdx + 1) % available.length;
    setProvider(available[nextIdx]);
  }
}

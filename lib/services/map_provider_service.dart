// lib/services/map_provider_service.dart
// 맵 제공자 관리 서비스 (네이버맵 / 구글맵 / OSM 전환 + 킬스위치)

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/hive_helper.dart';

enum MapProvider { naver, google, osm }

class MapProviderService extends ChangeNotifier {
  static const String _storageKey = 'map_provider';

  MapProvider _provider = MapProvider.osm;
  bool _isKoreanLocale = false;

  MapProvider get provider => _provider;
  bool get isNaver => _provider == MapProvider.naver;
  bool get isGoogle => _provider == MapProvider.google;
  bool get isOsm => _provider == MapProvider.osm;

  /// 네이버맵 전환 가능 여부 (한국 로케일 + 킬스위치)
  /// 한국 사용자에게만 표시 (구글맵 대신)
  bool get isNaverAvailable => _isKoreanLocale && AppConfig.isNaverMapsEnabled;

  /// 구글맵 사용 가능 여부 (킬스위치 + 한국에서는 숨김)
  /// 해외 사용자에게만 표시 (네이버맵 대신)
  bool get isGoogleAvailable => !_isKoreanLocale && AppConfig.isGoogleMapsEnabled;

  /// OSM은 항상 사용 가능 (폴백)
  bool get isOsmAvailable => true;

  MapProviderService() {
    _loadFromStorage();
  }

  /// 앱 로케일이 확정된 후 호출
  void initForLocale(String languageCode) {
    _isKoreanLocale = languageCode == 'ko';
    _applyKillSwitchFallback();
  }

  /// 킬스위치 변경 후 현재 provider가 비활성이면 OSM으로 폴백
  void applyKillSwitch() {
    _applyKillSwitchFallback();
    notifyListeners();
  }

  void _applyKillSwitchFallback() {
    // 킬스위치 폴백
    if (_provider == MapProvider.google && !isGoogleAvailable) {
      _provider = isNaverAvailable ? MapProvider.naver : MapProvider.osm;
      debugPrint('🗺️ Google 차단 → ${_provider.name} 로 폴백');
      notifyListeners();
    }
    if (_provider == MapProvider.naver && !isNaverAvailable) {
      _provider = isGoogleAvailable ? MapProvider.google : MapProvider.osm;
      debugPrint('🗺️ Naver 차단 → ${_provider.name} 로 폴백');
      notifyListeners();
    }
    // 로케일 기반 폴백:
    // 한국에서는 구글 사용 불가 → OSM 또는 네이버로 전환
    if (_provider == MapProvider.google && _isKoreanLocale) {
      _provider = isNaverAvailable ? MapProvider.naver : MapProvider.osm;
      debugPrint('🗺️ 한국 로케일 — Google 숨김 → ${_provider.name} 로 폴백');
      notifyListeners();
    }
    // 해외에서는 네이버 사용 불가 → OSM 또는 구글로 전환
    if (_provider == MapProvider.naver && !_isKoreanLocale) {
      _provider = isGoogleAvailable ? MapProvider.google : MapProvider.osm;
      debugPrint('🗺️ 해외 로케일 — Naver 숨김 → ${_provider.name} 로 폴백');
      notifyListeners();
    }
  }

  void _loadFromStorage() {
    try {
      final saved = HiveHelper.settingsBox.get(
        _storageKey,
        defaultValue: 'osm',
      );
      if (saved == 'naver') {
        _provider = MapProvider.naver;
      } else if (saved == 'google') {
        _provider = MapProvider.google;
      } else {
        _provider = MapProvider.osm;
      }
    } catch (e) {
      debugPrint('❌ MapProviderService load error: $e');
      _provider = MapProvider.osm;
    }
  }

  void setProvider(MapProvider newProvider) {
    if (newProvider == MapProvider.naver && !isNaverAvailable) {
      debugPrint('🗺️ Naver Maps not available');
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

  /// 현재 로케일에서 표시 가능한 제공자 목록
  /// 한국: Naver + OSM / 해외: Google + OSM
  List<MapProvider> get availableProviders => [
    if (isNaverAvailable) MapProvider.naver,
    if (isGoogleAvailable) MapProvider.google,
    MapProvider.osm,
  ];

  /// 순환 토글 (활성화된 것만)
  void toggle() {
    final available = availableProviders;
    if (available.length <= 1) return;
    final currentIdx = available.indexOf(_provider);
    final nextIdx = (currentIdx + 1) % available.length;
    setProvider(available[nextIdx]);
  }
}

// lib/services/map_provider_service.dart
// 맵 제공자 관리 서비스 (네이버맵 / 구글맵 / OSM 전환 + 킬스위치)

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/hive_helper.dart';

enum MapProvider { naver, google, osm }

class MapProviderService extends ChangeNotifier {
  static const String _storageKey = 'map_provider';

  MapProvider _provider = MapProvider.google;
  bool _isKoreanLocale = false;

  MapProvider get provider => _provider;
  bool get isNaver => _provider == MapProvider.naver;
  bool get isGoogle => _provider == MapProvider.google;
  bool get isOsm => _provider == MapProvider.osm;

  /// 네이버맵 전환 가능 여부 (한국 로케일 + 킬스위치)
  bool get isNaverAvailable => _isKoreanLocale && AppConfig.isNaverMapsEnabled;

  /// 구글맵 사용 가능 여부 (킬스위치)
  bool get isGoogleAvailable => AppConfig.isGoogleMapsEnabled;

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
  }

  void _loadFromStorage() {
    try {
      final saved = HiveHelper.settingsBox.get(
        _storageKey,
        defaultValue: 'google',
      );
      if (saved == 'naver') {
        _provider = MapProvider.naver;
      } else if (saved == 'osm') {
        _provider = MapProvider.osm;
      } else {
        _provider = MapProvider.google;
      }
    } catch (e) {
      debugPrint('❌ MapProviderService load error: $e');
      _provider = MapProvider.google;
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

  /// 순환 토글: naver → google → osm (활성화된 것만)
  void toggle() {
    final available = [
      if (isNaverAvailable) MapProvider.naver,
      if (isGoogleAvailable) MapProvider.google,
      MapProvider.osm, // OSM은 항상 포함
    ];
    if (available.length <= 1) return;
    final currentIdx = available.indexOf(_provider);
    final nextIdx = (currentIdx + 1) % available.length;
    setProvider(available[nextIdx]);
  }
}

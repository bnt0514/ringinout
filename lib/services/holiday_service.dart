import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:world_holidays/world_holidays.dart';

import 'hive_helper.dart';

class HolidayStatus {
  const HolidayStatus({
    required this.isHoliday,
    required this.isSubstituteOrTemporary,
    this.name,
  });

  final bool isHoliday;
  final bool isSubstituteOrTemporary;
  final String? name;
}

class HolidayService {
  HolidayService._();

  static final HolidayService instance = HolidayService._();

  /// world_holidays 패키지에서 지원하는 국가 목록
  static const List<String> supportedCountries = [
    'KR',
    'US',
    'JP',
    'CN',
    'VN',
    'MY',
    'TH',
    'CA',
    'BR',
    'TW',
    'DE',
    'FR',
    'ES',
    'IT',
    'NL',
    'SE',
    'PL',
    'GB',
  ];

  /// 국가코드 → 국기 이모지 매핑
  static const Map<String, String> countryFlags = {
    'KR': '🇰🇷',
    'US': '🇺🇸',
    'JP': '🇯🇵',
    'CN': '🇨🇳',
    'VN': '🇻🇳',
    'MY': '🇲🇾',
    'TH': '🇹🇭',
    'CA': '🇨🇦',
    'BR': '🇧🇷',
    'TW': '🇹🇼',
    'DE': '🇩🇪',
    'FR': '🇫🇷',
    'ES': '🇪🇸',
    'IT': '🇮🇹',
    'NL': '🇳🇱',
    'SE': '🇸🇪',
    'PL': '🇵🇱',
    'GB': '🇬🇧',
  };

  final WorldHolidays _worldHolidays = WorldHolidays();
  final Map<String, Future<List<Holiday>>> _yearHolidayCache = {};
  final Map<String, HolidayStatus> _dateStatusCache = {};

  /// GPS 역지오코딩으로 감지된 국가코드 캐시
  String? _detectedCountryCode;
  DateTime? _detectedAt;
  static const _detectionCacheDuration = Duration(hours: 6);

  /// 현재 적용할 국가코드를 반환
  /// 설정이 'auto'이면 GPS 기반 자동 감지, 아니면 설정값 사용
  Future<String> getEffectiveCountryCode() async {
    try {
      final setting = HiveHelper.getHolidayCountry();

      if (setting != 'auto') {
        if (supportedCountries.contains(setting)) {
          return setting;
        }
      }

      // auto 모드: GPS 기반 감지
      return await _detectCountryFromGPS();
    } catch (e) {
      debugPrint('❌ 국가코드 결정 실패, KR로 폴백: $e');
      return 'KR';
    }
  }

  /// GPS 현재 위치에서 국가코드를 감지
  Future<String> _detectCountryFromGPS() async {
    // 캐시가 유효하면 바로 반환
    if (_detectedCountryCode != null && _detectedAt != null) {
      if (DateTime.now().difference(_detectedAt!) < _detectionCacheDuration) {
        return _detectedCountryCode!;
      }
    }

    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final code = placemarks.first.isoCountryCode;
          if (code != null && supportedCountries.contains(code)) {
            _detectedCountryCode = code;
            _detectedAt = DateTime.now();
            debugPrint('🌍 GPS 국가 감지 성공: $code');
            return code;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ GPS 국가 감지 실패: $e');
    }

    // GPS 감지 실패 시 기존 캐시가 있으면 사용
    if (_detectedCountryCode != null) {
      return _detectedCountryCode!;
    }

    // 최종 폴백: KR
    return 'KR';
  }

  /// 현재 자동 감지된 국가코드를 반환 (설정 UI 표시용)
  Future<String?> getDetectedCountryCode() async {
    try {
      return await _detectCountryFromGPS();
    } catch (_) {
      return _detectedCountryCode;
    }
  }

  Future<HolidayStatus> getHolidayStatus(DateTime date) async {
    final countryCode = await getEffectiveCountryCode();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final cacheKey = '${countryCode}_${_dateKey(normalizedDate)}';
    final cached = _dateStatusCache[cacheKey];
    if (cached != null) {
      return cached;
    }

    try {
      final holidays = await _getYearHolidays(countryCode, normalizedDate.year);
      final matchedHoliday = holidays.cast<Holiday?>().firstWhere(
        (holiday) => holiday?.isOnDate(normalizedDate) ?? false,
        orElse: () => null,
      );

      final status =
          matchedHoliday == null
              ? const HolidayStatus(
                isHoliday: false,
                isSubstituteOrTemporary: false,
              )
              : HolidayStatus(
                isHoliday: true,
                isSubstituteOrTemporary: _isSubstituteOrTemporary(
                  matchedHoliday,
                ),
                name: matchedHoliday.name,
              );

      _dateStatusCache[cacheKey] = status;
      return status;
    } catch (_) {
      const status = HolidayStatus(
        isHoliday: false,
        isSubstituteOrTemporary: false,
      );
      _dateStatusCache[cacheKey] = status;
      return status;
    }
  }

  Future<List<Holiday>> _getYearHolidays(String countryCode, int year) {
    final cacheKey = '${countryCode}_$year';
    return _yearHolidayCache.putIfAbsent(
      cacheKey,
      () => _worldHolidays.getHolidays(countryCode, year: year),
    );
  }

  bool _isSubstituteOrTemporary(Holiday holiday) {
    final searchText =
        <String?>[
          holiday.name,
          holiday.descriptionEn,
          holiday.descriptionKo,
        ].whereType<String>().join(' ').toLowerCase();

    const markers = ['대체', '임시', 'substitute', 'temporary', 'observed'];

    return markers.any(searchText.contains);
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// 국가 변경 시 캐시 초기화
  void clearCache() {
    _yearHolidayCache.clear();
    _dateStatusCache.clear();
    debugPrint('🗑️ HolidayService 캐시 초기화 완료');
  }
}

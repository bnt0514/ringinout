// lib/utils/geocoding_cache.dart
// On-device geocoding cache — Hive 기반 영구 저장.
// 최대 20개 좌표-주소 쌍 보관, 초과 시 가장 오래된 항목 삭제(FIFO).
// Privacy: 서버 전송 없이 기기에서만 저장.

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class GeocodingCache {
  static final GeocodingCache _instance = GeocodingCache._();
  factory GeocodingCache() => _instance;
  GeocodingCache._();

  static const int _maxEntries = 20;
  static const String _boxName = 'geocoding_cache';

  Box? _box;

  /// 앱 시작 시 한 번 호출
  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// 좌표를 소수점 4자리(~11m)로 반올림하여 캐시 키 생성
  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// 캐시에서 주소 조회 (없으면 null)
  String? get(double lat, double lng) {
    if (_box == null || !_box!.isOpen) return null;
    final key = _key(lat, lng);
    return _box!.get(key) as String?;
  }

  /// 캐시에 주소 저장. 20개 초과 시 가장 먼저 저장된 항목 삭제.
  Future<void> put(double lat, double lng, String address) async {
    if (_box == null || !_box!.isOpen) return;
    final key = _key(lat, lng);

    // 이미 있으면 삭제 후 다시 추가 (순서 유지)
    if (_box!.containsKey(key)) {
      await _box!.delete(key);
    }

    // 용량 초과 시 가장 오래된(처음) 항목 삭제
    while (_box!.length >= _maxEntries) {
      final firstKey = _box!.keyAt(0);
      await _box!.delete(firstKey);
      debugPrint('🗑️ [GeoCache] 오래된 항목 삭제: $firstKey');
    }

    await _box!.put(key, address);
  }

  Future<void> clear() async => await _box?.clear();

  int get length => _box?.length ?? 0;
}

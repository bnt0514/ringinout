// lib/utils/geocoding_cache.dart
// On-device geocoding cache — Hive 기반 영구 저장.
//
// 특징:
// - 최대 500개 좌표-주소 쌍 보관 (LRU eviction)
// - 30일 TTL: 오래된 항목은 자동 만료/삭제 (Google/Naver Places 정책 준수)
// - Privacy: 서버 전송 없이 기기에서만 저장
//
// 마이그레이션: 기존 String 값 항목은 만료된 것으로 간주(읽기 시 미반영, put 시 신규 형식으로 덮어씀).

import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class GeocodingCache {
  static final GeocodingCache _instance = GeocodingCache._();
  factory GeocodingCache() => _instance;
  GeocodingCache._();

  /// 최대 항목 수 (LRU)
  static const int _maxEntries = 500;

  /// 항목 수명 (30일) — Google Places/Naver 정책 준수
  static const Duration _ttl = Duration(days: 30);

  static const String _boxName = 'geocoding_cache';
  static const String _kAddress = 'a';
  static const String _kTimestamp = 't';
  static const String _kUsedAt = 'u';

  Box? _box;

  /// 앱 시작 시 한 번 호출
  Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
    // 부팅 시 만료 항목 일괄 삭제 (베스트 에포트)
    await _purgeExpired();
  }

  /// 좌표를 소수점 4자리(~11m)로 반올림하여 캐시 키 생성
  static String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// 캐시에서 주소 조회 (없거나 만료면 null)
  String? get(double lat, double lng) {
    if (_box == null || !_box!.isOpen) return null;
    final key = _key(lat, lng);
    final raw = _box!.get(key);
    if (raw == null) return null;

    // 신규 형식: Map { a: address, t: createdAtMs, u: lastUsedMs }
    if (raw is Map) {
      final t = raw[_kTimestamp];
      if (t is int && _now() - t > _ttl.inMilliseconds) {
        // 만료 → 삭제 (await하지 않음, 동기 API 유지)
        _box!.delete(key);
        return null;
      }
      // LRU: lastUsedAt 갱신 (write이지만 LRU 정확도 위해 베스트 에포트)
      try {
        final updated = Map<String, dynamic>.from(raw);
        updated[_kUsedAt] = _now();
        _box!.put(key, updated);
      } catch (_) {}
      return raw[_kAddress] as String?;
    }

    // 구 형식 (String): 만료 처리 — 다음 put 때 신규 형식으로 갱신됨
    if (raw is String) {
      _box!.delete(key);
      return null;
    }

    return null;
  }

  /// 캐시에 주소 저장. 500개 초과 시 가장 오래 사용 안 된(LRU) 항목 삭제.
  Future<void> put(double lat, double lng, String address) async {
    if (_box == null || !_box!.isOpen) return;
    final key = _key(lat, lng);
    final now = _now();

    // 용량 초과 시 LRU eviction (이전 사용 시각 기준)
    while (_box!.length >= _maxEntries && !_box!.containsKey(key)) {
      final victimKey = _findLruKey();
      if (victimKey == null) break;
      await _box!.delete(victimKey);
      debugPrint('🗑️ [GeoCache] LRU eviction: $victimKey');
    }

    await _box!.put(key, <String, dynamic>{
      _kAddress: address,
      _kTimestamp: now,
      _kUsedAt: now,
    });
  }

  /// 만료(>30일) 항목 일괄 삭제
  Future<int> _purgeExpired() async {
    if (_box == null || !_box!.isOpen) return 0;
    final cutoff = _now() - _ttl.inMilliseconds;
    final toDelete = <dynamic>[];
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      if (raw is Map) {
        final t = raw[_kTimestamp];
        if (t is! int || t < cutoff) toDelete.add(key);
      } else {
        // 구 형식: 모두 삭제
        toDelete.add(key);
      }
    }
    if (toDelete.isNotEmpty) {
      await _box!.deleteAll(toDelete);
      debugPrint('🗑️ [GeoCache] 만료 항목 ${toDelete.length}건 삭제');
    }
    return toDelete.length;
  }

  /// 가장 오래 사용 안 된 항목 키 반환 (없으면 null)
  dynamic _findLruKey() {
    if (_box == null || !_box!.isOpen || _box!.isEmpty) return null;
    dynamic lruKey;
    int oldestUsedAt = 1 << 62;
    for (final key in _box!.keys) {
      final raw = _box!.get(key);
      int u;
      if (raw is Map) {
        final v = raw[_kUsedAt];
        u = (v is int) ? v : 0;
      } else {
        u = 0; // 구 형식은 즉시 evict 후보
      }
      if (u < oldestUsedAt) {
        oldestUsedAt = u;
        lruKey = key;
      }
    }
    return lruKey;
  }

  Future<void> clear() async => await _box?.clear();

  int get length => _box?.length ?? 0;
}

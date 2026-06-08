// lib/services/map_usage_service.dart
//
// 지도 + 지오코딩 사용량 추적 서비스
//
// - 기기 로컬(SharedPreferences)에 provider별 월간 카운트 저장
// - 주 1회 Firestore map_usage/{yyyy-MM} 에 increment 업로드
// - Firestore admin_config/map_settings 읽어서 킬스위치 적용
// - 개인별 지도 오픈 제한은 적용하지 않음
// - 전체 사용량이 무료 한도 80% 도달 시 무료 사용자만 자동 차단

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/hive_helper.dart';

/// 한 달치 전체 지도 사용량 통계 (Firestore에서 읽어온 값)
class MapUsageStats {
  final int google;
  final int naver;
  final int geoGoogleFwd;
  final int geoGoogleReverse;
  final int geoGooglePlace;
  final int geoNaverFwd;
  final int geoNaverReverse;
  final int geoNaverPlace;
  final DateTime fetchedAt;

  MapUsageStats({
    required this.google,
    required this.naver,
    this.geoGoogleFwd = 0,
    this.geoGoogleReverse = 0,
    this.geoGooglePlace = 0,
    this.geoNaverFwd = 0,
    this.geoNaverReverse = 0,
    this.geoNaverPlace = 0,
    required this.fetchedAt,
  });

  static MapUsageStats get empty =>
      MapUsageStats(google: 0, naver: 0, fetchedAt: DateTime(2000));

  /// Google Maps Platform 2026 pricing free usage caps.
  /// Mobile Maps SDK billing may appear as unlimited in Google's pricing table;
  /// this value is kept as a conservative Dynamic Maps safety cap for admin ops.
  static const int googleFreeLimit = 10000;
  static const int googleGeocodingCreditLimit = 10000;
  static const int googlePlacesTextCreditLimit = 5000;

  /// 네이버 NCP 월 무료 한도.
  static const int naverFreeLimit = 6000000;
  static const int naverGeocodingFreeLimit = 3000000;
  static const int naverReverseGeocodingFreeLimit = 3000000;
  static const int naverLocalSearchFreeLimit = 25000;

  double get googleUsageRatio => google / googleFreeLimit;
  double get naverUsageRatio => naver / naverFreeLimit;
}

/// 한 주의 지도 사용량 (Firestore map_usage_weekly/{yyyy-Www})
class WeeklyMapStats {
  final String week;
  final int google;
  final int naver;

  WeeklyMapStats({
    required this.week,
    required this.google,
    required this.naver,
  });

  int get total => google + naver;
}

// SharedPreferences 키
const _kLocalPrefix = 'map_local_';
const _kLastUploadKey = 'map_last_upload_date';
const _kFreeOpensPrefix = 'map_free_opens_';
const _kForceUploadCheckedKey = 'map_force_upload_checked';

// 지오코딩 호출 추적 키 (월별, 이 기기 발생분)
// geo_gfwd = Google forward, geo_gplace = Google place search
// geo_nfwd = Naver forward, geo_nrev = Naver reverse
const _kGeoGoogleFwd = 'geo_gfwd_'; // + month
const _kGeoGoogleReverse = 'geo_grev_'; // + month
const _kGeoGooglePlace = 'geo_gplace_'; // + month
const _kGeoNaverFwd = 'geo_nfwd_'; // + month
const _kGeoNaverRev = 'geo_nrev_'; // + month
const _kGeoNaverPlace = 'geo_nplace_'; // + month

/// 이전호환용 상수 — 실제 제한은 SubscriptionService.mapOpenMonthlyLimit 사용
/// (legacy only; current limits come from SubscriptionService)
@Deprecated('Use SubscriptionService.mapOpenMonthlyLimit(plan) instead')
const int kFreeMapOpenLimit = 20;

class MapUsageService {
  static const String _functionsBaseUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  // ──────────────────────────────────────────────
  // 전역 통계 캐시 (30분)
  // ──────────────────────────────────────────────
  static MapUsageStats _statsCache = MapUsageStats.empty;
  static DateTime _statsCacheTime = DateTime(2000);

  // ──────────────────────────────────────────────
  // 지도 로드 시 호출 — 로컬 카운트 증가 + 주1회 업로드 트리거
  // ──────────────────────────────────────────────
  static Future<void> onMapLoaded(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final month = _currentMonth();

    // 로컬 카운트 증가 (분석용)
    final key = '$_kLocalPrefix${provider}_$month';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);

    debugPrint('🗺️ [MapUsage] $provider +1 → ${current + 1} ($month)');

    // 무료 유저 오픈 카운트 증가 (제한용)
    await incrementFreeUserOpenCount(provider: provider);

    // 주 1회 업로드 체크
    await _maybeUploadToFirestore(prefs);
  }

  // ──────────────────────────────────────────────
  // 이번 달 지도 오픈 횟수 반환 (플랜 무관)
  // ──────────────────────────────────────────────
  static Future<int> getFreeUserOpenCount() async {
    return getMapOpenCount();
  }

  /// 이번 달 지도 오픈 횟수 반환 (모든 플랜 공통 카운터)
  static Future<int> getMapOpenCount() async {
    final uid = _currentOwnerKey();
    if (uid == null) return 0;
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kFreeOpensPrefix${uid}_${_currentMonth()}';
    return prefs.getInt(key) ?? 0;
  }

  /// 해당 provider로 지도를 열 수 있는지 확인.
  /// 개인별 월 제한은 없고, 전체 무료 한도 80% 도달 시 무료 사용자만 차단한다.
  static Future<bool> canOpenMap({String provider = 'naver'}) async {
    final plan = await SubscriptionService.getCurrentPlan();
    return SubscriptionService.canUseGeocoding(plan: plan, provider: provider);
  }

  /// 이전 호환용 — canOpenMap으로 대체
  static Future<bool> canFreeUserOpenMap({String provider = 'naver'}) =>
      canOpenMap(provider: provider);

  /// 지도 오픈 카운트 증가 (분석용). 개인별 제한에는 사용하지 않는다.
  static Future<void> incrementFreeUserOpenCount({
    String provider = 'naver',
  }) async {
    final uid = _currentOwnerKey();
    if (uid == null) return;
    final plan = await SubscriptionService.getCurrentPlan();

    final prefs = await SharedPreferences.getInstance();
    final key = '$_kFreeOpensPrefix${uid}_${_currentMonth()}';
    final current = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, current + 1);
    debugPrint(
      '🗺️ [MapUsage] ${plan.name} 오픈 ${current + 1} (provider: $provider)',
    );
  }

  // ──────────────────────────────────────────────
  // 전체 서비스 사용량 조회 (Firestore, 30분 캐시)
  // ──────────────────────────────────────────────
  static Future<MapUsageStats> getGlobalStats({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        now.difference(_statsCacheTime).inMinutes < 30 &&
        _statsCache != MapUsageStats.empty) {
      return _statsCache;
    }

    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('map_usage')
              .doc(_currentMonth())
              .get();
      final totals = Map<String, dynamic>.from(snap.data()?['totals'] ?? {});
      var google = (totals['google'] as num?)?.toInt() ?? 0;
      var naver = (totals['naver'] as num?)?.toInt() ?? 0;
      var geoGoogleFwd = (totals['geo_google_fwd'] as num?)?.toInt() ?? 0;
      var geoGoogleReverse = (totals['geo_google_rev'] as num?)?.toInt() ?? 0;
      var geoGooglePlace = (totals['geo_google_place'] as num?)?.toInt() ?? 0;
      var geoNaverFwd = (totals['geo_naver_fwd'] as num?)?.toInt() ?? 0;
      var geoNaverReverse = (totals['geo_naver_rev'] as num?)?.toInt() ?? 0;
      var geoNaverPlace = (totals['geo_naver_place'] as num?)?.toInt() ?? 0;
      if (totals.isEmpty) {
        final devicesSnap =
            await FirebaseFirestore.instance
                .collection('map_usage')
                .doc(_currentMonth())
                .collection('devices')
                .get();
        for (final doc in devicesSnap.docs) {
          final d = doc.data();
          google += (d['google'] as num?)?.toInt() ?? 0;
          naver += (d['naver'] as num?)?.toInt() ?? 0;
          geoGoogleFwd += (d['geo_google_fwd'] as num?)?.toInt() ?? 0;
          geoGoogleReverse += (d['geo_google_rev'] as num?)?.toInt() ?? 0;
          geoGooglePlace += (d['geo_google_place'] as num?)?.toInt() ?? 0;
          geoNaverFwd += (d['geo_naver_fwd'] as num?)?.toInt() ?? 0;
          geoNaverReverse += (d['geo_naver_rev'] as num?)?.toInt() ?? 0;
          geoNaverPlace += (d['geo_naver_place'] as num?)?.toInt() ?? 0;
        }
      }

      _statsCache = MapUsageStats(
        google: google,
        naver: naver,
        geoGoogleFwd: geoGoogleFwd,
        geoGoogleReverse: geoGoogleReverse,
        geoGooglePlace: geoGooglePlace,
        geoNaverFwd: geoNaverFwd,
        geoNaverReverse: geoNaverReverse,
        geoNaverPlace: geoNaverPlace,
        fetchedAt: now,
      );
      _statsCacheTime = now;

      await _checkAutoDisable(_statsCache);
      return _statsCache;
    } catch (e) {
      debugPrint('⚠️ [MapUsage] 전체 통계 조회 실패: $e');
      return _statsCache;
    }
  }

  // ──────────────────────────────────────────────
  // 킬스위치 설정 로드 (Firestore admin_config/map_settings)
  // ──────────────────────────────────────────────
  static Future<void> loadMapSettings() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('map_settings')
              .get();

      final data = doc.data() ?? {};
      AppConfig.isGoogleMapsEnabled = data['google_enabled'] as bool? ?? true;
      AppConfig.isNaverMapsEnabled = data['naver_enabled'] as bool? ?? true;
      AppConfig.isGeocodingEnabled = data['geocoding_enabled'] as bool? ?? true;
      // 맵이 꺼지면 지오코딩도 자동 차단
      if (!AppConfig.isGoogleMapsEnabled && !AppConfig.isNaverMapsEnabled) {
        AppConfig.isGeocodingEnabled = false;
      }

      // 무료 유저 선별 차단 적용
      SubscriptionService.setFreeUserBlock(
        naver: data['free_naver_blocked'] as bool? ?? false,
        google: data['free_google_blocked'] as bool? ?? false,
      );

      debugPrint(
        '🗺️ [MapSettings] Google=${AppConfig.isGoogleMapsEnabled}, '
        'Naver=${AppConfig.isNaverMapsEnabled}, '
        'Geocoding=${AppConfig.isGeocodingEnabled}, '
        'FreeNaverBlocked=${SubscriptionService.freeNaverBlocked}, '
        'FreeGoogleBlocked=${SubscriptionService.freeGoogleBlocked}',
      );
    } catch (e) {
      debugPrint('⚠️ [MapSettings] 설정 로드 실패 (기본값 사용): $e');
    }
  }

  // Admin: 구글/네이버 활성화 상태 변경
  static Future<void> setProviderEnabled(String provider, bool enabled) async {
    await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('map_settings')
        .set({'${provider}_enabled': enabled}, SetOptions(merge: true));

    if (provider == 'google') AppConfig.isGoogleMapsEnabled = enabled;
    if (provider == 'naver') AppConfig.isNaverMapsEnabled = enabled;

    debugPrint('🗺️ [Admin] $provider enabled=$enabled');
  }

  // Admin: 지오코딩 킬스위치 (지도 킬 시 자동 차단, 단독 차단도 가능)
  static Future<void> setGeocodingEnabled(bool enabled) async {
    await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('map_settings')
        .set({'geocoding_enabled': enabled}, SetOptions(merge: true));
    AppConfig.isGeocodingEnabled = enabled;
    debugPrint('🗺️ [Admin] geocoding enabled=$enabled');
  }

  // Admin: 무료 유저 선별 차단 (naver만, google만, 둘 다 선택 가능)
  static Future<void> setFreeProviderBlocked({
    bool? naver,
    bool? google,
  }) async {
    final patch = <String, dynamic>{};
    if (naver != null) patch['free_naver_blocked'] = naver;
    if (google != null) patch['free_google_blocked'] = google;
    if (patch.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('map_settings')
        .set(patch, SetOptions(merge: true));
    SubscriptionService.setFreeUserBlock(naver: naver, google: google);
    debugPrint('🗺️ [Admin] free block naver=$naver google=$google');
  }

  // ──────────────────────────────────────────────
  // 지오코딩 호출 추적 (SharedPreferences 월별 카운터)
  // ──────────────────────────────────────────────

  /// 지오코딩 API 호출 시 기록.
  static Future<void> trackGeocodingCall(String type) async {
    final month = _currentMonth();
    final prefs = await SharedPreferences.getInstance();
    final key = switch (type) {
      'google_fwd' => '$_kGeoGoogleFwd$month',
      'google_rev' => '$_kGeoGoogleReverse$month',
      'google_place' => '$_kGeoGooglePlace$month',
      'naver_fwd' => '$_kGeoNaverFwd$month',
      'naver_rev' => '$_kGeoNaverRev$month',
      'naver_place' => '$_kGeoNaverPlace$month',
      _ => null,
    };
    if (key == null) return;
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + 1);
  }

  /// 이번 달 지오코딩 로컬 카운트 전체 조회
  static Future<Map<String, int>> getLocalGeocodingCounts() async {
    final month = _currentMonth();
    final prefs = await SharedPreferences.getInstance();
    return {
      'google_fwd': prefs.getInt('$_kGeoGoogleFwd$month') ?? 0,
      'google_rev': prefs.getInt('$_kGeoGoogleReverse$month') ?? 0,
      'google_place': prefs.getInt('$_kGeoGooglePlace$month') ?? 0,
      'naver_fwd': prefs.getInt('$_kGeoNaverFwd$month') ?? 0,
      'naver_rev': prefs.getInt('$_kGeoNaverRev$month') ?? 0,
      'naver_place': prefs.getInt('$_kGeoNaverPlace$month') ?? 0,
    };
  }

  // ──────────────────────────────────────────────
  // 내부: 주 1회 Firestore 업로드
  // ──────────────────────────────────────────────
  static Future<void> _maybeUploadToFirestore(SharedPreferences prefs) async {
    final lastUploadStr = prefs.getString(_kLastUploadKey);
    final now = DateTime.now();

    if (lastUploadStr != null) {
      final lastUpload = DateTime.tryParse(lastUploadStr);
      if (lastUpload != null && now.difference(lastUpload).inDays < 7) {
        return; // 아직 7일 미경과
      }
    }

    await _uploadToFirestore(prefs);
    await prefs.setString(_kLastUploadKey, now.toIso8601String());
  }

  static Future<void> _uploadToFirestore(SharedPreferences prefs) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint('⚠️ [MapUsage] 로그인 상태 아님 — 업로드 스킵');
        return;
      }

      final month = _currentMonth();
      final week = _currentWeek();
      final google = prefs.getInt('${_kLocalPrefix}google_$month') ?? 0;
      final naver = prefs.getInt('${_kLocalPrefix}naver_$month') ?? 0;

      // 지오코딩 카운트
      final geoGFwd = prefs.getInt('$_kGeoGoogleFwd$month') ?? 0;
      final geoGRev = prefs.getInt('$_kGeoGoogleReverse$month') ?? 0;
      final geoGPlace = prefs.getInt('$_kGeoGooglePlace$month') ?? 0;
      final geoNFwd = prefs.getInt('$_kGeoNaverFwd$month') ?? 0;
      final geoNRev = prefs.getInt('$_kGeoNaverRev$month') ?? 0;
      final geoNPlace = prefs.getInt('$_kGeoNaverPlace$month') ?? 0;

      if (google == 0 &&
          naver == 0 &&
          geoGFwd == 0 &&
          geoGRev == 0 &&
          geoGPlace == 0 &&
          geoNFwd == 0 &&
          geoNRev == 0 &&
          geoNPlace == 0) {
        debugPrint('🗺️ [MapUsage] 업로드할 데이터 없음 — 스킵');
        return;
      }

      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) return;

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/uploadMapUsage'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'google': google,
          'naver': naver,
          'geo_google_fwd': geoGFwd,
          'geo_google_rev': geoGRev,
          'geo_google_place': geoGPlace,
          'geo_naver_fwd': geoNFwd,
          'geo_naver_rev': geoNRev,
          'geo_naver_place': geoNPlace,
        }),
      );

      if (response.statusCode >= 400) {
        throw Exception(
          'uploadMapUsage failed: ${response.statusCode} ${response.body}',
        );
      }

      debugPrint('🗺️ [MapUsage] Firestore 업로드 완료: G=$google N=$naver ($week)');
    } catch (e) {
      debugPrint('⚠️ [MapUsage] Firestore 업로드 실패: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────
  // 내부: 80% 도달 시 무료 사용자만 자동 차단
  // ──────────────────────────────────────────────
  static Future<void> _checkAutoDisable(MapUsageStats stats) async {
    const threshold = 0.80;
    bool changed = false;

    if (!SubscriptionService.freeGoogleBlocked &&
        stats.googleUsageRatio >= threshold) {
      debugPrint(
        '🚨 [MapUsage] Google Maps 80% 도달! (${stats.google}/${MapUsageStats.googleFreeLimit}) → Free 자동 차단',
      );
      await setFreeProviderBlocked(google: true);
      changed = true;
    }

    if (!SubscriptionService.freeNaverBlocked &&
        stats.naverUsageRatio >= threshold) {
      debugPrint(
        '🚨 [MapUsage] Naver Maps 80% 도달! (${stats.naver}/${MapUsageStats.naverFreeLimit}) → Free 자동 차단',
      );
      await setFreeProviderBlocked(naver: true);
      changed = true;
    }

    if (changed) {
      // 캐시 무효화
      _statsCacheTime = DateTime(2000);
    }
  }

  // ──────────────────────────────────────────────
  // 헬퍼
  // ──────────────────────────────────────────────
  static String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  static String? _currentOwnerKey() {
    final canonical = HiveHelper.storedActiveOwnerUid;
    if (canonical != null && canonical.isNotEmpty) return canonical;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  /// 이번 주 키 반환 — yyyy-Www 형식 (월요일 기준)
  static String _currentWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfYear = DateTime(monday.year, 1, 1);
    final dayOfYear = monday.difference(startOfYear).inDays + 1;
    final weekNum = ((dayOfYear - 1) ~/ 7) + 1;
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }

  /// 이번 달 로컬 누적 카운트 조회 (Admin 대시보드용)
  static Future<int> getLocalMonthlyCount(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final month = _currentMonth();
    return prefs.getInt('$_kLocalPrefix${provider}_$month') ?? 0;
  }

  /// 강제 업로드 (이 기기 / Admin용)
  static Future<void> forceUpload() async {
    final prefs = await SharedPreferences.getInstance();
    await _uploadToFirestore(prefs);
    await prefs.setString(_kLastUploadKey, DateTime.now().toIso8601String());
  }

  // ──────────────────────────────────────────────
  // Admin: 모든 클라이언트 강제 업로드 요청
  // ──────────────────────────────────────────────

  /// Admin이 Firestore에 강제 업로드 명령 기록 →
  /// 온라인 상태인 모든 기기가 포그라운드 복귀 시 즉시 업로드
  static Future<void> requestAllUsersUpload() async {
    await FirebaseFirestore.instance
        .collection('admin_config')
        .doc('commands')
        .set({
          'force_upload_at': FieldValue.serverTimestamp(),
          'requested_by': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        }, SetOptions(merge: true));
    debugPrint('🗺️ [Admin] 전체 강제 업로드 명령 전송 완료');
  }

  /// 앱 포그라운드 복귀 시 호출 — admin 강제 업로드 명령 확인 및 실행
  static Future<void> checkForceUploadCommand() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('commands')
              .get();
      if (!doc.exists) return;

      final forceAt = (doc.data()?['force_upload_at'] as Timestamp?)?.toDate();
      if (forceAt == null) return;

      final lastCheckStr = prefs.getString(_kForceUploadCheckedKey);
      final lastCheck =
          lastCheckStr != null ? DateTime.tryParse(lastCheckStr) : null;

      if (lastCheck == null || forceAt.isAfter(lastCheck)) {
        debugPrint('🗺️ [MapUsage] 어드민 강제 업로드 명령 감지 → 즉시 업로드');
        await _uploadToFirestore(prefs);
        final now = DateTime.now().toIso8601String();
        await prefs.setString(_kLastUploadKey, now);
        await prefs.setString(_kForceUploadCheckedKey, now);
      }
    } catch (e) {
      debugPrint('⚠️ [MapUsage] checkForceUploadCommand 실패: $e');
    }
  }

  // ──────────────────────────────────────────────
  // 주간 히스토리 (Admin 대시보드용)
  // ──────────────────────────────────────────────

  /// 최근 N주 사용량 조회 (Firestore map_usage_weekly 컬렉션)
  static Future<List<WeeklyMapStats>> getWeeklyHistory({int weeks = 6}) async {
    final results = <WeeklyMapStats>[];
    try {
      // 최근 N주 데이터 주간 ID 생성
      final weekIds = List.generate(weeks, (i) {
        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1 + i * 7));
        final startOfYear = DateTime(monday.year, 1, 1);
        final dayOfYear = monday.difference(startOfYear).inDays + 1;
        final weekNum = ((dayOfYear - 1) ~/ 7) + 1;
        return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
      });

      for (final weekId in weekIds) {
        final snap =
            await FirebaseFirestore.instance
                .collection('map_usage_weekly')
                .doc(weekId)
                .get();

        if (!snap.exists) continue;
        final totals = Map<String, dynamic>.from(snap.data()?['totals'] ?? {});
        var google = (totals['google'] as num?)?.toInt() ?? 0;
        var naver = (totals['naver'] as num?)?.toInt() ?? 0;
        if (totals.isEmpty) {
          final devicesSnap =
              await FirebaseFirestore.instance
                  .collection('map_usage_weekly')
                  .doc(weekId)
                  .collection('devices')
                  .get();
          for (final doc in devicesSnap.docs) {
            final d = doc.data();
            google += (d['google'] as num?)?.toInt() ?? 0;
            naver += (d['naver'] as num?)?.toInt() ?? 0;
          }
        }
        if (google == 0 && naver == 0) continue;
        results.add(WeeklyMapStats(week: weekId, google: google, naver: naver));
      }
    } catch (e) {
      debugPrint('⚠️ [MapUsage] getWeeklyHistory 실패: $e');
    }
    return results;
  }
}

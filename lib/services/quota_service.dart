// lib/services/quota_service.dart
//
// QuotaService — 무료/Plus/Pro 플랜별 "알람 발동" + "검색" 월간 사용량 관리
//
// 설계 원칙
// - 로컬(SharedPreferences)에 즉시 카운터 유지 → UI 차단/표시 빠름
// - 서버(Firestore `quotas/{uid}/months/{yyyy-MM}`)에 진실값 동기화 → 어드민 가시성 + 재설치 우회 방지
// - "보장 한도"(baseLimit) 초과 시 보상 크레딧으로 연장 가능
// - "어뷰징 캡"(absoluteCap) 도달 시 보상으로도 사용 불가
// - 보상 = 추후 리워드 광고 시청, 현재는 안내문 동의 대체
//
// 카테고리:
//   - search : 검색 (명칭/주소 통합)
//   - alarm  : 알람 발동
//
// SharedPreferences 키 포맷:
//   quota.search.used.{yyyy-MM}
//   quota.search.reward.{yyyy-MM}
//   quota.alarm.used.{yyyy-MM}
//   quota.alarm.reward.{yyyy-MM}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ringinout/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/services/hive_helper.dart';

/// 쿼터 체크 결과
enum QuotaStatus {
  /// 무료 보장 한도 내
  ok,

  /// 보장 한도 초과, 보상 크레딧으로 사용 가능 (1회 소비 예정)
  needsReward,

  /// 어뷰징 절대 캡 도달 — 보상으로도 사용 불가
  capped,
}

class QuotaCheck {
  final QuotaStatus status;
  final int used;
  final int baseLimit;
  final int absoluteCap;
  final int rewardCredits;

  const QuotaCheck({
    required this.status,
    required this.used,
    required this.baseLimit,
    required this.absoluteCap,
    required this.rewardCredits,
  });

  bool get allowed => status == QuotaStatus.ok;
  int get remainingBase => (baseLimit - used).clamp(0, baseLimit);
  int get remainingCap => (absoluteCap - used).clamp(0, absoluteCap);
}

enum QuotaCategory { search, alarm }

class QuotaService {
  static const String _functionsBaseUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  static const _kSearchUsed = 'quota.search.used.'; // + yyyy-MM
  static const _kSearchReward = 'quota.search.reward.'; // + yyyy-MM
  static const _kAlarmUsed = 'quota.alarm.used.';
  static const _kAlarmReward = 'quota.alarm.reward.';

  /// 일별 보상 획득 상한 (어뷰즈 방지)
  /// 익명 로그인 불가이므로 uid 기반이지만, 하루에 너무 많이 누르는 것도 방지
  static const int kDailyRewardMax = 20;
  static const _kRewardDaily = 'quota.reward.daily.'; // + yyyy-MM-dd

  // ──────────────────────────────────────────────
  // 체크 (UI에서 차단 여부 판단)
  // ──────────────────────────────────────────────

  static Future<QuotaCheck> check(QuotaCategory category) async {
    final plan = await SubscriptionService.getCurrentPlan();
    final base = _baseLimit(category, plan);
    final cap = _absoluteCap(category, plan);
    final used = await _getUsed(category);
    final rewards = await _getRewards(category);

    if (AppConfig.isBetaVersion) {
      return QuotaCheck(
        status: QuotaStatus.ok,
        used: used,
        baseLimit: base ?? cap,
        absoluteCap: cap,
        rewardCredits: rewards,
      );
    }

    // special 플랜: base가 null이면 무제한, 단 cap은 적용
    final effectiveBase = base ?? cap;
    final effectiveLimit = (effectiveBase + rewards).clamp(0, cap);

    QuotaStatus status;
    if (used < effectiveLimit) {
      status = QuotaStatus.ok;
    } else if (used >= cap) {
      status = QuotaStatus.capped;
    } else {
      status = QuotaStatus.needsReward;
    }

    return QuotaCheck(
      status: status,
      used: used,
      baseLimit: base ?? cap, // UI 표기용 (무제한이면 cap 표시)
      absoluteCap: cap,
      rewardCredits: rewards,
    );
  }

  // ──────────────────────────────────────────────
  // 기록 (실제 사용 직후 호출)
  // ──────────────────────────────────────────────

  /// 사용량 +1. 이미 cap 도달 시 false 반환(호출측에서 처리).
  static Future<bool> record(QuotaCategory category) async {
    final c = await check(category);
    if (c.status == QuotaStatus.capped) return false;

    final prefs = await SharedPreferences.getInstance();
    final month = _month();
    final key = _scopedKey(_usedKey(category), month);
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + 1);

    debugPrint(
      '📊 [Quota] ${category.name} +1 → ${cur + 1} / base=${c.baseLimit} '
      'reward=${c.rewardCredits} cap=${c.absoluteCap}',
    );

    // Firestore는 별도 async (비동기, 실패해도 UI 영향 없음)
    unawaited(_syncToFirestore(category, delta: 1, rewardDelta: 0));
    return true;
  }

  /// 사용량 -1 환불. 0 미만으로는 내려가지 않음.
  /// 오발동/잠시 멈춤처럼 "사용자가 의도적으로 dismiss한" 케이스에서 호출.
  /// Firestore도 동일하게 -1 sync (FieldValue.increment는 음수 허용).
  static Future<void> refund(QuotaCategory category) async {
    final prefs = await SharedPreferences.getInstance();
    final month = _month();
    final key = _scopedKey(_usedKey(category), month);
    final cur = prefs.getInt(key) ?? 0;
    if (cur <= 0) {
      debugPrint('💸 [Quota] ${category.name} 환불 스킵 (이미 0)');
      return;
    }
    await prefs.setInt(key, cur - 1);
    debugPrint('💸 [Quota] ${category.name} -1 → ${cur - 1} (refund)');
    unawaited(_syncToFirestore(category, delta: -1, rewardDelta: 0));
  }

  // ──────────────────────────────────────────────
  // 보상 지급
  // ──────────────────────────────────────────────

  /// 보상 크레딧 +amount. 일일 상한 검사 후 실제 지급량 반환 (0이면 지급 불가).
  static Future<int> grantReward(
    QuotaCategory category, {
    int amount = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey();
    final dailyKey = _scopedKey(_kRewardDaily, today);
    final dailyCount = prefs.getInt(dailyKey) ?? 0;
    if (dailyCount >= kDailyRewardMax) {
      debugPrint('🚫 [Quota] 일일 보상 상한 도달 ($dailyCount/$kDailyRewardMax)');
      return 0;
    }

    final month = _month();
    final key = _scopedKey(_rewardKey(category), month);
    final cur = prefs.getInt(key) ?? 0;
    await prefs.setInt(key, cur + amount);
    await prefs.setInt(dailyKey, dailyCount + 1);

    debugPrint(
      '🎁 [Quota] ${category.name} reward +$amount → ${cur + amount} '
      '(daily $dailyCount→${dailyCount + 1})',
    );

    unawaited(_syncToFirestore(category, delta: 0, rewardDelta: amount));
    return amount;
  }

  // ──────────────────────────────────────────────
  // 조회용 헬퍼
  // ──────────────────────────────────────────────

  static Future<int> getUsed(QuotaCategory category) => _getUsed(category);
  static Future<int> getRewards(QuotaCategory category) =>
      _getRewards(category);

  /// 오늘 지급된 보상 횟수 (일일 상한 UI 표시용)
  static Future<int> getTodayRewardGrants() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey(_kRewardDaily, _dateKey())) ?? 0;
  }

  // ──────────────────────────────────────────────
  // 한도 상수 (플랜별)
  // ──────────────────────────────────────────────

  /// 보장 한도 (null = 무제한, 단 absoluteCap은 항상 적용)
  static int? _baseLimit(QuotaCategory c, SubscriptionPlan plan) {
    if (plan == SubscriptionPlan.special) return null; // 무제한
    switch (c) {
      case QuotaCategory.search:
        return SubscriptionService.searchMonthlyBase(plan);
      case QuotaCategory.alarm:
        return SubscriptionService.alarmMonthlyBase(plan);
    }
  }

  /// 어뷰징 절대 캡
  static int _absoluteCap(QuotaCategory c, SubscriptionPlan plan) {
    switch (c) {
      case QuotaCategory.search:
        return SubscriptionService.searchMonthlyCap(plan);
      case QuotaCategory.alarm:
        return SubscriptionService.alarmMonthlyCap(plan);
    }
  }

  // ──────────────────────────────────────────────
  // 내부 유틸
  // ──────────────────────────────────────────────

  static String _usedKey(QuotaCategory c) =>
      c == QuotaCategory.search ? _kSearchUsed : _kAlarmUsed;

  static String _rewardKey(QuotaCategory c) =>
      c == QuotaCategory.search ? _kSearchReward : _kAlarmReward;

  static Future<int> _getUsed(QuotaCategory c) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey(_usedKey(c), _month())) ?? 0;
  }

  static Future<int> _getRewards(QuotaCategory c) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_scopedKey(_rewardKey(c), _month())) ?? 0;
  }

  static String _scopedKey(String prefix, String suffix) {
    final owner =
        HiveHelper.storedActiveOwnerUid ??
        FirebaseAuth.instance.currentUser?.uid ??
        'signed_out';
    return '$prefix$owner.$suffix';
  }

  static String _month() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  static String _dateKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  // ──────────────────────────────────────────────
  // Firestore 동기화 (서버 진실값 + 어드민 가시성)
  //   quotas/{uid}/months/{yyyy-MM}
  //   { search_used, search_reward, alarm_used, alarm_reward,
  //     plan_snapshot, last_updated }
  //
  //   + pools/{yyyy-MM}
  //   { search_total, alarm_total, last_updated }
  // ──────────────────────────────────────────────

  static Future<void> _syncToFirestore(
    QuotaCategory category, {
    required int delta,
    required int rewardDelta,
  }) async {
    try {
      if (delta < 0) {
        debugPrint('ℹ️ [Quota] 서버 환불 동기화는 보안상 생략합니다.');
      }

      for (var i = 0; i < delta; i++) {
        await _incrementQuotaOnServer(category, 'used');
      }
      for (var i = 0; i < rewardDelta; i++) {
        await _incrementQuotaOnServer(category, 'reward');
      }
    } catch (e) {
      debugPrint('⚠️ [Quota] Firestore 동기화 실패: $e');
    }
  }

  static Future<void> _incrementQuotaOnServer(
    QuotaCategory category,
    String kind,
  ) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) return;

    final response = await http.post(
      Uri.parse('$_functionsBaseUrl/incrementQuota'),
      headers: await SecureHttpHeaders.json(idToken: idToken),
      body: jsonEncode({'category': category.name, 'kind': kind}),
    );

    if (response.statusCode >= 400) {
      debugPrint(
        '⚠️ [Quota] 서버 쿼터 기록 실패: ${response.statusCode} ${response.body}',
      );
    }
  }

  // ──────────────────────────────────────────────
  // Admin: 글로벌 풀 조회 (어드민 대시보드용)
  // ──────────────────────────────────────────────

  /// 이번 달 전체 검색/알람 누적 (Firestore pools/{yyyy-MM})
  static Future<Map<String, int>> getGlobalPool() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('pools')
              .doc(_month())
              .get();
      final d = snap.data() ?? {};
      return {
        'search_total': (d['search_total'] as num?)?.toInt() ?? 0,
        'alarm_total': (d['alarm_total'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('⚠️ [Quota] 글로벌 풀 조회 실패: $e');
      return {'search_total': 0, 'alarm_total': 0};
    }
  }
}

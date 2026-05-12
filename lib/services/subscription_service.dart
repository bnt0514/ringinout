import 'package:flutter/foundation.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/hive_helper.dart';

enum SubscriptionPlan { free, plus, pro, special }

/// SubscriptionService - 구독 플랜 관리 (서버 기반)
///
/// ⚠️ 중요: 이 서비스는 BillingService를 통해 서버에서 플랜을 가져옵니다.
/// 로컬 SharedPreferences는 폴백용으로만 사용됩니다.
class SubscriptionService {
  static BillingService? _billingService;

  /// BillingService 인스턴스 설정 (앱 시작 시 호출)
  static void initialize(BillingService billingService) {
    _billingService = billingService;
  }

  /// 현재 플랜 가져오기 (서버 기반)
  static Future<SubscriptionPlan> getCurrentPlan() async {
    if (_billingService == null) {
      print('⚠️ BillingService not initialized, using free plan');
      return SubscriptionPlan.free;
    }

    try {
      await _billingService!.fetchStatus();
      return _billingService!.currentPlan;
    } catch (e) {
      print('⚠️ Failed to fetch plan from server: $e');
      return SubscriptionPlan.free; // 폴백
    }
  }

  /// 플랜 강제 새로고침
  static Future<SubscriptionPlan> refreshPlan() async {
    if (_billingService == null) {
      return SubscriptionPlan.free;
    }

    try {
      await _billingService!.fetchStatus(forceRefresh: true);
      return _billingService!.currentPlan;
    } catch (e) {
      print('⚠️ Failed to refresh plan: $e');
      return SubscriptionPlan.free;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 등록 제한은 폐기 (사용량 기반 모델로 전환)
  // placeLimit / alarmLimit은 @Deprecated 유지 — 기존 UI 호환용만 반환
  // ══════════════════════════════════════════════════════════════════

  @Deprecated('등록 개수 제한 폐기. QuotaService 기반 알람 발동 쿼터 사용.')
  static int? placeLimit(SubscriptionPlan plan) => null; // 무제한

  @Deprecated('등록 개수 제한 폐기. QuotaService 기반 알람 발동 쿼터 사용.')
  static int? alarmLimit(SubscriptionPlan plan) => null; // 무제한

  /// 맵 오픈 월별 제한 — 어뷰즈 방지용 (실제 비용은 검색에서 발생)
  /// - beta free: 무제한, free: 100, plus: 300, pro: 1000, special: 무제한
  static int? mapOpenMonthlyLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        if (AppConfig.isBetaVersion) return null;
        return 100;
      case SubscriptionPlan.plus:
        return 300;
      case SubscriptionPlan.pro:
        return 1000;
      case SubscriptionPlan.special:
        return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 검색 쿼터 (명칭 + 주소 통합)
  //   baseLimit = 보장 한도 (광고/보상 없이 제공)
  //   cap       = 어뷰징 절대 상한 (보상으로도 못 넘음)
  //   Pro 마케팅 표기: "대용량" (cap=150)
  // ══════════════════════════════════════════════════════════════════

  /// 보장 검색 횟수 (null = 무제한, special만 해당)
  static int? searchMonthlyBase(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        if (AppConfig.isBetaVersion) return 100000;
        return 5;
      case SubscriptionPlan.plus:
        return 30;
      case SubscriptionPlan.pro:
        return 150; // cap과 동일 = 실질 상한, 마케팅은 "대용량"
      case SubscriptionPlan.special:
        return null;
    }
  }

  /// 검색 절대 상한 (어뷰징 방지)
  static int searchMonthlyCap(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        if (AppConfig.isBetaVersion) return 100000;
        return 15;
      case SubscriptionPlan.plus:
        return 50;
      case SubscriptionPlan.pro:
        return 150;
      case SubscriptionPlan.special:
        return 100000; // 사실상 무제한
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 알람 발동 쿼터 (외부 API 비용 없음, 플랜 차별화용)
  // ══════════════════════════════════════════════════════════════════

  /// 보장 알람 발동 횟수
  static int? alarmMonthlyBase(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 30;
      case SubscriptionPlan.plus:
        return 100;
      case SubscriptionPlan.pro:
        return 500; // cap과 동일 = 실질 상한, 마케팅은 "대용량"
      case SubscriptionPlan.special:
        return null;
    }
  }

  /// 알람 발동 절대 상한
  static int alarmMonthlyCap(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        if (AppConfig.isBetaVersion) return 100000;
        return 30;
      case SubscriptionPlan.plus:
        return 200;
      case SubscriptionPlan.pro:
        return 500;
      case SubscriptionPlan.special:
        return 100000;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 무료 사용자 선택적 차단 (어드민 토글)
  //   admin_config/map_settings 에 free_*_blocked 플래그 추가
  //   여기선 AppConfig에서 읽어서 반환하는 헬퍼
  // ══════════════════════════════════════════════════════════════════

  /// 해당 플랜 + 제공자 조합에서 지오코딩을 사용할 수 있는지
  /// 어드민이 "무료만 차단" 토글을 켜면 Plus/Pro는 계속 사용 가능
  static bool canUseGeocoding({
    required SubscriptionPlan plan,
    required String provider, // 'google' or 'naver'
  }) {
    // 전체 킬스위치는 여기선 체크 안 함 (호출측에서 AppConfig 체크)
    // 여기선 "무료만 차단" 로직만
    if (plan != SubscriptionPlan.free) return true;
    if (provider == 'naver' && _freeNaverBlocked) return false;
    if (provider == 'google' && _freeGoogleBlocked) return false;
    return true;
  }

  // loadMapSettings에서 MapUsageService가 업데이트
  static bool _freeNaverBlocked = false;
  static bool _freeGoogleBlocked = false;

  static void setFreeUserBlock({bool? naver, bool? google}) {
    if (naver != null) _freeNaverBlocked = naver;
    if (google != null) _freeGoogleBlocked = google;
  }

  static bool get freeNaverBlocked => _freeNaverBlocked;
  static bool get freeGoogleBlocked => _freeGoogleBlocked;

  /// 인덱스가 한도 초과인지 여부 (초과분은 잠금 처리)
  /// items는 0번부터 순서대로, limit 이상 인덱스가 잠김
  static bool isIndexLocked(int index, int? limit) {
    if (limit == null) return false;
    return index >= limit;
  }

  static bool isAdFree(SubscriptionPlan plan) {
    return plan == SubscriptionPlan.plus ||
        plan == SubscriptionPlan.pro ||
        plan == SubscriptionPlan.special;
  }

  static Future<void> requestAdIfNeeded(SubscriptionPlan plan) async {
    if (plan == SubscriptionPlan.free) {
      await onAdRequest?.call();
    }
  }

  static Future<void> Function()? onAdRequest;

  /// 플랜 제한에 따라 초과 알람을 비활성화
  /// 유료 → 무료 전환 시 잠긴 알람이 계속 작동하는 것을 방지
  static Future<void> enforceAlarmLimits(SubscriptionPlan plan) async {
    try {
      if (!HiveHelper.isInitialized) return;

      final limit = alarmLimit(plan);
      if (limit == null) return; // 무제한 플랜

      final box = HiveHelper.alarmBox;
      int disabledCount = 0;

      for (int i = 0; i < box.length; i++) {
        if (i >= limit) {
          final alarm = box.getAt(i);
          if (alarm != null && alarm['enabled'] == true) {
            final updated = Map<String, dynamic>.from(alarm);
            updated['enabled'] = false;
            await box.putAt(i, updated);
            disabledCount++;
          }
        }
      }

      if (disabledCount > 0) {
        debugPrint(
          '🔒 Plan enforcement: disabled $disabledCount alarms '
          'exceeding limit of $limit (plan: $plan)',
        );
      }
    } catch (e) {
      debugPrint('❌ enforceAlarmLimits error: $e');
    }
  }

  /// 플랜 제한에 따라 초과 장소도 잠금 확인 (현재는 알람만 비활성화)
  /// 장소는 enabled 필드가 없으므로 UI 잠금만 유지
}

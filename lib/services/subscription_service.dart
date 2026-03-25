import 'package:flutter/foundation.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/hive_helper.dart';

enum SubscriptionPlan { free, basic, premium, special }

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

  static int? placeLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 2;
      case SubscriptionPlan.basic:
        return 5;
      case SubscriptionPlan.premium:
      case SubscriptionPlan.special:
        return null;
    }
  }

  /// 등록 가능한 알람 총 개수 (활성 여부 무관)
  static int? alarmLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 4;
      case SubscriptionPlan.basic:
        return 10;
      case SubscriptionPlan.premium:
      case SubscriptionPlan.special:
        return null;
    }
  }

  /// 맵 오픈 월별 제한 횟수
  static int? mapOpenMonthlyLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 20;
      case SubscriptionPlan.basic:
      case SubscriptionPlan.premium:
      case SubscriptionPlan.special:
        return null;
    }
  }

  /// 인덱스가 한도 초과인지 여부 (초과분은 잠금 처리)
  /// items는 0번부터 순서대로, limit 이상 인덱스가 잠김
  static bool isIndexLocked(int index, int? limit) {
    if (limit == null) return false;
    return index >= limit;
  }

  static bool isAdFree(SubscriptionPlan plan) {
    return plan == SubscriptionPlan.basic ||
        plan == SubscriptionPlan.premium ||
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

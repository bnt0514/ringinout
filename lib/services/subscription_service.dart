import 'package:ringinout/services/billing_service.dart';

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

  static int? activeAlarmLimit(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 2;
      case SubscriptionPlan.basic:
        return 10;
      case SubscriptionPlan.premium:
      case SubscriptionPlan.special:
        return null;
    }
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
}

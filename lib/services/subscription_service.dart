import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionPlan { free, basic, premium, special }

class SubscriptionService {
  static const String _planKey = 'subscription_plan';

  static Future<SubscriptionPlan> getCurrentPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_planKey);
    return _fromString(value);
  }

  static Future<void> setCurrentPlan(SubscriptionPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_planKey, plan.name);
  }

  static SubscriptionPlan _fromString(String? value) {
    switch (value) {
      case 'basic':
        return SubscriptionPlan.basic;
      case 'premium':
        return SubscriptionPlan.premium;
      case 'special':
        return SubscriptionPlan.special;
      default:
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

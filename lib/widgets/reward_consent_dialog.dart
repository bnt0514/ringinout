// lib/widgets/reward_consent_dialog.dart
//
// Free 플랜이 보장 한도를 초과했을 때 "안내문 읽고 동의" 방식으로 +1 크레딧 획득.
// (추후 리워드 광고로 대체 가능한 자리)

import 'package:flutter/material.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/quota_service.dart';
import 'package:ringinout/services/subscription_service.dart';

class RewardConsentDialog {
  /// 동의하고 +1 크레딧 지급 시 true, 취소/실패 시 false.
  static Future<bool> show(
    BuildContext context, {
    required QuotaCategory category,
  }) async {
    final l10n = AppLocalizations.of(context);
    final categoryLabel = l10n.get(
      category == QuotaCategory.search
          ? 'quota_search_label'
          : 'quota_alarm_label',
    );

    final check = await QuotaService.check(category);
    final todayGranted = await QuotaService.getTodayRewardGrants();
    final dailyLeft = QuotaService.kDailyRewardMax - todayGranted;

    if (!context.mounted) return false;

    // 일일 상한 도달 — 안내만
    if (dailyLeft <= 0) {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(l10n.get('reward_intro_title')),
            content: Text(
              l10n.getWithArgs('reward_daily_limit_reached', {
                'daily': QuotaService.kDailyRewardMax.toString(),
              }),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.get('close')),
              ),
            ],
          );
        },
      );
      return false;
    }

    final agreed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.get('quota_need_reward_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.getWithArgs('quota_need_reward_msg', {
                    'category': categoryLabel,
                    'base': check.baseLimit.toString(),
                    'daily': QuotaService.kDailyRewardMax.toString(),
                  }),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.get('reward_intro_body'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.get('reward_consent_cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.get('reward_consent_agree')),
            ),
          ],
        );
      },
    );

    if (agreed != true) return false;

    final granted = await QuotaService.grantReward(category);
    return granted > 0;
  }

  /// 캡 도달 시 "더 이상 사용 불가" 알림 + 업그레이드 안내.
  static Future<void> showCapped(
    BuildContext context, {
    required QuotaCategory category,
    required int cap,
  }) async {
    final l10n = AppLocalizations.of(context);
    final plan = await SubscriptionService.getCurrentPlan();
    if (!context.mounted) return;

    final categoryLabel = l10n.get(
      category == QuotaCategory.search
          ? 'quota_search_label'
          : 'quota_alarm_label',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.get('quota_capped_title')),
          content: Text(
            l10n.getWithArgs('quota_capped_msg', {
              'plan': plan.name.toUpperCase(),
              'category': categoryLabel,
              'cap': cap.toString(),
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.get('close')),
            ),
          ],
        );
      },
    );
  }
}

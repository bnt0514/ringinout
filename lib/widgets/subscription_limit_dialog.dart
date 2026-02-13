import 'package:flutter/material.dart';

import 'package:ringinout/pages/server_subscription_page.dart';
import 'package:ringinout/services/subscription_service.dart';

class SubscriptionLimitDialog {
  static Future<void> showPlaceLimit(
    BuildContext context, {
    required SubscriptionPlan plan,
    required int limit,
  }) {
    final title = '장소 등록 한도';
    final message =
        '${_planLabel(plan)} 플랜에서는 장소를 $limit개까지만 등록할 수 있습니다.\n기존 장소를 삭제하거나 업그레이드 해주세요.';
    return _show(context, title, message);
  }

  static Future<void> showAlarmLimit(
    BuildContext context, {
    required SubscriptionPlan plan,
    required int limit,
  }) {
    final title = '알람 등록 한도';
    final message =
        '${_planLabel(plan)} 플랜에서는 활성 알람을 $limit개까지만 설정할 수 있습니다.\n기존 알람을 삭제하거나 업그레이드 해주세요.';
    return _show(context, title, message);
  }

  static String _planLabel(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.basic:
        return 'Basic';
      case SubscriptionPlan.premium:
        return 'Premium';
      case SubscriptionPlan.special:
        return 'Special';
    }
  }

  static Future<void> _show(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ServerSubscriptionPage(),
                  ),
                );
              },
              child: const Text('구독 관리'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'package:ringinout/pages/server_subscription_page.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/subscription_service.dart';

class SubscriptionLimitDialog {
  static Future<void> showPlaceLimit(
    BuildContext context, {
    required SubscriptionPlan plan,
    required int limit,
  }) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.get('place_limit_title');
    final message = l10n.getWithArgs('place_limit_msg', {
      'plan': _planLabel(plan),
      'limit': limit.toString(),
    });
    return _show(context, title, message);
  }

  static Future<void> showAlarmLimit(
    BuildContext context, {
    required SubscriptionPlan plan,
    required int limit,
  }) {
    final l10n = AppLocalizations.of(context);
    final title = l10n.get('alarm_limit_title');
    final message = l10n.getWithArgs('alarm_limit_msg', {
      'plan': _planLabel(plan),
      'limit': limit.toString(),
    });
    return _show(context, title, message);
  }

  static String _planLabel(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.plus:
        return 'Plus';
      case SubscriptionPlan.pro:
        return 'Pro';
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
              child: Text(AppLocalizations.of(context).get('close_btn')),
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
              child: Text(
                AppLocalizations.of(context).get('subscription_mgmt_title'),
              ),
            ),
          ],
        );
      },
    );
  }
}

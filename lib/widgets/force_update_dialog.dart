// lib/widgets/force_update_dialog.dart
//
// 강제 업데이트 다이얼로그 — 닫기 없음, 업데이트 버튼만 존재.
// Play 스토어 내부 테스트 링크로 이동.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ringinout/services/app_localizations.dart';

class ForceUpdateDialog extends StatelessWidget {
  // 내부 테스트 링크 (Google Play 내부 테스트 URL)
  static const _storeUrl =
      'https://play.google.com/store/apps/details?id=com.bnt0514.ringinout';

  const ForceUpdateDialog({super.key});

  /// 강제 업데이트가 필요한 경우 호출. WillPopScope로 닫기 차단.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ForceUpdateDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false, // 뒤로가기로 닫기 차단
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update, color: Colors.blue),
            const SizedBox(width: 8),
            Text(l10n.get('force_update_title')),
          ],
        ),
        content: Text(l10n.get('force_update_body')),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.get('force_update_button')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final uri = Uri.parse(_storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}

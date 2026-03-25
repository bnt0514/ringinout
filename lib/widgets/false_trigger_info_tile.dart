// lib/widgets/false_trigger_info_tile.dart

import 'package:flutter/material.dart';
import 'package:ringinout/services/app_localizations.dart';

class FalseTriggerInfoTile extends StatelessWidget {
  const FalseTriggerInfoTile({super.key});

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber.shade700, size: 24),
                const SizedBox(width: 8),
                const Text(
                  '오발동 버튼이란?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              '알람이 울릴 때 "다시 울림", "알람 종료" 외에\n'
              '"⚡ 오발동" 버튼이 함께 표시됩니다.\n\n'
              '📡 GPS 신호 튐 현상 등으로 알람이\n'
              '잘못 울린 경우에 사용합니다.\n\n'
              '"오발동"을 누르면:\n'
              '  • 벨소리·진동이 즉시 멈춥니다\n'
              '  • 알람은 비활성화되지 않고 유지됩니다\n'
              '  • 처음부터 다시 발동 가능한 상태가 됩니다\n\n'
              '예) GPS가 잠깐 튀어 집 밖으로 인식된 경우,\n'
              '"오발동"을 누르면 알람이 유지되어\n'
              '실제로 나갈 때 다시 정상적으로 울립니다.',
              style: TextStyle(fontSize: 13.5, height: 1.55),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '확인',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _showDialog(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt, color: Colors.amber.shade700, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('false_trigger_info_title'),
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    l10n.get('false_trigger_info_subtitle'),
                    style: TextStyle(
                      color: Colors.amber.shade700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.amber.shade600, size: 18),
          ],
        ),
      ),
    );
  }
}

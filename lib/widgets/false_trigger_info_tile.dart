// lib/widgets/false_trigger_info_tile.dart

import 'package:flutter/material.dart';
import 'package:ringinout/services/app_localizations.dart';

class FalseTriggerInfoTile extends StatelessWidget {
  /// 'gps' (기본) 또는 'device' (블루투스 기기 알람 전용 문구)
  final String mode;

  const FalseTriggerInfoTile({super.key, this.mode = 'gps'});

  String _titleKey() =>
      mode == 'device'
          ? 'bt_false_trigger_info_title'
          : 'false_trigger_info_title';
  String _subtitleKey() =>
      mode == 'device'
          ? 'bt_false_trigger_info_subtitle'
          : 'false_trigger_info_subtitle';
  String _dialogTitleKey() =>
      mode == 'device'
          ? 'bt_false_trigger_dialog_title'
          : 'false_trigger_dialog_title';
  String _dialogBodyKey() =>
      mode == 'device'
          ? 'bt_false_trigger_dialog_body'
          : 'false_trigger_dialog_body';

  void _showDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                Text(
                  l10n.get(_dialogTitleKey()),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                l10n.get(_dialogBodyKey()),
                style: const TextStyle(fontSize: 13.5, height: 1.55),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  l10n.get('false_trigger_dialog_ok'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                    l10n.get(_titleKey()),
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    l10n.get(_subtitleKey()),
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

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/services/app_localizations.dart';

class ShowAlarmPopupPage extends StatefulWidget {
  final String alarmTitle;
  final Map<String, dynamic>? alarmData;

  const ShowAlarmPopupPage({
    super.key,
    required this.alarmTitle,
    this.alarmData,
  });

  @override
  State<ShowAlarmPopupPage> createState() => _ShowAlarmPopupPageState();
}

class _ShowAlarmPopupPageState extends State<ShowAlarmPopupPage> {
  static const platform = MethodChannel('flutter.bell');

  Future<void> _stopNativeRingtone() async {
    try {
      await platform.invokeMethod('stopSystemRingtone');
    } catch (e) {
      print('🔕 벨소리 정지 실패: $e');
    }
  }

  Future<void> _onSnooze() async {
    await _stopNativeRingtone();
    Navigator.of(context).pop('snooze');
  }

  Future<void> _onConfirm() async {
    final reallyExit = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).get('alarm_end_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).get('no_label')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(AppLocalizations.of(context).get('yes_label')),
              ),
            ],
          ),
    );

    if (reallyExit == true) {
      await _stopNativeRingtone();
      Navigator.of(context).pop('stop');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // ✅ 뒤로가기 차단
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        // 뒤로가기 무시
        print('🔙 알람 팝업 뒤로가기 차단됨');
      },
      child: Material(
        color: Colors.black.withValues(alpha: 0.8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                widget.alarmTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: _onSnooze,
              child: Text(
                AppLocalizations.of(context).get('snooze_btn'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            // ✅ 알람 종료 버튼 - 항상 표시
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: _onConfirm,
              child: Text(
                AppLocalizations.of(context).get('alarm_stop_btn'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

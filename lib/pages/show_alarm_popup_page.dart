import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';

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
            title: const Text("알람을 종료하시겠습니까?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("아니오"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("예"),
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
    return Material(
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
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            onPressed: _onSnooze,
            child: const Text('다시 울림', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 16),
          // ✅ 알람 종료 버튼 - 항상 표시
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            onPressed: _onConfirm,
            child: const Text('알람 종료', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

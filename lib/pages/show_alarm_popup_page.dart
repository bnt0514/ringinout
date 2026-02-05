import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

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
  static const platform = MethodChannel('com.example.ringinout/audio');
  int _triggerCount = 0;

  @override
  void initState() {
    super.initState();
    _increaseAndLoadTriggerCount();
  }

  Future<void> _increaseAndLoadTriggerCount() async {
    final id = widget.alarmData?['id'];
    if (id != null) {
      final box = await Hive.openBox('trigger_counts');
      final current = box.get(id, defaultValue: 0);
      await box.put(id, current + 1);
      setState(() {
        _triggerCount = current + 1;
      });
    }
  }

  Future<void> _stopNativeRingtone() async {
    try {
      await platform.invokeMethod('stopRingtone');
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
    final Size screenSize = MediaQuery.of(context).size;

    return Material(
      color: Colors.black.withOpacity(0.8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              widget.alarmTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            ),
            onPressed: _onSnooze,
            child: const Text('다시 울림', style: TextStyle(fontSize: 18)),
          ),
          if (_triggerCount >= 2) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: _onConfirm,
              child: const Text('알람 종료', style: TextStyle(fontSize: 18)),
            ),
          ],
        ],
      ),
    );
  }
}

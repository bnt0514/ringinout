import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:ringinout/services/hive_helper.dart';

class FullScreenAlarmPage extends StatefulWidget {
  final String alarmTitle;
  final String soundPath; // 사용하지 않지만, 구조 맞추기 위해 유지
  final Map<String, dynamic>? alarmData; // ✅ option
  final Future<void> Function() onDismiss;

  const FullScreenAlarmPage({
    super.key,
    required this.alarmTitle,
    required this.soundPath,
    this.alarmData, // ✅ optional
    required this.onDismiss,
  });

  @override
  State<FullScreenAlarmPage> createState() => _FullScreenAlarmPageState();
}

class _FullScreenAlarmPageState extends State<FullScreenAlarmPage> {
  static const platform = MethodChannel('com.example.ringinout/audio');
  static const bellPlatform = MethodChannel('flutter.bell');
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

  // ✅ 모든 사운드 정지 메서드
  Future<void> _stopAllSounds() async {
    try {
      // 1. 기존 네이티브 벨소리 정지
      await platform.invokeMethod('stopRingtone');
      print('🔕 네이티브 벨소리 정지 완료');
    } catch (e) {
      print('❌ 네이티브 벨소리 정지 실패: $e');
    }

    try {
      // 2. flutter.bell 채널 벨소리 정지
      await bellPlatform.invokeMethod('stopSystemRingtone');
      print('🔕 시스템 벨소리 정지 완료');
    } catch (e) {
      print('❌ 시스템 벨소리 정지 실패: $e');
    }

    try {
      // 3. AlarmNotificationHelper의 정지 메서드도 호출
      await widget.onDismiss();
      print('🔕 알람 정지 콜백 완료');
    } catch (e) {
      print('❌ 알람 정지 콜백 실패: $e');
    }
  }

  // ❌ 삭제: _stopNativeRingtone 메서드 제거 (사용되지 않음)

  // ✅ 추가: _recordGoalAchieved 메서드
  Future<void> _recordGoalAchieved(bool achieved) async {
    try {
      final box = await Hive.openBox('goal_achievements');
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await box.put(timestamp, {
        'alarm_title': widget.alarmTitle,
        'achieved': achieved,
        'timestamp': timestamp,
        'trigger_count': _triggerCount,
      });

      print('📊 목표 달성 기록: $achieved (알람: ${widget.alarmTitle})');
    } catch (e) {
      print('❌ 목표 달성 기록 실패: $e');
    }
  }

  Future<void> _disableAlarm(String alarmTitle) async {
    final box = HiveHelper.alarmBox;
    final alarms = box.values;
    for (var alarm in alarms) {
      if (alarm['name'] == alarmTitle && alarm['enabled'] == true) {
        alarm['enabled'] = false;
        alarm.delete('triggerCount');
        await alarm.save();
        final triggerBox = await Hive.openBox('trigger_counts');
        await triggerBox.delete(alarm['id']);
        print('🔕 알람 비활성화 완료 + triggerCount 제거');
        break;
      }
    }
  }

  Future<void> _saveSnoozeTime(int minutes) async {
    try {
      var box = await Hive.openBox('snoozeData');
      await box.put('lastSnoozeMinutes', minutes);
      print('✅ $minutes분 후 다시 울림 저장 완료');
    } catch (e) {
      print('💾 다시 울림 저장 실패: $e');
    }
  }

  Future<void> _onSnooze() async {
    // 즉시 모든 사운드 정지
    await _stopAllSounds();

    int? selectedMinutes = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("다시 울림 시간 선택"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[1, 3, 5, 10, 30].map(
                (m) => ListTile(
                  title: Text("$m분 후"),
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
              ListTile(
                title: const Text("직접 입력"),
                onTap: () async {
                  final controller = TextEditingController();
                  final result = await showDialog<int>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("다시 울림 시간 (분)"),
                          content: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: "예: 7"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                final input = int.tryParse(controller.text);
                                Navigator.pop(context, input);
                              },
                              child: const Text("확인"),
                            ),
                          ],
                        ),
                  );
                  if (result != null && result > 0) {
                    Navigator.pop(context, result);
                  }
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedMinutes != null && selectedMinutes > 0) {
      await _saveSnoozeTime(selectedMinutes);
      print("⏰ $selectedMinutes분 후 다시 울림 예약됨");
    }

    Navigator.of(context).pop();
  }

  Future<void> _onConfirm() async {
    // 즉시 모든 사운드 정지
    await _stopAllSounds();

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

    if (reallyExit != true) return;

    final goalAchieved = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("알람 목표를 달성하셨습니까?"),
            actions: [
              TextButton(
                onPressed: () {
                  _recordGoalAchieved(false);
                  Navigator.pop(context, false);
                },
                child: const Text("아니오"),
              ),
              TextButton(
                onPressed: () {
                  _recordGoalAchieved(true);
                  Navigator.pop(context, true);
                },
                child: const Text("예"),
              ),
            ],
          ),
    );

    if (goalAchieved != null) {
      await _disableAlarm(widget.alarmTitle);
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stopAllSounds(); // ✅ dispose에서도 모든 사운드 정지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: screenSize.height * 0.1,
              left: 20,
              right: 20,
              child: Text(
                widget.alarmTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Positioned(
              bottom: screenSize.height * (_triggerCount < 2 ? 0.2 : 0.4),
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: 250,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: _onSnooze,
                    child: const Text(
                      "다시 울림",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
            if (_triggerCount >= 2)
              Positioned(
                bottom: screenSize.height * 0.2,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 250,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: _onConfirm,
                      child: const Text(
                        "알람 종료",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

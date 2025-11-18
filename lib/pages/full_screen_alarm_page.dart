import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart'; // cancelAllAlarmNotifications() 사용
import 'package:ringinout/features/navigation/main_navigation.dart'; // ✅ 홈 화면 import

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
  static const bellPlatform = MethodChannel('flutter.bell');
  int _triggerCount = 0;

  @override
  void initState() {
    super.initState();
    _increaseAndLoadTriggerCount();
  }

  Future<void> _exitAlarmPageCompletely() async {
    // 1) 소리/벨/콜백 모두 정지
    try {
      await _stopAllSounds();
    } catch (e) {
      print('❌ 사운드 정지 실패: $e');
    }

    try {
      await cancelAllAlarmNotifications();
    } catch (e) {
      print('❌ 알림 취소 실패: $e');
    }

    if (!mounted) return;

    // 2) ✅ 홈화면으로 완전 교체 (Navigator 스택 초기화)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationPage()),
      (route) => false,
    );

    print('✅ 전체알람화면 종료 - 홈화면으로 복귀');
  }
  // _increaseAndLoadTriggerCount 메서드 수정

  Future<void> _increaseAndLoadTriggerCount() async {
    final id = widget.alarmData?['id'];
    if (id != null) {
      // ✅ v2로 변경
      final box = await Hive.openBox('trigger_counts_v2');

      final currentRaw = box.get(id, defaultValue: 0);
      final current =
          (currentRaw is int)
              ? currentRaw
              : int.tryParse(currentRaw.toString()) ?? 0;

      final newCount = current + 1;
      await box.put(id, newCount);

      if (mounted) {
        setState(() {
          _triggerCount = newCount;
        });
      }

      print('🔢 트리거 카운트: $newCount (알람 ID: $id)');
      print('📊 trigger_counts_v2[$id] = $newCount');
    } else {
      if (mounted) {
        setState(() {
          _triggerCount = 1;
        });
      }
      print('⚠️ alarmData가 없어 triggerCount를 1로 설정');
    }
  }

  // ✅ 모든 사운드 정지 메서드
  Future<void> _stopAllSounds() async {
    try {
      // ✅ flutter.bell 채널 벨소리 정지
      await bellPlatform.invokeMethod('stopSystemRingtone');
      print('🔕 시스템 벨소리 정지 완료');
    } catch (e) {
      print('❌ 시스템 벨소리 정지 실패: $e');
    }

    try {
      // ✅ AlarmNotificationHelper의 정지 메서드도 호출
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
    try {
      print('🔕 알람 비활성화 시작: $alarmTitle');

      final box = HiveHelper.alarmBox;
      final alarmsList = box.values.toList();

      for (var i = 0; i < alarmsList.length; i++) {
        final alarm = alarmsList[i];

        if (alarm['name'] == alarmTitle && alarm['enabled'] == true) {
          // ✅ Map을 복사하여 수정
          final updatedAlarm = Map<String, dynamic>.from(alarm);
          updatedAlarm['enabled'] = false;

          // ✅ alarmId 가져오기
          final alarmId = updatedAlarm['id'];
          if (alarmId == null) {
            print('❌ 알람 ID가 없음');
            continue;
          }

          // ✅ Hive 박스에서 해당 id를 키로 찾아서 업데이트
          final keys = box.keys.toList();
          for (var key in keys) {
            final item = box.get(key);
            if (item != null && item['id'] == alarmId) {
              await box.put(key, updatedAlarm);
              print('✅ 알람 비활성화 완료 (key: $key, id: $alarmId)');

              // ✅ 트리거 카운트 제거
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
              print('🗑️ 트리거 카운트 제거: $alarmId');

              // ✅ 스누즈 스케줄도 제거 (ID로 삭제)
              final snoozeBox = await Hive.openBox('snoozeSchedules');
              await snoozeBox.delete(alarmId);
              print('🗑️ 스누즈 스케줄 제거 (ID): $alarmId');

              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      print('❌ 알람 비활성화 실패: $e');
      print('스택 트레이스: ${StackTrace.current}');
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

  // ✅ 스누즈 알람 스케줄링 추가 (알람 ID를 키로 사용)
  Future<void> _scheduleSnoozeAlarm(int minutes) async {
    try {
      final snoozeTime = DateTime.now().add(Duration(minutes: minutes));

      // ✅ 알람 ID 추출
      final alarmId = widget.alarmData?['id'];
      if (alarmId == null) {
        print('❌ 알람 ID 없음 - 스누즈 스케줄링 불가');
        return;
      }

      // Hive에 스케줄 저장 (키를 ID로 변경)
      var box = await Hive.openBox('snoozeSchedules');
      await box.put(alarmId, {
        'alarmId': alarmId,
        'alarmTitle': widget.alarmTitle,
        'scheduledTime': snoozeTime.millisecondsSinceEpoch,
        'alarmData': widget.alarmData,
      });

      print(
        '⏰ 스누즈 알람 스케줄됨: ${widget.alarmTitle} (ID: $alarmId) at $snoozeTime',
      );
    } catch (e) {
      print('❌ 스누즈 알람 스케줄링 실패: $e');
    }
  }

  Future<void> _onSnooze() async {
    print('🔵 다시 울림 버튼 클릭');

    // ✅ 즉시 모든 사운드 정지
    await _stopAllSounds();

    // ✅ 사용자에게 시간 선택 다이얼로그 표시
    int? selectedMinutes = await showDialog<int>(
      context: context,
      barrierDismissible: false,
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
            ],
          ),
        );
      },
    );

    // ✅ 시간을 선택한 경우에만 처리
    if (selectedMinutes != null && selectedMinutes > 0) {
      await _saveSnoozeTime(selectedMinutes);
      await _scheduleSnoozeAlarm(selectedMinutes);

      print("⏰ $selectedMinutes분 후 다시 울림 예약됨");
    } else {
      print("! 다시 울림 취소됨");
    }

    // ✅ 선택 완료 후 알람 페이지 종료
    if (!mounted) return;
    await _exitAlarmPageCompletely();
  }

  Future<void> _onConfirm() async {
    print('🔴 알람 종료 버튼 클릭');

    // ✅ 즉시 모든 사운드 정지
    await _stopAllSounds();

    // ✅ 다이얼로그 없이 즉시 처리
    // 목표 달성은 true로 기록
    await _recordGoalAchieved(true);

    print('✅ 목표 달성으로 기록');

    // 알람 비활성화
    await _disableAlarm(widget.alarmTitle);

    // ✅ 즉시 알람 페이지 종료
    if (!mounted) return;
    await _exitAlarmPageCompletely();
  }

  @override
  void dispose() {
    _stopAllSounds(); // ✅ dispose에서도 모든 사운드 정지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    // ✅ PopScope로 Scaffold 전체를 감싸기
    return PopScope(
      canPop: true, // ✅ true = 뒤로가기 허용
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          // ✅ 뒤로가기로 닫힐 때 알람 정지
          print('🔙 뒤로가기 버튼 - 알람 정지');
          await _stopAllSounds();
          await cancelAllAlarmNotifications();
          print('✅ 알람 정지 완료');
        }
      },
      child: Scaffold(
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
      ),
    );
  }
} // ✅ _FullScreenAlarmPageState 클래스 끝

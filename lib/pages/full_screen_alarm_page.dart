import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart'; // cancelAllAlarmNotifications() 사용
import 'package:ringinout/features/navigation/main_navigation.dart'; // ✅ 홈 화면 import
import 'package:ringinout/services/location_monitor_service.dart'; // ✅ Heartbeat 전송용

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
  static const _smartChannel = MethodChannel(
    'com.example.ringinout/smart_location',
  );
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

  Future<void> _disableAlarm(String alarmId) async {
    try {
      print('🔕 알람 비활성화 시작 (ID): $alarmId');

      final box = HiveHelper.alarmBox;

      // ✅ Hive 키 = 알람 ID → 직접 조회
      final alarm = box.get(alarmId);
      if (alarm == null) {
        print('⚠️ 알람을 찾을 수 없음 (ID: $alarmId)');
        return;
      }

      final updatedAlarm = Map<String, dynamic>.from(alarm);
      updatedAlarm['enabled'] = false;
      updatedAlarm['snoozePending'] = false;
      await box.put(alarmId, updatedAlarm);
      print('✅ 알람 비활성화 완료 (id: $alarmId)');

      // ✅ 트리거 카운트 제거
      final triggerBox = await Hive.openBox('trigger_counts_v2');
      await triggerBox.delete(alarmId);
      print('🗑️ 트리거 카운트 제거: $alarmId');

      // ✅ 스누즈 스케줄도 제거
      final snoozeBox = await Hive.openBox('snoozeSchedules');
      await snoozeBox.delete(alarmId);
      print('🗑️ 스누즈 스케줄 제거: $alarmId');

      // ✅ Watchdog heartbeat 전송
      await LocationMonitorService.sendWatchdogHeartbeat();
      print('💓 알람 비활성화 후 Heartbeat 전송');
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
      barrierDismissible: true,
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
      // ★ 스누즈: 지금 비활성화 → n분 후 재트리거
      final alarmId = widget.alarmData?['id'];
      if (alarmId != null) {
        await _disableAlarm(alarmId);
      }
      await _saveSnoozeTime(selectedMinutes);
      await _scheduleSnoozeAlarm(selectedMinutes);

      print("⏰ $selectedMinutes분 후 다시 울림 예약됨");

      // ✅ 선택 완료 후 알람 페이지 종료
      if (!mounted) return;
      await _exitAlarmPageCompletely();
    } else {
      // ★ 취소/미선택 → 알람 화면으로 돌아감 (종료하지 않음)
      print("! 다시 울림 취소됨 → 알람 화면 유지");
      // 소리 다시 재생 (사용자가 아직 선택 안 했으므로)
      try {
        await bellPlatform.invokeMethod('playSystemRingtone');
      } catch (_) {}
    }
  }

  Future<void> _onConfirm() async {
    print('🔴 알람 종료 버튼 클릭');

    // ✅ 즉시 모든 사운드 정지
    await _stopAllSounds();

    // ✅ 다이얼로그 없이 즉시 처리
    // 목표 달성은 true로 기록
    await _recordGoalAchieved(true);

    print('✅ 목표 달성으로 기록');

    // 알람 비활성화 (ID로 정확히 매칭)
    final alarmId = widget.alarmData?['id'];
    if (alarmId != null) {
      await _disableAlarm(alarmId);

      // ✅ SmartLocationManager에도 dismiss 처리 (GateState DISABLED → 반복 알람 차단)
      try {
        await _smartChannel.invokeMethod('dismissAlarm', {'placeId': alarmId});
        print('✅ dismissAlarm 완료: $alarmId');
      } catch (e) {
        print('⚠️ dismissAlarm 채널 실패 (무시): $e');
      }
    } else {
      print('⚠️ 알람 ID 없음 - 비활성화 스킵');
    }

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
      canPop: false, // ✅ 뒤로가기 차단 — 반드시 다시 울림/알람 종료 선택
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // 뒤로가기 무시 — 사용자가 반드시 버튼을 눌러야 함
        print('🔙 뒤로가기 차단됨 — 다시 울림 또는 알람 종료를 선택하세요');
      },
      child: Scaffold(
        backgroundColor: AppColors.textPrimary,
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
                    color: AppColors.textOnPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // ✅ 다시 울림 버튼
              Positioned(
                bottom: screenSize.height * 0.40,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 250,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _onSnooze,
                      child: const Text(
                        "다시 울림",
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // ✅ 알람 종료 버튼
              Positioned(
                bottom: screenSize.height * 0.25,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: 250,
                    height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                      ),
                      onPressed: _onConfirm,
                      child: const Text(
                        "알람 종료",
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.textOnPrimary,
                        ),
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

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart'; // cancelAllAlarmNotifications() 사용
import 'package:ringinout/features/navigation/main_navigation.dart'; // ✅ 홈 화면 import
import 'package:ringinout/services/location_monitor_service.dart'; // ✅ Heartbeat 전송용
import 'package:ringinout/services/active_alarm_state.dart'; // ✅ 활성 알람 상태 추적
import 'package:ringinout/services/quota_service.dart'; // ✅ 오발동/잠시멈춤 시 환불
import 'package:ringinout/services/smart_location_service.dart'; // ✅ 오발동 후 장소 상태 복원
import 'package:ringinout/services/app_localizations.dart';

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
    'com.bnt0514.ringinout/smart_location',
  );
  int _triggerCount = 0;

  @override
  void initState() {
    super.initState();
    // ✅ 포그라운드 복귀 시 복원인지 체크 (트리거 카운트 중복 방지)
    final isRestored =
        ActiveAlarmState.isActive &&
        ActiveAlarmState.alarmData?['id'] == widget.alarmData?['id'];

    // ✅ 활성 알람 상태 등록 (포그라운드 복귀 시 복원용)
    ActiveAlarmState.setActive(
      alarmTitle: widget.alarmTitle,
      alarmData: widget.alarmData,
      soundPath: widget.soundPath,
    );

    if (!isRestored) {
      _increaseAndLoadTriggerCount();
    } else {
      // 복원 시에는 기존 트리거 카운트만 로드
      _loadTriggerCountOnly();
    }
  }

  /// 트리거 카운트 로드만 (증가 없이)
  Future<void> _loadTriggerCountOnly() async {
    final id = widget.alarmData?['id'];
    if (id != null) {
      final box = await Hive.openBox('trigger_counts_v2');
      final currentRaw = box.get(id, defaultValue: 0);
      final current =
          (currentRaw is int)
              ? currentRaw
              : int.tryParse(currentRaw.toString()) ?? 0;
      if (mounted) {
        setState(() {
          _triggerCount = current;
        });
      }
    }
  }

  Future<void> _exitAlarmPageCompletely() async {
    // ✅ 활성 알람 상태 해제
    ActiveAlarmState.clear();

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

    // 2) ✅ 알람 스택 지원: pop으로 이전 화면으로 돌아감
    // 이전 화면이 없으면 (최초 알람) 홈화면으로 완전 교체
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      print('✅ 알람화면 pop — 이전 화면으로 복귀');
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (route) => false,
      );
      print('✅ 전체알람화면 종료 - 홈화면으로 복귀');
    }
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

  /// ✅ 반복 알람 여부 확인 헬퍼
  bool get _isRepeatAlarm {
    final repeat = widget.alarmData?['repeat'];
    return (repeat is List && repeat.isNotEmpty);
  }

  Future<void> _disableAlarm(String alarmId) async {
    try {
      // ✅ 위치 알람 또는 기기 알람 모두 처리
      final locationBox = HiveHelper.alarmBox;
      final deviceBox = HiveHelper.deviceAlarmBox;

      final isDeviceAlarm =
          !locationBox.containsKey(alarmId) && deviceBox.containsKey(alarmId);
      final box = isDeviceAlarm ? deviceBox : locationBox;

      // ✅ Hive 키 = 알람 ID → 직접 조회
      final alarm = box.get(alarmId);
      if (alarm == null) {
        print('⚠️ 알람을 찾을 수 없음 (ID: $alarmId)');
        return;
      }

      final updatedAlarm = Map<String, dynamic>.from(alarm);

      // ✅ 반복 알람이면 enabled=false 하지 않음! (내일 다시 울려야 함)
      // 기기 알람은 repeat 개념이 없으므로 항상 enabled=false
      if (_isRepeatAlarm && !isDeviceAlarm) {
        updatedAlarm['snoozePending'] = false;
        await box.put(alarmId, updatedAlarm);
        print('🔄 반복 알람 — enabled 유지 (비활성화 스킵): $alarmId');
      } else {
        updatedAlarm['enabled'] = false;
        updatedAlarm['snoozePending'] = false;
        await box.put(alarmId, updatedAlarm);
        print('✅ ${isDeviceAlarm ? "기기" : "일회성"} 알람 비활성화 완료 (id: $alarmId)');

        // ✅ 트리거 카운트 제거 (일회성/기기 알람)
        final triggerBox = await Hive.openBox('trigger_counts_v2');
        await triggerBox.delete(alarmId);
        print('🗑️ 트리거 카운트 제거: $alarmId');
      }

      // ✅ 스누즈 스케줄 제거 (반복/일회 모두)
      final snoozeBox = await Hive.openBox('snoozeSchedules');
      await snoozeBox.delete(alarmId);
      print('🗑️ 스누즈 스케줄 제거: $alarmId');

      // ✅ Watchdog heartbeat 전송
      await LocationMonitorService.sendWatchdogHeartbeat();
      print('💓 알람 처리 후 Heartbeat 전송');
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

      final alarmBox = HiveHelper.alarmBox;
      final alarm = alarmBox.get(alarmId);
      if (alarm is Map) {
        final updatedAlarm = Map<String, dynamic>.from(alarm);
        // ✅ 반복 알람이면 enabled=true 유지
        if (!_isRepeatAlarm) {
          updatedAlarm['enabled'] = false;
        }
        updatedAlarm['snoozePending'] = true;
        await alarmBox.put(alarmId, updatedAlarm);
      }

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
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.get('snooze_time_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[1, 3, 5, 10, 30].map(
                (m) => ListTile(
                  title: Text(l10n.getWithArgs('snooze_min', {'m': '$m'})),
                  onTap: () => Navigator.pop(ctx, m),
                ),
              ),
              ListTile(
                title: Text(l10n.get('snooze_min_custom')),
                trailing: const Icon(Icons.edit, size: 18),
                onTap: () async {
                  final custom = await _showCustomSnoozeDialog();
                  if (custom != null && custom > 0) {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, custom);
                  }
                },
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

      // ✅ SmartLocationManager에도 dismiss 처리
      // 반복 알람: 당일 재트리거만 방지 (alarm_triggered_date로 이미 관리됨)
      // 일회성 알람: GateState DISABLED
      try {
        await _smartChannel.invokeMethod('dismissAlarm', {'alarmKey': alarmId});
        print('✅ dismissAlarm 완료: $alarmId (반복: $_isRepeatAlarm)');
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

  /// ⚡ 오발동 처리
  /// 소리만 끄고, 알람은 활성(enabled=true) 상태 그대로 유지
  /// 반복 알람: 당일 트리거 기록 + 쿨다운 초기화 (같은 날 재트리거 허용)
  Future<void> _onFalseTrigger() async {
    print('⚡ 오발동 버튼 클릭 - 소리만 끄고 알람 유지');

    // 1. 소리/진동 즉시 정지
    await _stopAllSounds();
    await cancelAllAlarmNotifications();

    // 2. 트리거 카운트 원복 (발동 안 된 것쳄럼 재설정)
    final alarmId = widget.alarmData?['id'];
    if (alarmId != null) {
      // 2-0. 월간 quota도 환불 (알람이 트리거될 때 QuotaService.record(alarm)이 호출되었으므로)
      try {
        await QuotaService.refund(QuotaCategory.alarm);
      } catch (e) {
        print('⚠️ 오발동 quota 환불 실패 (무시): $e');
      }
      final box = await Hive.openBox('trigger_counts_v2');
      final currentRaw = box.get(alarmId, defaultValue: 0);
      final current =
          (currentRaw is int)
              ? currentRaw
              : int.tryParse(currentRaw.toString()) ?? 0;
      if (current > 0) {
        await box.put(alarmId, current - 1);
        print('⚡ 트리거 카운트 원복: $current → ${current - 1}');
      }

      // 3. 당일 트리거 기록 + 쿨다운 모두 초기화 (오발동 = 트리거 안 된 것으로 처리)
      //    Wi-Fi 일시 끊김 보호는 WifiMonitorManager의 15초 임계값이 처리함
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_triggered_date_$alarmId');
        await prefs.remove('cooldown_until_$alarmId');
        print('⚡ 당일 트리거 기록 + 쿨다운 초기화: $alarmId');
      } catch (e) {
        print('⚠️ 오발동 SharedPrefs 초기화 실패: $e');
      }

      // 4. 일회성 알람이면 enabled=true 복원 (트리거 시 disabled 되었으므로)
      try {
        final hiveBox = HiveHelper.alarmBox;
        final current = hiveBox.get(alarmId);
        if (current != null) {
          final repeat = current['repeat'];
          final isRepeat = (repeat is List && repeat.isNotEmpty);
          if (!isRepeat && current['enabled'] != true) {
            final updated = Map<String, dynamic>.from(current);
            updated['enabled'] = true;
            await hiveBox.put(alarmId, updated);
            print('⚡ 일회성 알람 enabled=true 복원: $alarmId');
          }
        }
      } catch (e) {
        print('⚠️ 오발동 알람 복원 실패: $e');
      }

      // 5. ★ LMS 장소 상태를 GPS 기반으로 즉시 재판단
      //    오발동 = "나는 여전히 여기 있는데 잘못 울렸다" → insideIdle로 복원해야 함
      //    (outside로 굳어지면 Wi-Fi 재연결 시 진입 알람이 또 울릴 수 있음)
      try {
        final placeId =
            widget.alarmData?['placeId']?.toString() ??
            widget.alarmData?['place']?.toString() ??
            widget.alarmData?['locationName']?.toString();
        if (placeId != null && placeId.isNotEmpty) {
          await SmartLocationService.clearTriggeredAlarm(placeId);
          print('⚡ 오발동 — LMS 장소 상태 GPS 기반 재판단: $placeId');
        }
      } catch (e) {
        print('⚠️ 오발동 LMS 상태 복원 실패: $e');
      }
    }

    // 6. 화면 상태 해제 (enabled 필드는 터치 안 함)
    ActiveAlarmState.clear();

    print('✅ 오발동 처리 완료 - 알람 enabled=true 유지, 상태 재판단 완료');

    // 4. 이전 화면으로 복귀 (알람 스택 지원)
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      print('✅ 오발동 — 이전 알람 화면으로 복귀');
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (route) => false,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ⏸️ 잠시 멈춤 (Pause)
  //
  //  오발동과 다른 점: 사용자가 N분 동안 같은 트리거 타입(entry/exit)을
  //  완전히 차단. 반경 근처에서 활동할 때 진입/이탈 반복 발동을 막음.
  //
  //  - 발동된 트리거 타입(entry/exit)만 차단 → 상대 트리거는 정상 동작
  //  - quota 환불 (오발동과 동일)
  //  - 같은 장소에서 2회째 잠시 멈춤 시 안내 다이얼로그 자동 노출
  // ═══════════════════════════════════════════════════════════

  Future<void> _onPause() async {
    print('⏸️ 잠시 멈춤 버튼 클릭');

    // 1. 사운드/진동 즉시 정지 (다이얼로그 띄우기 전)
    await _stopAllSounds();
    await cancelAllAlarmNotifications();

    // 2. 시간 선택 다이얼로그 표시
    final selectedMinutes = await _showPauseTimeDialog();
    if (selectedMinutes == null || selectedMinutes <= 0) {
      // 취소: 사운드 다시 재생 (사용자가 결정 안 함)
      print('! 잠시 멈춤 취소됨 → 알람 화면 유지');
      try {
        await bellPlatform.invokeMethod('playSystemRingtone');
      } catch (_) {}
      return;
    }

    // 3. 마지막 선택 시간 저장 (다음 다이얼로그 기본값용)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastPauseMinutes', selectedMinutes);
    } catch (_) {}

    // 4. pause_until_{trigger}_{alarmId} 설정 — LMS가 평가 시 차단
    final alarmId = widget.alarmData?['id']?.toString();
    final trigger =
        (widget.alarmData?['trigger'] as String?)?.toLowerCase() ?? 'entry';
    if (alarmId != null && alarmId.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final pauseUntilMs =
            DateTime.now().millisecondsSinceEpoch +
            (selectedMinutes * 60 * 1000);
        await prefs.setInt('pause_until_${trigger}_$alarmId', pauseUntilMs);
        print(
          '⏸️ pause_until_${trigger}_$alarmId 설정: $pauseUntilMs ($selectedMinutes분 후)',
        );
      } catch (e) {
        print('⚠️ pause_until 저장 실패: $e');
      }
    }

    // 5. 오발동과 동일한 후처리 (quota 환불, 카운트 원복, 활성화 복원, LMS 재판단)
    await _onFalseTriggerCleanup();

    // 6. 토스트로 사용자 피드백
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final toastKey =
        trigger == 'exit' ? 'pause_toast_exit' : 'pause_toast_entry';
    final minLabel = l10n.getWithArgs('pause_min_value', {
      'm': '$selectedMinutes',
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.getWithArgs(toastKey, {'time': minLabel})),
        duration: const Duration(seconds: 2),
      ),
    );

    // 7. 같은 장소에서 잠시 멈춤 횟수 카운트 → 2회째에 안내 다이얼로그 자동 노출
    final placeKey = _placeKeyForCoaching();
    bool shouldShowCoaching = false;
    if (placeKey != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cntKey = 'pause_count_$placeKey';
        final cur = prefs.getInt(cntKey) ?? 0;
        final next = cur + 1;
        await prefs.setInt(cntKey, next);

        final shownKey = 'pause_coaching_shown_$placeKey';
        final alreadyShown = prefs.getBool(shownKey) ?? false;
        if (next >= 2 && !alreadyShown) {
          shouldShowCoaching = true;
          await prefs.setBool(shownKey, true);
        }
      } catch (_) {}
    }

    if (shouldShowCoaching && mounted) {
      // 토스트 후 살짝 텀을 두고 다이얼로그
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) await _showPauseIssueHelpDialog(autoShown: true);
    }

    // 8. 화면 종료
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationPage()),
        (route) => false,
      );
    }
  }

  /// `_onFalseTrigger`의 6단계 후처리 부분만 추출 — 잠시 멈춤이 재사용.
  /// (사운드 정지/UI 종료는 호출측에서 직접 처리)
  Future<void> _onFalseTriggerCleanup() async {
    final alarmId = widget.alarmData?['id'];
    if (alarmId == null) {
      ActiveAlarmState.clear();
      return;
    }

    // quota 환불
    try {
      await QuotaService.refund(QuotaCategory.alarm);
    } catch (e) {
      print('⚠️ 잠시멈춤 quota 환불 실패 (무시): $e');
    }

    // 트리거 카운트 원복
    final box = await Hive.openBox('trigger_counts_v2');
    final currentRaw = box.get(alarmId, defaultValue: 0);
    final current =
        (currentRaw is int)
            ? currentRaw
            : int.tryParse(currentRaw.toString()) ?? 0;
    if (current > 0) {
      await box.put(alarmId, current - 1);
    }

    // 당일 트리거 기록 + cooldown 초기화
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_triggered_date_$alarmId');
      await prefs.remove('cooldown_until_$alarmId');
    } catch (_) {}

    // 일회성 알람 enabled 복원 (트리거 시 disabled 되었을 수 있음)
    try {
      final hiveBox = HiveHelper.alarmBox;
      final cur = hiveBox.get(alarmId);
      if (cur != null) {
        final repeat = cur['repeat'];
        final isRepeat = (repeat is List && repeat.isNotEmpty);
        if (!isRepeat && cur['enabled'] != true) {
          final updated = Map<String, dynamic>.from(cur);
          updated['enabled'] = true;
          await hiveBox.put(alarmId, updated);
        }
      }
    } catch (_) {}

    // LMS 장소 상태 GPS 기반 재판단
    try {
      final placeId =
          widget.alarmData?['placeId']?.toString() ??
          widget.alarmData?['place']?.toString() ??
          widget.alarmData?['locationName']?.toString();
      if (placeId != null && placeId.isNotEmpty) {
        await SmartLocationService.clearTriggeredAlarm(placeId);
      }
    } catch (_) {}

    ActiveAlarmState.clear();
  }

  /// 잠시 멈춤 시간 선택 다이얼로그 (15/60/240/직접 입력)
  /// 직전 선택값을 하이라이트로 표시.
  Future<int?> _showPauseTimeDialog() async {
    final l10n = AppLocalizations.of(context);
    int lastMinutes = 60; // 기본값
    try {
      final prefs = await SharedPreferences.getInstance();
      lastMinutes = prefs.getInt('lastPauseMinutes') ?? 60;
    } catch (_) {}

    if (!mounted) return null;
    return showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.pause_circle, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.get('pause_dialog_title'),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[15, 60, 240].map((m) {
                final isLast = m == lastMinutes;
                return ListTile(
                  dense: true,
                  leading:
                      isLast
                          ? Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 20,
                          )
                          : const SizedBox(width: 20),
                  title: Text(
                    l10n.getWithArgs('pause_min_value', {'m': '$m'}),
                    style: TextStyle(
                      fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, m),
                );
              }),
              ListTile(
                dense: true,
                leading: const SizedBox(width: 20),
                title: Text(l10n.get('pause_min_custom')),
                onTap: () async {
                  final custom = await _showCustomPauseDialog();
                  if (custom != null && custom > 0) {
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx, custom);
                  }
                },
              ),
              const Divider(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  Navigator.pop(ctx, null); // 다이얼로그 닫고
                  // 안내 다이얼로그 띄움 → 잠시 멈춤은 취소된 상태
                  if (mounted) {
                    await _showPauseIssueHelpDialog(autoShown: false);
                  }
                  // 사운드 다시 재생 (사용자가 안내만 보고 다시 결정)
                  try {
                    await bellPlatform.invokeMethod('playSystemRingtone');
                  } catch (_) {}
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.get('pause_help_link'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Colors.amber.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(l10n.get('cancel_btn')),
            ),
          ],
        );
      },
    );
  }

  /// 직접 입력 다이얼로그 (1~720분)
  Future<int?> _showCustomSnoozeDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.get('snooze_custom_title')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.get('snooze_custom_hint'),
              suffixText: l10n.get('pause_custom_unit'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(l10n.get('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v == null || v <= 0 || v > 720) {
                  Navigator.pop(ctx, null);
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text(l10n.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  Future<int?> _showCustomPauseDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.get('pause_custom_title')),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.get('pause_custom_hint'),
              suffixText: l10n.get('pause_custom_unit'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text(l10n.get('cancel_btn')),
            ),
            ElevatedButton(
              onPressed: () {
                final v = int.tryParse(controller.text.trim());
                if (v == null || v <= 0 || v > 720) {
                  Navigator.pop(ctx, null);
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: Text(l10n.get('confirm')),
            ),
          ],
        );
      },
    );
  }

  /// "왜 잘못 울렸을까요?" 안내 다이얼로그 (Issue Coaching)
  Future<void> _showPauseIssueHelpDialog({required bool autoShown}) async {
    final l10n = AppLocalizations.of(context);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.handyman_outlined, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.get('pause_help_title'),
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              l10n.get('pause_help_body'),
              style: const TextStyle(fontSize: 13.5, height: 1.55),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.get('false_trigger_dialog_ok')),
            ),
          ],
        );
      },
    );
  }

  /// place coaching 카운터 키 (placeId > placeName 순으로 폴백)
  String? _placeKeyForCoaching() {
    final pid = widget.alarmData?['placeId']?.toString();
    if (pid != null && pid.isNotEmpty) return pid;
    final pname =
        widget.alarmData?['place']?.toString() ??
        widget.alarmData?['locationName']?.toString();
    if (pname != null && pname.isNotEmpty) return pname;
    return null;
  }

  @override
  void dispose() {
    _stopAllSounds(); // ✅ dispose에서도 모든 사운드 정지
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
          child: Column(
            children: [
              // ── 알람 제목 (상단 영역) ──
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                ),
              ),

              // ── 메인 버튼 2개 (다시 울림 / 알람 종료) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // ✅ 다시 울림
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _onSnooze,
                        child: Text(
                          l10n.get('btn_snooze'),
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // ✅ 알람 종료
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _onConfirm,
                        child: Text(
                          l10n.get('btn_dismiss'),
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── 잠시 멈춤 / 오발동 (보조 버튼 2개) ──
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ⏸️ 잠시 멈춤
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.lightBlue.shade200,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: _onPause,
                          icon: const Icon(Icons.pause_circle, size: 16),
                          label: Text(
                            l10n.get('btn_pause'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ⚡ 오발동
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber.shade300,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          onPressed: _onFalseTrigger,
                          icon: const Icon(Icons.bolt, size: 16),
                          label: Text(
                            l10n.get('btn_false_trigger'),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.get('pause_or_false_hint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} // ✅ _FullScreenAlarmPageState 클래스 끝

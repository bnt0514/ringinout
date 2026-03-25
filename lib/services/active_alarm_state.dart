// lib/services/active_alarm_state.dart
// 활성 알람 상태 관리 — 알람 화면이 떠 있는 동안 상태를 추적

import 'package:flutter/material.dart';

/// 전체화면 알람이 활성 상태인지 추적하는 글로벌 서비스
/// 홈 버튼/멀티태스킹으로 백그라운드 갔다가 포그라운드 복귀 시
/// 알람 화면을 다시 표시하기 위해 사용
class ActiveAlarmState {
  static String? _activeAlarmId;
  static String? _activeAlarmTitle;
  static Map<String, dynamic>? _activeAlarmData;
  static String? _activeAlarmSoundPath;

  /// 알람 화면이 활성화될 때 호출
  static void setActive({
    required String alarmTitle,
    Map<String, dynamic>? alarmData,
    String? soundPath,
  }) {
    _activeAlarmId = alarmData?['id']?.toString();
    _activeAlarmTitle = alarmTitle;
    _activeAlarmData = alarmData;
    _activeAlarmSoundPath = soundPath;
    debugPrint('🔔 ActiveAlarmState: 알람 활성화 (${_activeAlarmId})');
  }

  /// 알람이 종료(dismiss/snooze)될 때 호출
  static void clear() {
    debugPrint('🔕 ActiveAlarmState: 알람 해제 ($_activeAlarmId)');
    _activeAlarmId = null;
    _activeAlarmTitle = null;
    _activeAlarmData = null;
    _activeAlarmSoundPath = null;
  }

  /// 현재 활성 알람이 있는지
  static bool get isActive => _activeAlarmId != null;

  /// 활성 알람 정보
  static String? get alarmTitle => _activeAlarmTitle;
  static Map<String, dynamic>? get alarmData => _activeAlarmData;
  static String? get soundPath => _activeAlarmSoundPath;
}

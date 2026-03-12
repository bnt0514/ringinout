// lib/services/smart_location_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/app_log_buffer.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/smart_location_monitor.dart';

/// 🎯 SmartLocationService - Flutter 기반 위치 모니터링 파사드
///
/// 린 하이브리드 아키텍처: 외부 인터페이스 유지, 내부는
/// SmartLocationMonitor → LocationMonitorService (Timer+Geolocator) 체인으로 수행.
class SmartLocationService {
  static void _log(String message) {
    AppLogBuffer.record('SmartLocationService', message);
    debugPrint(message);
  }

  static bool _isInitialized = false;
  static Function(String placeId, String placeName, String triggerType)?
  _onAlarmTriggered;

  /// 초기화 및 알람 콜백 설정
  static Future<void> initialize({
    required Function(String placeId, String placeName, String triggerType)
    onAlarmTriggered,
  }) async {
    if (_isInitialized) return;

    _onAlarmTriggered = onAlarmTriggered;
    _isInitialized = true;
    _log('✅ SmartLocationService 초기화 완료 (Flutter 기반)');
  }

  /// 모니터링 시작 → SmartLocationMonitor로 위임
  static Future<void> startMonitoring() async {
    try {
      _log('🧭 startMonitoring → SmartLocationMonitor로 위임');
      await SmartLocationMonitor.startSmartMonitoring();
    } catch (e) {
      _log('❌ SmartLocationService 모니터링 시작 실패: $e');
    }
  }

  /// 모니터링 중지 → SmartLocationMonitor로 위임
  static Future<void> stopMonitoring() async {
    try {
      await SmartLocationMonitor.stopMonitoring();
      _log('🛑 SmartLocationService 모니터링 중지');
    } catch (e) {
      _log('❌ SmartLocationService 모니터링 중지 실패: $e');
    }
  }

  /// 알람 장소 업데이트 → LMS에 반영
  static Future<void> updatePlaces() async {
    try {
      _log('🔄 updatePlaces');
      await SmartLocationMonitor.updatePlaces();
    } catch (e) {
      _log('❌ SmartLocationService 장소 업데이트 실패: $e');
    }
  }

  /// 상태 조회 → SmartLocationMonitor + LocationMonitorService에서 조합
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final monitorStatus = SmartLocationMonitor.getStatus();
      final locationService = LocationMonitorService.instance;
      final isRunning = monitorStatus['isRunning'] as bool? ?? false;

      // v2: placeStates 기반으로 insideStatus 문자열 생성 (하위 호환)
      final placeStates = locationService.getAllPlaceStates();
      final insideParts = <String>[];
      for (final entry in placeStates.entries) {
        insideParts.add('${entry.key}=${entry.value.name}');
      }
      final insideStatusStr = insideParts.join(',');

      // 활성 알람 개수
      int alarmCount = 0;
      try {
        final alarms = HiveHelper.getActiveAlarmsForMonitoring();
        alarmCount = alarms.length;
      } catch (_) {}

      return {
        'state': isRunning ? 'MONITORING' : 'IDLE',
        'alarmCount': alarmCount,
        'targetPlace': '없음',
        'insideStatus': insideStatusStr,
        'exitWatchActive': false,
        'isMoving': false,
        'precisionMode': false,
        'profile': locationService.currentMonitoringProfile,
      };
    } catch (e) {
      _log('❌ SmartLocationService 상태 조회 실패: $e');
      return {'state': 'UNKNOWN', 'error': e.toString()};
    }
  }

  /// 장소별 inside 상태 조회 (v2: PlaceState 기반)
  /// SharedPreferences `place_state_{alarmId}` 에서 읽음
  static Future<Map<String, bool>> getInsideStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = <String, bool>{};
      for (final key in prefs.getKeys()) {
        if (key.startsWith('place_state_')) {
          final alarmId = key.substring('place_state_'.length);
          final stateStr = prefs.getString(key) ?? 'outside';
          // inside/exitVerify → true, outside → false
          result[alarmId] = (stateStr != 'outside');
        }
      }
      // 메인 isolate LMS가 실행 중이면 그 값도 병합 (우선 적용)
      final lmsStates = LocationMonitorService.instance.getAllPlaceStates();
      for (final entry in lmsStates.entries) {
        result[entry.key] = (entry.value != PlaceState.outside);
      }
      return result;
    } catch (e) {
      _log('⚠️ getInsideStatus 실패: $e');
      final lmsStates = LocationMonitorService.instance.getAllPlaceStates();
      return lmsStates.map((k, v) => MapEntry(k, v != PlaceState.outside));
    }
  }

  /// LMS가 현재 실제로 추적(폴링) 중인 장소 이름 집합
  /// 백그라운드 isolate 여부와 무관하게 geofence_running + 활성 알람으로 판단
  static Set<String> getTrackedPlaceNames() {
    // 메인 isolate LMS가 실행 중이면 그걸 우선 사용
    final lmsNames = LocationMonitorService.instance.trackedPlaceNames;
    if (lmsNames.isNotEmpty) return lmsNames;

    // 백그라운드 서비스가 실행 중인지는 SharedPreferences로 판단
    // (비동기 불가 → 활성 알람 장소 이름을 직접 반환)
    try {
      final alarms = HiveHelper.getActiveAlarmsForMonitoring();
      return alarms
          .map((a) => (a['place'] ?? a['locationName'] ?? '') as String)
          .where((n) => n.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  /// 서비스 실행 여부
  static bool get isRunning => _isInitialized;

  /// 현재 모니터링 모드
  static Future<String> getCurrentState() async {
    final status = await getStatus();
    return status['state'] as String? ?? 'UNKNOWN';
  }

  /// 활성 알람 수
  static Future<int> getAlarmCount() async {
    final status = await getStatus();
    return status['alarmCount'] as int? ?? 0;
  }

  /// 현재 타겟 장소
  static Future<String?> getTargetPlace() async {
    return null; // Flutter 모드에서는 단일 타겟 개념 없음
  }

  /// 특정 알람 트리거 기록 제거 (재활성화 시 사용)
  static Future<void> clearTriggeredAlarm(String placeId) async {
    // Flutter 모드에서는 _lastInside 상태를 리셋
    try {
      final parts = placeId.split('_');
      if (parts.length >= 2) {
        final placeName = parts.sublist(1, parts.length - 1).join('_');
        await LocationMonitorService.instance.resetPlaceState(placeName);
      }
      _log('🔔 트리거 기록 제거: $placeId');
    } catch (e) {
      _log('❌ 트리거 기록 제거 실패: $e');
    }
  }

  /// 알람 데이터로 고유 placeId 생성
  static String buildPlaceIdFromAlarm(Map<String, dynamic> alarm) {
    final placeName = alarm['place'] ?? alarm['locationName'] ?? '';
    final trigger = alarm['trigger'] as String? ?? 'entry';
    final alarmId = alarm['id']?.toString() ?? '';
    return '${alarmId}_${placeName}_$trigger';
  }

  /// 에러 리포트 (no-op in Flutter mode)
  static Future<void> sendErrorReport(Map<String, dynamic> payload) async {
    _log('ℹ️ sendErrorReport: Flutter 모드 - 로그만 기록');
    _log(payload.toString());
  }

  /// 알람 모드 전환 (Flutter 모드에서는 항상 Flutter)
  static Future<void> setAlarmMode({required bool useFlutter}) async {
    _log('ℹ️ setAlarmMode: Flutter 기반 모드 고정 (useFlutter=$useFlutter)');
  }

  /// 테스트 알람 (Flutter 모드)
  static Future<void> testAlarm() async {
    try {
      await AlarmNotificationHelper.showNativeAlarm(
        title: '테스트 알람',
        message: 'Flutter 모니터링 테스트입니다!',
        alarmData: {'name': '테스트 알람', 'trigger': 'entry'},
      );
      _log('🧪 테스트 알람 발동');
    } catch (e) {
      _log('❌ 테스트 알람 실패: $e');
    }
  }

  // ========== GPS 시뮬레이터 (제거됨 - 린 하이브리드에서 불필요) ==========

  /// GPS 시뮬레이션 주입 (no-op — 린 하이브리드에서 시뮬레이터 제거됨)
  static Future<void> injectSimulatedLocation({
    required double lat,
    required double lng,
    double accuracy = 5.0,
    double speed = 0.0,
  }) async {
    _log('⚠️ injectSimulatedLocation 호출됨 (no-op — 린 하이브리드 모드)');
  }

  /// GPS 시뮬레이션 중지 (no-op — 린 하이브리드에서 시뮬레이터 제거됨)
  static Future<void> stopSimulation() async {
    _log('⚠️ stopSimulation 호출됨 (no-op — 린 하이브리드 모드)');
  }

  /// Passing 알람 (알람 정지 후 재세팅)
  static Future<void> passingAlarm(
    String placeId, {
    int snoozeDurationMs = 0,
  }) async {
    _log('👋 Passing 요청: $placeId (Flutter 모드 - 장소 상태 리셋)');
    try {
      final parts = placeId.split('_');
      if (parts.length >= 2) {
        final placeName = parts.sublist(1, parts.length - 1).join('_');
        await LocationMonitorService.instance.resetPlaceState(placeName);
      }
    } catch (e) {
      _log('❌ Passing 요청 실패: $e');
    }
  }
}

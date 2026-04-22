import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/location_monitor_service.dart'; // ✅ Heartbeat 전송용
import 'package:ringinout/services/smart_location_service.dart';

class AlarmController extends ChangeNotifier {
  // 알람 리스트
  List<Map<String, dynamic>> _locationAlarms = [];
  List<Map<String, dynamic>> get locationAlarms => _locationAlarms;

  // 정렬 순서
  String _sortOrder = 'time';
  String get sortOrder => _sortOrder;

  // ✅ 초기화 완료 여부 체크
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 초기화 - 안전하게 처리
  Future<void> initialize() async {
    try {
      await _loadAlarms();
      _sortAlarms();
      _isInitialized = true;
      print('✅ AlarmController 초기화 완료');
    } catch (e) {
      print('⚠️ AlarmController 초기화 실패: $e');
      _locationAlarms = [];
      _isInitialized = false;
    }
    notifyListeners();
  }

  // 알람 로드 - 안전하게 처리
  Future<void> _loadAlarms() async {
    try {
      _locationAlarms = HiveHelper.getLocationAlarms();
    } catch (e) {
      print('⚠️ 알람 목록 가져오기 실패: $e');
      _locationAlarms = [];
    }
    notifyListeners();
  }

  // ✅ 활성화된 알람만 안전하게 가져오기
  List<Map<String, dynamic>> getActiveAlarms() {
    try {
      if (!_isInitialized) return [];
      return _locationAlarms
          .where((alarm) => alarm['enabled'] == true)
          .toList();
    } catch (e) {
      print('⚠️ 활성화된 알람 가져오기 실패: $e');
      return [];
    }
  }

  // Add new alarm
  Future<void> addAlarm(Map<String, dynamic> alarm) async {
    await HiveHelper.addLocationAlarm(alarm);
    await _loadAlarms();
    await _refreshMonitoring();
    // ✅ Watchdog heartbeat 전송
    await LocationMonitorService.sendWatchdogHeartbeat();
  }

  // Update existing alarm
  Future<void> updateAlarm(int index, Map<String, dynamic> alarm) async {
    final existingId =
        _locationAlarms.isNotEmpty && index < _locationAlarms.length
            ? _locationAlarms[index]['id']
            : null;
    final alarmId = alarm['id'] ?? existingId;

    if (alarmId is String) {
      await HiveHelper.updateLocationAlarmById(alarmId, alarm);

      // ✅ 알람 수정 시 잔류 차단 플래그 초기화
      // - alarm_disabled_: 이전에 알람이 울리고 종료 버튼 눌렀을 때 설정됨
      // - alarm_triggered_date_: 당일 재트리거 방지용 기록
      // 사용자가 저장하는 행위 자체가 알람을 새로 활성화하겠다는 의도이므로 삭제
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_disabled_$alarmId');
        await prefs.remove('alarm_triggered_date_$alarmId');
      } catch (e) {
        print('⚠️ 알람 플래그 초기화 실패: $e');
      }
    } else {
      await HiveHelper.updateLocationAlarm(index, alarm);
    }
    await _loadAlarms();
    await _refreshMonitoring();
    // ✅ Watchdog heartbeat 전송
    await LocationMonitorService.sendWatchdogHeartbeat();
  }

  // Delete alarm
  Future<void> deleteAlarm(int index) async {
    final alarmId =
        index < _locationAlarms.length ? _locationAlarms[index]['id'] : null;
    if (alarmId is String) {
      await HiveHelper.deleteAlarmById(alarmId);
    } else {
      await HiveHelper.deleteLocationAlarm(index);
    }
    await _loadAlarms();
    await _refreshMonitoring();
    // ✅ Watchdog heartbeat 전송
    await LocationMonitorService.sendWatchdogHeartbeat();
  }

  // Change sort order
  void setSortOrder(String order) {
    if (_sortOrder != order) {
      _sortOrder = order;
      _sortAlarms();
      notifyListeners();
    }
  }

  // Sort alarms based on current sort order
  void _sortAlarms() {
    if (_sortOrder == 'time') {
      _locationAlarms.sort((a, b) {
        final aHour = a['hour'] ?? 0;
        final bHour = b['hour'] ?? 0;
        if (aHour != bHour) return aHour.compareTo(bHour);

        final aMinute = a['minute'] ?? 0;
        final bMinute = b['minute'] ?? 0;
        return aMinute.compareTo(bMinute);
      });
    } else {
      _locationAlarms.sort((a, b) {
        final aOrder = a['order'] ?? 0;
        final bOrder = b['order'] ?? 0;
        return aOrder.compareTo(bOrder);
      });
    }
    notifyListeners();
  }

  // Toggle alarm enabled state
  Future<void> toggleAlarmEnabled(int index, bool enabled) async {
    final alarm = _locationAlarms[index];
    alarm['enabled'] = enabled;
    if (enabled) {
      final placeId = SmartLocationService.buildPlaceIdFromAlarm(alarm);
      await SmartLocationService.clearTriggeredAlarm(placeId);

      // ✅ alarm_disabled_ 플래그 제거 (Problem 4 수정)
      final alarmId = alarm['id'];
      if (alarmId is String) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('alarm_disabled_$alarmId');
        print('🗑️ alarm_disabled_ 플래그 제거: $alarmId');
      }
    }
    await updateAlarm(index, alarm);
  }

  // Update alarm order (for custom sorting)
  Future<void> reorderAlarms(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final alarm = _locationAlarms.removeAt(oldIndex);
    _locationAlarms.insert(newIndex, alarm);

    // Update order values
    for (var i = 0; i < _locationAlarms.length; i++) {
      final alarm = _locationAlarms[i];
      alarm['order'] = i;
      final alarmId = alarm['id'];
      if (alarmId is String) {
        await HiveHelper.updateLocationAlarmById(alarmId, alarm);
      }
    }

    notifyListeners();
    await _refreshMonitoring();
  }

  Future<void> _refreshMonitoring() async {
    try {
      // ✅ Flutter LMS + 네이티브 지오펜스 동시 갱신
      // startSmartMonitoring 대신 updatePlaces만 호출:
      // LMS가 이미 실행 중이면 재시작 없이 장소/알람 목록만 갱신
      await SmartLocationMonitor.updatePlaces();
      print('🎯 AlarmController: 장소 업데이트 완료 (Flutter LMS + 네이티브)');
    } catch (e) {
      print('⚠️ 모니터링 업데이트 실패: $e');
    }
  }

  @override
  void dispose() {
    if (Hive.isBoxOpen('locationAlarms_v2')) {
      Hive.box('locationAlarms_v2').close();
    }
    super.dispose();
  }
}

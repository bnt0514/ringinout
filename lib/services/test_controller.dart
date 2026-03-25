import 'package:flutter/material.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';

class TestGeofenceController extends ChangeNotifier {
  Map<String, bool> _locationStates = {};
  bool _isInitialized = false;

  Map<String, bool> get locationStates => _locationStates;
  bool get isInitialized => _isInitialized;

  // ✅ 안전한 초기화
  void initialize() {
    try {
      final locations = HiveHelper.getSavedLocations();
      _locationStates.clear();

      for (var location in locations) {
        _locationStates[location['name']] = false;
      }

      _isInitialized = true;
      notifyListeners();
      print('🧪 TestGeofenceController 초기화 완료: ${_locationStates.length}개 장소');
    } catch (e) {
      print('❌ TestGeofenceController 초기화 실패: $e');
      _isInitialized = false;
    }
  }

  // ✅ 안전한 토글
  void toggleLocationState(String locationName) {
    if (!_isInitialized) {
      print('⚠️ TestGeofenceController가 초기화되지 않음');
      return;
    }

    if (_locationStates.containsKey(locationName)) {
      final wasInside = _locationStates[locationName]!;
      _locationStates[locationName] = !wasInside;

      print('🔄 테스트 상태 변경: $locationName ${wasInside ? '진입→진출' : '진출→진입'}');

      // 알람 체크 및 트리거
      _checkAndTriggerAlarm(locationName, !wasInside);

      notifyListeners();
    } else {
      print('❌ 장소를 찾을 수 없음: $locationName');
    }
  }

  // ✅ 안전한 알람 체크
  void _checkAndTriggerAlarm(String locationName, bool isEntering) {
    try {
      final alarms = HiveHelper.getLocationAlarms();

      for (var alarm in alarms) {
        if (alarm['enabled'] == true && alarm['locationName'] == locationName) {
          final triggerType = isEntering ? 'enter' : 'exit';
          final shouldTrigger = alarm[triggerType] == true;

          if (shouldTrigger) {
            print('🧪 테스트 알람 트리거: $locationName (${isEntering ? '진입' : '진출'})');
            _triggerTestAlarm(alarm, isEntering);
          }
        }
      }
    } catch (e) {
      print('❌ 알람 체크 실패: $e');
    }
  }

  // ✅ 테스트 알람 실행
  void _triggerTestAlarm(Map<String, dynamic> alarm, bool isEntering) {
    try {
      final message =
          isEntering
              ? '${alarm['locationName']}에 도착했습니다! 🎯'
              : '${alarm['locationName']}에서 나갔습니다! 🚶‍♂️';

      AlarmNotificationHelper.showNativeAlarm(
        title: '🧪 테스트 알람: ${alarm['name']}',
        message: message,
        sound: alarm['sound'] ?? 'default',
        vibrate: alarm['vibrate'] ?? true,
      );

      print('🔔 테스트 알람 실행: ${alarm['name']} - $message');
    } catch (e) {
      print('❌ 테스트 알람 실행 실패: $e');
    }
  }

  // ✅ 안전한 상태 초기화
  void resetAllStates() {
    if (!_isInitialized) {
      print('⚠️ TestGeofenceController가 초기화되지 않음');
      return;
    }

    for (var key in _locationStates.keys) {
      _locationStates[key] = false;
    }
    notifyListeners();
    print('🔄 모든 위치 상태 초기화 (진출 상태)');
  }

  // ✅ 디버깅용 현재 상태 출력
  void printCurrentStates() {
    if (!_isInitialized) {
      print('⚠️ TestGeofenceController가 아직 초기화되지 않음');
      return;
    }

    print('📊 현재 테스트 상태:');
    _locationStates.forEach((location, isInside) {
      print('  $location: ${isInside ? '진입' : '진출'}');
    });
  }
}

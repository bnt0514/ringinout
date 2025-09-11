// lib/services/hive_helper.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart'; // ✅ 추가

class HiveHelper {
  static late Box _placeBox;
  static late Box _alarmBox;
  static late Box _settingsBox;
  static bool _isInitialized = false; // ✅ 초기화 상태 추가

  // ✅ 앱 시작 시 반드시 호출해야 함
  static Future<void> init() async {
    if (_isInitialized) return; // ✅ 중복 초기화 방지

    try {
      // ✅ 고유 경로로 초기화 (충돌 방지)
      final appDir = await getApplicationDocumentsDirectory();
      final uniquePath = '${appDir.path}/ringinout_unique_v3'; // ✅ 고유 경로

      await Hive.initFlutter(uniquePath);
      print('📦 Hive 고유 경로 설정: $uniquePath');

      // ✅ 박스 열기 + late 변수에 할당
      if (!Hive.isBoxOpen('savedLocations_v2')) {
        // ✅ 버전 추가로 충돌 방지
        _placeBox = await Hive.openBox('savedLocations_v2');
      } else {
        _placeBox = Hive.box('savedLocations_v2');
      }

      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        // ✅ 버전 추가
        _alarmBox = await Hive.openBox('locationAlarms_v2');
      } else {
        _alarmBox = Hive.box('locationAlarms_v2');
      }

      if (!Hive.isBoxOpen('settings_v2')) {
        // ✅ 버전 추가
        _settingsBox = await Hive.openBox('settings_v2');
      } else {
        _settingsBox = Hive.box('settings_v2');
      }

      _isInitialized = true; // ✅ 초기화 완료 플래그
      print('📦 HiveHelper 초기화 완료 (고유 경로)');
    } catch (e) {
      print('❌ HiveHelper 초기화 실패: $e');

      // ✅ 락 파일 충돌 시 재시도
      if (e.toString().contains('lock failed')) {
        print('🔄 Hive 락 충돌 감지, 재시도...');
        await _retryWithFallback();
      } else {
        rethrow;
      }
    }
  }

  // ✅ 충돌 시 폴백 재시도
  static Future<void> _retryWithFallback() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackPath =
          '${appDir.path}/ringinout_fallback_${DateTime.now().millisecondsSinceEpoch}';

      await Hive.initFlutter(fallbackPath);
      print('🔄 폴백 경로로 재시도: $fallbackPath');

      _placeBox = await Hive.openBox('savedLocations_fallback');
      _alarmBox = await Hive.openBox('locationAlarms_fallback');
      _settingsBox = await Hive.openBox('settings_fallback');

      _isInitialized = true;
      print('✅ 폴백 초기화 성공');
    } catch (e) {
      print('❌ 폴백 초기화도 실패: $e');
      throw e;
    }
  }

  // ✅ 안전한 getter들 (초기화 체크 포함)
  static Box get placeBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _placeBox;
  }

  static Box get alarmBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _alarmBox;
  }

  static Box get settingsBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _settingsBox;
  }

  // ✅ 초기화 상태 확인
  static bool get isInitialized => _isInitialized;

  // ✅ MyPlaces 관련 (안전한 접근)
  static List<Map<String, dynamic>> getSavedLocations() {
    try {
      final values = _placeBox.values.toList();
      for (var v in values) {
        debugPrint('📦 저장된 값 타입: ${v.runtimeType}, 값: $v');
      }
      debugPrint('📥 getSavedLocations 원본 값: $values');
      final mapped =
          values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      debugPrint('📥 getSavedLocations 반환값: $mapped');
      return mapped;
    } catch (e) {
      debugPrint('❌ getSavedLocations 에러: $e');
      return [];
    }
  }

  static Future<void> addLocationAlarm(Map<String, dynamic> alarmData) async {
    try {
      final String id = await saveLocationAlarm(alarmData);
      debugPrint('✅ 위치 알람 저장 완료 (ID: $id)');
      debugPrint('📦 현재 알람 목록: ${_alarmBox.values.toList()}');
    } catch (e) {
      debugPrint('❌ addLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static Future<void> addLocation(Map<String, dynamic> location) async {
    try {
      await _placeBox.add(location);
      debugPrint('✅ Hive에 저장 완료: $location');
      debugPrint('📦 현재 Hive 상태 (저장 후): ${_placeBox.values.toList()}');
    } catch (e) {
      debugPrint('❌ addLocation 에러: $e');
      rethrow;
    }
  }

  static Future<void> updateLocationAt(
    int index,
    Map<String, dynamic> newLocation,
  ) async {
    try {
      final box = placeBox;
      if (index >= 0 && index < box.length) {
        await box.putAt(index, newLocation);
      }
    } catch (e) {
      debugPrint('❌ updateLocationAt 에러: $e');
      rethrow;
    }
  }

  static Future<void> deleteLocation(int index) async {
    try {
      await _placeBox.deleteAt(index);
    } catch (e) {
      debugPrint('❌ deleteLocation 에러: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> getLocation(int index) {
    try {
      return Map<String, dynamic>.from(_placeBox.getAt(index));
    } catch (e) {
      debugPrint('❌ getLocation 에러: $e');
      return {};
    }
  }

  static int getLength() {
    try {
      return _placeBox.length;
    } catch (e) {
      debugPrint('❌ getLength 에러: $e');
      return 0;
    }
  }

  // ✅ 알람 저장용 - 이미 열린 박스 사용
  static Future<String> saveLocationAlarm(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      final id = const Uuid().v4(); // 고유 ID 생성
      alarmData['id'] = id;

      await _alarmBox.put(id, alarmData); // 이미 열린 박스 사용
      return id;
    } catch (e) {
      debugPrint('❌ saveLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> getLocationAlarms() {
    try {
      return _alarmBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ getLocationAlarms 에러: $e');
      return [];
    }
  }

  static Future<void> deleteLocationAlarm(int index) async {
    try {
      await _alarmBox.deleteAt(index);
    } catch (e) {
      debugPrint('❌ deleteLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static Future<void> updateLocationAlarm(
    int index,
    Map<String, dynamic> updatedAlarm,
  ) async {
    try {
      await _alarmBox.putAt(index, updatedAlarm);
    } catch (e) {
      debugPrint('❌ updateLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static Future<void> deleteAlarmById(String id) async {
    try {
      final triggerBox = await Hive.openBox('trigger_counts_v2'); // ✅ 버전 추가
      final prefs = await SharedPreferences.getInstance();

      await alarmBox.delete(id); // 알람 삭제
      await triggerBox.delete(id); // triggerCount 삭제
      await prefs.remove('alarm_name_$id'); // 캐시 삭제

      print('🗑️ 알람 $id 삭제 완료 (알람 + 트리거 + 캐시)');
    } catch (e) {
      debugPrint('❌ deleteAlarmById 에러: $e');
      rethrow;
    }
  }

  // ✅ FAB 위치 저장
  static Future<void> saveFabPosition(double x, double y) async {
    try {
      await _settingsBox.put('fabX', x);
      await _settingsBox.put('fabY', y);
    } catch (e) {
      debugPrint('❌ saveFabPosition 에러: $e');
      rethrow;
    }
  }

  static Future<Offset> getFabPosition() async {
    try {
      final x = _settingsBox.get('fabX', defaultValue: 300.0);
      final y = _settingsBox.get('fabY', defaultValue: 600.0);
      return Offset(x, y);
    } catch (e) {
      debugPrint('❌ getFabPosition 에러: $e');
      return const Offset(300.0, 600.0);
    }
  }

  // ✅ 알람 설정값 (벨소리, 진동, 다시 울림) 저장/불러오기
  static Future<void> saveAlarmSound(String path) async {
    try {
      await _settingsBox.put('alarmSound', path);
    } catch (e) {
      debugPrint('❌ saveAlarmSound 에러: $e');
      rethrow;
    }
  }

  static String getAlarmSound() {
    try {
      return _settingsBox.get('alarmSound', defaultValue: '기본 벨소리');
    } catch (e) {
      debugPrint('❌ getAlarmSound 에러: $e');
      return '기본 벨소리';
    }
  }

  static Future<void> saveVibration(String vibration) async {
    try {
      await _settingsBox.put('vibration', vibration);
    } catch (e) {
      debugPrint('❌ saveVibration 에러: $e');
      rethrow;
    }
  }

  static String getVibration() {
    try {
      return _settingsBox.get('vibration', defaultValue: '짧은 진동');
    } catch (e) {
      debugPrint('❌ getVibration 에러: $e');
      return '짧은 진동';
    }
  }

  static Future<void> saveSnooze(String snooze) async {
    try {
      await _settingsBox.put('snooze', snooze);
    } catch (e) {
      debugPrint('❌ saveSnooze 에러: $e');
      rethrow;
    }
  }

  static String getSnooze() {
    try {
      return _settingsBox.get('snooze', defaultValue: '5분 후 1회');
    } catch (e) {
      debugPrint('❌ getSnooze 에러: $e');
      return '5분 후 1회';
    }
  }
}

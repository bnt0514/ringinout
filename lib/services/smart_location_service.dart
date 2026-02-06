// lib/services/smart_location_service.dart

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/app_log_buffer.dart';

/// 🎯 SmartLocationService - 네이티브 3단계 위치 모니터링 연동
///
/// 기존 Flutter 기반 GeofenceService를 대체
/// 네이티브 Android SmartLocationManager와 통신
///
/// 모드:
/// - IDLE: 배터리 0% (Activity Transition + 큰 지오펜스)
/// - ARMED: 배터리 ~1% (작은 지오펜스 + 저전력 위치)
/// - HOT: 30~60초 고정밀 GPS 버스트
class SmartLocationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.ringinout/smart_location',
  );

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

    // 네이티브에서 알람 트리거 수신
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmTriggered') {
        final args = call.arguments as Map<dynamic, dynamic>;
        final placeId = args['placeId'] as String;
        final placeName = args['placeName'] as String;
        final triggerType = args['triggerType'] as String;

        _log('🚨 네이티브 알람 수신: $placeName ($triggerType)');

        // 콜백 호출
        _onAlarmTriggered?.call(placeId, placeName, triggerType);

        // 알람 처리
        await _handleAlarmTrigger(placeId, placeName, triggerType);
      }
    });

    _isInitialized = true;
    _log('✅ SmartLocationService 초기화 완료');
  }

  /// 모니터링 시작
  static Future<void> startMonitoring() async {
    try {
      // Hive에서 활성 알람 가져오기
      final alarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();

      _log('🧭 startMonitoring 활성 알람 수: ${alarms.length}');

      if (alarms.isEmpty) {
        _log('📭 활성 알람 없음 - 모니터링 시작하지 않음');
        return;
      }

      // 장소 정보 가져오기
      final places = HiveHelper.getSavedLocations();
      final alarmPlaces = <Map<String, dynamic>>[];

      for (final alarm in alarms) {
        final placeName = alarm['place'] ?? alarm['locationName'];
        if (placeName == null) continue;

        final alarmId = alarm['id']?.toString() ?? '';
        final trigger = alarm['trigger'] as String? ?? 'entry';
        _log('🧭 알람 확인: id=$alarmId, place=$placeName, trigger=$trigger');

        final place = places.firstWhere(
          (p) => p['name'] == placeName,
          orElse: () => <String, dynamic>{},
        );

        if (place.isEmpty) continue;

        final lat = (place['latitude'] ?? place['lat']) as double?;
        final lng = (place['longitude'] ?? place['lng']) as double?;
        final radius = (alarm['radius'] ?? place['radius'] ?? 100) as num;

        if (lat == null || lng == null) continue;

        // ✅ 고유 ID 생성: 알람ID_장소명_트리거타입 (같은 장소에 여러 알람 지원)
        final uniqueId = '${alarmId}_${placeName}_$trigger';

        alarmPlaces.add({
          'id': uniqueId,
          'name': placeName,
          'latitude': lat,
          'longitude': lng,
          'radiusMeters': radius.toDouble(),
          'triggerType': trigger == 'exit' ? 'exit' : 'entry',
          'enabled': true,
        });
      }

      if (alarmPlaces.isEmpty) {
        _log('📭 유효한 알람 장소 없음');
        return;
      }

      // 네이티브 모니터링 시작
      await _channel.invokeMethod('startMonitoring', {'places': alarmPlaces});

      _log('🎯 SmartLocationService 모니터링 시작: ${alarmPlaces.length}개 장소');
      for (final place in alarmPlaces) {
        _log(
          '   📍 ${place['name']} (${place['triggerType']}) - ID: ${place['id']}',
        );
      }
    } catch (e) {
      _log('❌ SmartLocationService 모니터링 시작 실패: $e');
    }
  }

  static Future<void> sendErrorReport(Map<String, dynamic> payload) async {
    try {
      await _channel.invokeMethod('sendErrorReport', payload);
      _log('✅ 에러 리포트 전송 요청 완료');
    } catch (e) {
      _log('❌ 에러 리포트 전송 실패: $e');
      _log(payload.toString());
    }
  }

  /// 모니터링 중지
  static Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
      _log('🛑 SmartLocationService 모니터링 중지');
    } catch (e) {
      _log('❌ SmartLocationService 모니터링 중지 실패: $e');
    }
  }

  /// 알람 장소 업데이트
  static Future<void> updatePlaces() async {
    try {
      final alarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();

      _log('🧭 updatePlaces 활성 알람 수: ${alarms.length}');

      final places = HiveHelper.getSavedLocations();
      final alarmPlaces = <Map<String, dynamic>>[];

      for (final alarm in alarms) {
        final placeName = alarm['place'] ?? alarm['locationName'];
        if (placeName == null) continue;

        final alarmId = alarm['id']?.toString() ?? '';
        final trigger = alarm['trigger'] as String? ?? 'entry';
        _log(
          '🧭 updatePlaces 알람: id=$alarmId, place=$placeName, trigger=$trigger',
        );

        final place = places.firstWhere(
          (p) => p['name'] == placeName,
          orElse: () => <String, dynamic>{},
        );

        if (place.isEmpty) continue;

        final lat = (place['latitude'] ?? place['lat']) as double?;
        final lng = (place['longitude'] ?? place['lng']) as double?;
        final radius = (alarm['radius'] ?? 100) as num;

        if (lat == null || lng == null) continue;

        alarmPlaces.add({
          'id': '${alarmId}_${placeName}_$trigger',
          'name': placeName,
          'latitude': lat,
          'longitude': lng,
          'radiusMeters': radius.toDouble(),
          'triggerType': trigger == 'exit' ? 'exit' : 'entry',
          'enabled': true,
        });
      }

      await _channel.invokeMethod('updatePlaces', {'places': alarmPlaces});
      _log('🔄 SmartLocationService 장소 업데이트: ${alarmPlaces.length}개');
      for (final place in alarmPlaces) {
        _log(
          '   📍 ${place['name']} (${place['triggerType']}) - ID: ${place['id']}',
        );
      }
    } catch (e) {
      _log('❌ SmartLocationService 장소 업데이트 실패: $e');
    }
  }

  /// 특정 알람 트리거 기록 제거 (재활성화 시 사용)
  static Future<void> clearTriggeredAlarm(String placeId) async {
    try {
      await _channel.invokeMethod('clearTriggeredAlarm', {'placeId': placeId});
      _log('🔔 트리거 기록 제거 요청: $placeId');
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

  /// 상태 조회
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return Map<String, dynamic>.from(result as Map);
    } catch (e) {
      print('❌ SmartLocationService 상태 조회 실패: $e');
      return {'state': 'UNKNOWN', 'error': e.toString()};
    }
  }

  /// 서비스 실행 여부
  static bool get isRunning => _isInitialized;

  /// 현재 모니터링 모드 (IDLE, ARMED, HOT)
  static Future<String> getCurrentState() async {
    final status = await getStatus();
    return status['state'] as String? ?? 'UNKNOWN';
  }

  /// 장소별 inside 상태 조회
  static Future<Map<String, bool>> getInsideStatus() async {
    final status = await getStatus();
    final insideStr = status['insideStatus'] as String? ?? '';

    final result = <String, bool>{};
    if (insideStr.isEmpty) return result;

    // "시흥집=true,회사=false" 형식 파싱
    for (final pair in insideStr.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        final name = parts[0].trim();
        final value = parts[1].trim().toLowerCase() == 'true';
        result[name] = value;
      }
    }
    return result;
  }

  /// 활성 알람 수
  static Future<int> getAlarmCount() async {
    final status = await getStatus();
    return status['alarmCount'] as int? ?? 0;
  }

  /// 현재 타겟 장소 (ARMED/HOT 모드일 때)
  static Future<String?> getTargetPlace() async {
    final status = await getStatus();
    final target = status['targetPlace'] as String?;
    return (target == '없음' || target == null) ? null : target;
  }

  /// 알람 트리거 처리
  static Future<void> _handleAlarmTrigger(
    String placeId,
    String placeName,
    String triggerType,
  ) async {
    try {
      print('🚨 알람 트리거: $placeName ($triggerType)');

      // 알람 정보 찾기 (고유 ID + 트리거 타입 기준)
      final alarms = HiveHelper.getLocationAlarms();
      final alarm = alarms.firstWhere((a) {
        if (a['enabled'] != true) return false;

        final alarmPlace = a['place'] ?? a['locationName'];
        final alarmTrigger = a['trigger'] as String? ?? 'entry';
        final alarmId = a['id']?.toString() ?? '';
        final uniqueId = '${alarmId}_${alarmPlace}_$alarmTrigger';

        return uniqueId == placeId ||
            (alarmPlace == placeName && alarmTrigger == triggerType);
      }, orElse: () => <String, dynamic>{});

      if (alarm.isEmpty) {
        print('⚠️ 활성 알람 정보를 찾을 수 없음: $placeId');
        return;
      }

      // 전체화면 알람 표시
      await AlarmNotificationHelper.showNativeAlarm(
        title: alarm['name'] ?? placeName,
        message: triggerType == 'entry' ? '도착했습니다!' : '출발했습니다!',
      );

      // 알람 비활성화 (1회성 알람인 경우)
      final repeatDays = alarm['days'] as List?;
      if (repeatDays == null || repeatDays.isEmpty) {
        // 반복 요일이 없으면 비활성화
        await _disableAlarm(placeId, placeName);
      }
    } catch (e) {
      print('❌ 알람 트리거 처리 실패: $e');
    }
  }

  /// 알람 비활성화
  static Future<void> _disableAlarm(String placeId, String placeName) async {
    try {
      final alarmBox = HiveHelper.alarmBox;

      for (var key in alarmBox.keys) {
        final alarm = alarmBox.get(key);
        if (alarm is Map) {
          final id = alarm['id']?.toString();
          final place = alarm['place'] ?? alarm['locationName'];

          if (id == placeId || place == placeName) {
            final updatedAlarm = Map<String, dynamic>.from(alarm);
            updatedAlarm['enabled'] = false;
            await alarmBox.put(key, updatedAlarm);
            print('🔕 알람 비활성화: $placeName');
            break;
          }
        }
      }

      // 장소 목록 업데이트
      await updatePlaces();
    } catch (e) {
      print('❌ 알람 비활성화 실패: $e');
    }
  }
}

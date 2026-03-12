// lib/services/smart_location_monitor.dart
//
// ✅ v3 지오펜스 + ActivityTransition — 모니터링 오케스트레이터
//
// 역할:
// 1. LocationMonitorService v3 시작/중지 관리
// 2. 네이티브 지오펜스 이벤트 수신 → LMS.onGeofenceEvent()로 전달
// 3. 네이티브 ActivityTransition 이벤트 수신 → LMS.onActivityTransition()으로 전달
//    (v3: 모션 이벤트가 INSIDE_IDLE ↔ INSIDE_MOVING 전환을 트리거)
// 4. 백그라운드 서비스 유지보수
//
// 판정 로직: LocationMonitorService v3에 100% 위임
// GPS 호출: SmartLocationMonitor에서 절대 하지 않음

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/background_service.dart';
import 'package:ringinout/services/hive_helper.dart';

class SmartLocationMonitor {
  // 타이머
  static Timer? _serviceCheckTimer;

  // 상태
  static LocationMonitorService? _locationService;

  // 네이티브 신호 수신 채널
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.example.ringinout/smart_location',
  );
  static bool _nativeListenerSetup = false;

  // ========== 통합 스마트 모니터링 ==========

  /// 모니터링 시작 (유일한 진입점)
  static Future<void> startSmartMonitoring() async {
    try {
      print('[SLM] 🧠 스마트 모니터링 시작');

      await BackgroundServiceManager.initialize();

      final activeAlarms = await _getActiveAlarmsCount();
      print('[SLM] 🎯 활성 알람 ${activeAlarms}개 발견');

      if (activeAlarms == 0) {
        print('[SLM] 📭 활성 알람이 없어 모니터링 중단');
        final locationService = LocationMonitorService();
        await locationService.stopMonitoring();
        return;
      }

      // 백그라운드 서비스 시작
      if (!await BackgroundServiceManager.isRunning()) {
        print('[SLM] 🚀 백그라운드 서비스 시작');
        await BackgroundServiceManager.startService();
      }

      // LocationMonitorService 시작
      _locationService = LocationMonitorService();
      await _locationService!.startBackgroundMonitoring((type, alarm) {
        print('[SLM] 🚨 알람 트리거: ${alarm['name']} ($type)');
      });

      // 네이티브 지오펜스 이벤트 수신 설정
      _setupNativeSignalListener();

      // ★ 네이티브 지오펜스 + ActivityTransition 등록
      await _registerNativeGeofences();

      // 서비스 유지보수 타이머 (30분)
      _startServiceMaintenance();

      print('[SLM] ✅ 스마트 모니터링 가동 완료 — 지오펜스 이벤트 대기 중');
    } catch (e) {
      print('[SLM] ❌ 스마트 모니터링 시작 실패: $e');
    }
  }

  /// 서비스 유지보수 타이머 (30분마다 서비스 상태 확인)
  static void _startServiceMaintenance() {
    _serviceCheckTimer?.cancel();
    _serviceCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkAndMaintainService(),
    );
  }

  /// v2: 네이티브 지오펜스 + ActivityTransition 이벤트 수신
  static void _setupNativeSignalListener() {
    if (_nativeListenerSetup) return;
    _nativeListenerSetup = true;

    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onNativeSignal') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final type = args['type'] as String?;

        if (type == 'geofence') {
          final placeId = args['placeId'] as String? ?? '';
          final isEnter = args['isEnter'] as bool? ?? true;

          print('[SLM] 📡 지오펜스: $placeId (${isEnter ? "ENTER" : "EXIT"})');

          // v2: LMS에 직접 전달 (isOuter 제거)
          if (_locationService != null) {
            _locationService!.onGeofenceEvent(placeId, isEnter);
          }
        } else if (type == 'activityTransition') {
          final isMoving = args['isMoving'] as bool? ?? false;

          print('[SLM] 🚶 ActivityTransition: ${isMoving ? "이동 시작" : "정지"}');

          // v2: LMS에 ActivityTransition 전달
          if (_locationService != null) {
            _locationService!.onActivityTransition(isMoving);
          }
        }
      }
    });
    print('[SLM] ✅ v2 네이티브 리스너 설정 완료 (지오펜스 + ActivityTransition)');
  }

  /// 서비스 상태 체크 및 복구
  static Future<void> _checkAndMaintainService() async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();

      if (activeAlarms == 0) {
        print('[SLM] 📭 활성 알람 없음 - 서비스 중단');
        if (_locationService != null) {
          await _locationService!.stopMonitoring();
        }
        return;
      }

      // 서비스가 죽었으면 재시작
      if (_locationService == null || !_locationService!.isRunning) {
        print('[SLM] 🔄 LocationMonitorService 재시작');

        if (!await BackgroundServiceManager.isRunning()) {
          await BackgroundServiceManager.startService();
        }

        _locationService = LocationMonitorService();
        await _locationService!.startBackgroundMonitoring((type, alarm) {
          print('[SLM] 🚨 알람 트리거 (복구): ${alarm['name']} ($type)');
        });

        // ★ 복구 시에도 네이티브 지오펜스 재등록
        await _registerNativeGeofences();
      }
    } catch (e) {
      print('[SLM] ❌ 서비스 체크 실패: $e');
    }
  }

  /// 활성 알람 개수 확인
  static Future<int> _getActiveAlarmsCount() async {
    try {
      if (HiveHelper.isInitialized) {
        final alarms = HiveHelper.getLocationAlarms();
        return alarms.where((alarm) => alarm['enabled'] == true).length;
      }
      return 0;
    } catch (e) {
      print('[SLM] ❌ 활성 알람 개수 확인 실패: $e');
      return 0;
    }
  }

  // ========== 모니터링 중단 ==========

  static Future<void> stopMonitoring() async {
    try {
      print('[SLM] 🛑 모니터링 중단');

      _serviceCheckTimer?.cancel();
      _serviceCheckTimer = null;

      if (_locationService != null) {
        await _locationService!.stopMonitoring();
        _locationService = null;
      }

      print('[SLM] ✅ 모니터링 완전 중단');
    } catch (e) {
      print('[SLM] ❌ 모니터링 중단 실패: $e');
    }
  }

  // ========== 외부 인터페이스 ==========

  /// 상태 정보
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _locationService?.isRunning ?? false,
      'serviceCheckActive': _serviceCheckTimer != null,
      'locationServiceActive': _locationService != null,
      'monitoringProfile': _locationService?.currentMonitoringProfile,
    };
  }

  /// 장소 상태 초기화
  static Future<void> resetPlaceState(String placeName) async {
    try {
      if (_locationService != null) {
        await _locationService!.resetPlaceState(placeName);
        print('[SLM] ✅ 장소 상태 초기화: $placeName');
      }
    } catch (e) {
      print('[SLM] ❌ 장소 상태 초기화 실패: $e');
    }
  }

  /// ★ 네이티브 지오펜스 + ActivityTransition 등록
  /// startSmartMonitoring() 및 복구 시 호출
  static Future<void> _registerNativeGeofences() async {
    try {
      final places = _buildNativePlacesList();
      if (places.isEmpty) {
        print('[SLM] 📭 등록할 네이티브 장소 없음');
        return;
      }
      await _nativeChannel.invokeMethod('startMonitoring', {'places': places});
      print(
        '[SLM] ✅ 네이티브 지오펜스 등록 완료 (${places.length}개) — ENTER+EXIT+ActivityTransition',
      );
    } catch (e) {
      print('[SLM] ⚠️ 네이티브 지오펜스 등록 실패 (앱 포그라운드 아닐 수 있음): $e');
    }
  }

  /// 장소 목록 변경 시 호출 — LMS + 네이티브 지오펜스 동시 업데이트
  static Future<void> updatePlaces() async {
    // 1. Flutter LMS 업데이트
    if (_locationService != null) {
      await _locationService!.updatePlaces();
    }

    // 2. 네이티브 SmartLocationManager 지오펜스 재등록
    try {
      final places = _buildNativePlacesList();
      if (places.isNotEmpty) {
        await _nativeChannel.invokeMethod('updatePlaces', {'places': places});
        print('[SLM] ✅ 네이티브 지오펜스 재등록 완료 (${places.length}개)');
      }
    } catch (e) {
      print('[SLM] ⚠️ 네이티브 지오펜스 업데이트 실패 (앱 포그라운드 아닐 수 있음): $e');
    }
  }

  /// Hive 알람+장소 데이터를 네이티브 AlarmPlace 형식으로 변환
  /// ★ 같은 장소에 여러 알람이 있어도 지오펜스는 장소당 1개만 등록
  ///   (ENTER+EXIT 모두 감시). id는 첫 번째 알람의 id 사용.
  ///   LMS의 _processEntryAlarm/_processExitAlarm에서 placeName으로
  ///   매칭하므로 같은 장소의 다른 알람도 정상 트리거됨.
  static List<Map<String, dynamic>> _buildNativePlacesList() {
    try {
      final alarms =
          HiveHelper.getLocationAlarms()
              .where((a) => a['enabled'] == true)
              .toList();
      final places = HiveHelper.getSavedLocations();

      final result = <Map<String, dynamic>>[];
      final seen = <String>{}; // placeName 기준 중복 제거

      for (final alarm in alarms) {
        final placeName = (alarm['place'] ?? alarm['locationName']) as String?;
        if (placeName == null) continue;
        if (seen.contains(placeName)) continue;

        final place = places.firstWhere(
          (p) => p['name'] == placeName,
          orElse: () => <String, dynamic>{},
        );
        if (place.isEmpty) continue;

        final lat = (place['lat'] ?? place['latitude']);
        final lng = (place['lng'] ?? place['longitude']);
        final radius = (place['radius'] ?? place['geofenceRadius'] ?? 100);
        if (lat == null || lng == null) continue;

        seen.add(placeName);
        // ★ 지오펜스 id = alarmId (UUID). 같은 장소 다른 알람은
        //   placeName 매칭으로 처리됨.
        result.add({
          'id': alarm['id'] ?? placeName,
          'name': placeName,
          'latitude': (lat as num).toDouble(),
          'longitude': (lng as num).toDouble(),
          'radiusMeters': (radius as num).toDouble(),
          'triggerType': alarm['trigger'] ?? 'entry',
          'enabled': true,
          'isFirstOnly': alarm['isFirstOnly'] ?? false,
          'startTimeMs': alarm['startTimeMs'] ?? 0,
          'isTimeSpecified': alarm['isTimeSpecified'] ?? false,
        });
      }
      return result;
    } catch (e) {
      print('[SLM] ❌ _buildNativePlacesList 실패: $e');
      return [];
    }
  }

  /// inside 상태 조회
  static bool? getInsideStatus(String placeName) {
    return _locationService?.getInsideStatus(placeName);
  }

  /// 디버그 정보 출력
  static void printDebugInfo() {
    final status = getStatus();
    print('[SLM] 📊 상태:');
    print('   - 실행 중: ${status['isRunning']}');
    print('   - 서비스 체크: ${status['serviceCheckActive']}');
    print('   - 현재 interval: ${status['currentInterval']}ms');
  }
}

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
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/app_log_buffer.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/background_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';

class SmartLocationMonitor {
  // 타이머
  static Timer? _serviceCheckTimer;

  // 상태
  static LocationMonitorService? _locationService;

  // 네이티브 신호 수신 채널
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.bnt0514.ringinout/smart_location',
  );
  static bool _nativeListenerSetup = false;

  // ========== 통합 스마트 모니터링 ==========

  /// 모니터링 시작 (유일한 진입점)
  static Future<void> startSmartMonitoring() async {
    try {
      AppLogBuffer.record('SLM', '🧠 스마트 모니터링 시작');

      await BackgroundServiceManager.initialize();

      final ownerUid = HiveHelper.activeOwnerUid;
      if (ownerUid == null || ownerUid.isEmpty) {
        AppLogBuffer.record('SLM', 'active owner missing; stop monitoring');
        await stopMonitoring();
        return;
      }

      final activeAlarms = await _getActiveAlarmsCount();
      AppLogBuffer.record('SLM', '🎯 활성 알람 ${activeAlarms}개 발견');

      if (activeAlarms == 0) {
        AppLogBuffer.record('SLM', '📭 활성 알람이 없어 모니터링 중단');
        await stopMonitoring();
        return;
      }

      // 백그라운드 서비스 시작
      if (!await BackgroundServiceManager.isRunning()) {
        AppLogBuffer.record('SLM', '🚀 백그라운드 서비스 시작');
        await BackgroundServiceManager.startService();
      } else {
        AppLogBuffer.record('SLM', '✅ 백그라운드 서비스 이미 실행 중');
      }

      // LocationMonitorService 시작
      _locationService = LocationMonitorService();
      AppLogBuffer.record('SLM', '📡 LMS.startBackgroundMonitoring() 호출');
      await _locationService!.startBackgroundMonitoring((type, alarm) {
        AppLogBuffer.record('SLM', '🚨 알람 트리거: ${alarm["name"]} ($type)');
      });
      AppLogBuffer.record(
        'SLM',
        '✅ LMS 시작 완료. isRunning=${_locationService!.isRunning}',
      );

      // 네이티브 지오펜스 이벤트 수신 설정
      _setupNativeSignalListener();

      // ★ 네이티브 지오펜스 + ActivityTransition 등록
      await _registerNativeGeofences();

      // 서비스 유지보수 타이머 (30분)
      _startServiceMaintenance();

      AppLogBuffer.record('SLM', '✅ 스마트 모니터링 가동 완료 — 지오펜스 이벤트 대기 중');
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ 스마트 모니터링 시작 실패: $e');
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

          AppLogBuffer.record(
            'SLM',
            '📡 지오펜스 수신: $placeId (${isEnter ? "ENTER" : "EXIT"})',
          );

          // v2: LMS에 직접 전달 (isOuter 제거)
          if (_locationService != null) {
            AppLogBuffer.record(
              'SLM',
              '→ LMS.onGeofenceEvent() 전달 (isRunning=${_locationService!.isRunning})',
            );
            _locationService!.onGeofenceEvent(placeId, isEnter);
          } else {
            AppLogBuffer.record(
              'SLM',
              '⚠️ _locationService==null — 지오펜스 이벤트 드롭!',
            );
          }
        } else if (type == 'activityTransition') {
          final isMoving = args['isMoving'] as bool? ?? false;

          AppLogBuffer.record(
            'SLM',
            '🚶 ActivityTransition: ${isMoving ? "이동 시작" : "정지"}',
          );

          // v2: LMS에 ActivityTransition 전달
          if (_locationService != null) {
            _locationService!.onActivityTransition(isMoving);
          }
        } else if (type == 'wifi') {
          final placeId = args['placeId'] as String? ?? '';
          final isEnter = args['isEnter'] as bool? ?? true;

          AppLogBuffer.record(
            'SLM',
            '📶 Wi-Fi: $placeId (${isEnter ? "ENTER" : "EXIT"})',
          );

          if (_locationService != null) {
            _locationService!.onWifiEvent(placeId, isEnter);
          }
        } else if (type == 'wifiHardware') {
          final isEnabled = args['isEnabled'] as bool? ?? true;

          AppLogBuffer.record(
            'SLM',
            '📶 Wi-Fi 하드웨어: ${isEnabled ? "ON" : "OFF"}',
          );

          if (_locationService != null) {
            _locationService!.onWifiHardwareChanged(isEnabled);
          }
        } else if (type == 'bluetooth') {
          if (!AppConfig.enableBluetoothFeatures) {
            AppLogBuffer.record(
              'SLM',
              'Bluetooth event ignored: feature disabled',
            );
            return;
          }
          // ✅ 블루투스 장소 진입/진출 이벤트
          final placeId = args['placeId'] as String? ?? '';
          final isEnter = args['isEnter'] as bool? ?? true;

          AppLogBuffer.record(
            'SLM',
            '🔵 Bluetooth: $placeId (${isEnter ? "ENTER" : "EXIT"})',
          );

          if (_locationService != null) {
            _locationService!.onBluetoothEvent(placeId, isEnter);
          }
        } else if (type == 'bluetoothDevice') {
          if (!AppConfig.enableBluetoothFeatures) {
            AppLogBuffer.record(
              'SLM',
              'Bluetooth device event ignored: feature disabled',
            );
            return;
          }
          // ✅ 독립형 기기 알람 BT 연결/해제 이벤트
          final macAddress = args['macAddress'] as String? ?? '';
          final deviceName = args['deviceName'] as String? ?? '';
          final isConnected = args['isConnected'] as bool? ?? true;

          final btLog =
              '🔵 BT ${isConnected ? "연결" : "해제"}: $deviceName ($macAddress)';
          AppLogBuffer.record('BT', btLog);

          if (_locationService != null) {
            _locationService!.onBluetoothDeviceEvent(
              macAddress,
              deviceName,
              isConnected,
            );
          }
        }
      }
    });
    AppLogBuffer.record(
      'SLM',
      '✅ 네이티브 리스너 설정 완료 (지오펜스 + ActivityTransition + Wi-Fi + Bluetooth)',
    );
  }

  /// 서비스 상태 체크 및 복구
  static Future<void> _checkAndMaintainService() async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();
      AppLogBuffer.record(
        'SLM',
        '🔁 30분 서비스 체크: 활성 알람 ${activeAlarms}개, lmsRunning=${_locationService?.isRunning}, lmsNull=${_locationService == null}',
      );

      final ownerUid = HiveHelper.activeOwnerUid;
      if (ownerUid == null || ownerUid.isEmpty) {
        AppLogBuffer.record('SLM', 'active owner missing; stop service');
        await stopMonitoring();
        return;
      }

      if (activeAlarms == 0) {
        AppLogBuffer.record('SLM', '📭 활성 알람 없음 - 서비스 중단');
        await stopMonitoring();
        return;
      }

      // 서비스가 죽었으면 재시작
      if (_locationService == null || !_locationService!.isRunning) {
        AppLogBuffer.record('SLM', '🔄 LMS 죽어있음 — 재시작');

        if (!await BackgroundServiceManager.isRunning()) {
          await BackgroundServiceManager.startService();
        }

        _locationService = LocationMonitorService();
        await _locationService!.startBackgroundMonitoring((type, alarm) {
          AppLogBuffer.record(
            'SLM',
            '🚨 알람 트리거 (복구): ${alarm["name"]} ($type)',
          );
        });

        // ★ 복구 시에도 네이티브 지오펜스 재등록
        await _registerNativeGeofences();
      } else {
        AppLogBuffer.record('SLM', '✅ LMS 정상 실행 중');
      }
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ 서비스 체크 실패: $e');
    }
  }

  /// 활성 알람 개수 확인
  static Future<int> _getActiveAlarmsCount() async {
    try {
      if (HiveHelper.isInitialized) {
        final alarms = HiveHelper.getLocationAlarms();
        final count = alarms.where((alarm) => alarm['enabled'] == true).length;
        return count;
      }
      AppLogBuffer.record('SLM', '⚠️ _getActiveAlarmsCount: HiveHelper 미초기화');
      return 0;
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ 활성 알람 개수 확인 실패: $e');
      return 0;
    }
  }

  // ========== 모니터링 중단 ==========

  static Future<void> stopMonitoring() async {
    try {
      AppLogBuffer.record('SLM', '🛑 모니터링 중단');

      _serviceCheckTimer?.cancel();
      _serviceCheckTimer = null;

      if (_locationService != null) {
        await _locationService!.stopMonitoring();
        _locationService = null;
      }

      try {
        await _nativeChannel.invokeMethod('stopMonitoring');
        AppLogBuffer.record('SLM', 'native monitoring stopped');
      } catch (e) {
        AppLogBuffer.record('SLM', 'native monitoring stop failed: $e');
      }

      await LocationMonitorService.clearWatchdogHeartbeat();

      AppLogBuffer.record('SLM', '✅ 모니터링 완전 중단');
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ 모니터링 중단 실패: $e');
    }
  }

  // ========== 외부 인터페이스 ==========

  /// 상태 정보
  static Future<void> cancelAllSnoozes() async {
    try {
      await _nativeChannel.invokeMethod('cancelAllSnoozes');
      AppLogBuffer.record('SLM', 'native snoozes cancelled');
    } catch (e) {
      AppLogBuffer.record('SLM', 'native snooze cancel failed: $e');
    }
  }

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
        AppLogBuffer.record('SLM', '✅ 장소 상태 초기화: $placeName');
      }
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ 장소 상태 초기화 실패: $e');
    }
  }

  /// ★ 네이티브 지오펜스 + ActivityTransition 등록
  /// startSmartMonitoring() 및 복구 시 호웉
  static Future<void> _registerNativeGeofences() async {
    try {
      final ownerUid = HiveHelper.activeOwnerUid;
      if (ownerUid == null || ownerUid.isEmpty) {
        AppLogBuffer.record(
          'SLM',
          'active owner missing; stop native register',
        );
        await _nativeChannel.invokeMethod('stopMonitoring');
        return;
      }

      final places = _buildNativePlacesList();
      final deviceAlarmMacs = _buildDeviceAlarmMacList();
      AppLogBuffer.record(
        'SLM',
        '📋 _buildNativePlacesList 결과: ${places.length}개 → ${places.map((p) => p["name"] ?? p["id"]).toList()}',
      );
      if (places.isEmpty && deviceAlarmMacs.isEmpty) {
        AppLogBuffer.record('SLM', '🔴 등록할 네이티브 장소 없음! 지오펜스 미등록 — 알람 동작 불가');
        await _nativeChannel.invokeMethod('stopMonitoring');
        return;
      }
      await _nativeChannel.invokeMethod('startMonitoring', {
        'places': places,
        'deviceAlarmMacs': deviceAlarmMacs,
        'ownerUid': ownerUid,
      });
      await _recordNativeStatus('startMonitoring');
      AppLogBuffer.record(
        'SLM',
        '✅ 네이티브 지오펜스 등록 완료 (${places.length}개) — BT 기기: ${deviceAlarmMacs.length}개',
      );
    } catch (e) {
      AppLogBuffer.record('SLM', '⚠️ 네이티브 지오펜스 등록 실패: $e');
    }
  }

  /// 장소 목록 변경 시 호웉 — LMS + 네이티브 지오펜스 동시 업데이트
  static Future<void> updatePlaces() async {
    final ownerUid = HiveHelper.activeOwnerUid;
    if (ownerUid == null || ownerUid.isEmpty) {
      AppLogBuffer.record('SLM', 'active owner missing; stop updatePlaces');
      await stopMonitoring();
      return;
    }

    // 1. Flutter LMS 업데이트
    if (_locationService != null) {
      await _locationService!.updatePlaces();
    }

    // 2. 네이티브 SmartLocationManager 지오펜스 재등록
    try {
      final places = _buildNativePlacesList();
      final deviceAlarmMacs = _buildDeviceAlarmMacList();
      await _nativeChannel.invokeMethod('updatePlaces', {
        'places': places,
        'deviceAlarmMacs': deviceAlarmMacs,
        'ownerUid': ownerUid,
      });
      await _recordNativeStatus('updatePlaces');
      AppLogBuffer.record(
        'SLM',
        '✅ 네이티브 지오펜스 재등록 완료 (${places.length}개, BT 기기: ${deviceAlarmMacs.length}개)',
      );
    } catch (e) {
      AppLogBuffer.record('SLM', '⚠️ 네이티브 지오펜스 업데이트 실패: $e');
    }
  }

  /// Hive 알람+장소 데이터를 네이티브 AlarmPlace 형식으로 변환
  /// ★ 같은 장소에 여러 알람이 있어도 지오펜스는 장소당 1개만 등록
  ///   (ENTER+EXIT 모두 감시). id는 저장된 placeId를 사용한다.
  static List<Map<String, dynamic>> _buildNativePlacesList() {
    try {
      final allAlarms = HiveHelper.getLocationAlarms();
      final alarms = allAlarms.where((a) => a['enabled'] == true).toList();
      final places = HiveHelper.getSavedLocations();

      AppLogBuffer.record(
        'SLM',
        '🔍 _buildNativePlacesList: 전체 알람=${allAlarms.length}, 활성=${alarms.length}, 장소=${places.length}',
      );

      final result = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (final alarm in alarms) {
        final placeName = (alarm['place'] ?? alarm['locationName']) as String?;
        final alarmPlaceId = alarm['placeId']?.toString();
        if ((placeName == null || placeName.isEmpty) &&
            (alarmPlaceId == null || alarmPlaceId.isEmpty)) {
          AppLogBuffer.record(
            'SLM',
            '⚠️ 알람 [${alarm["name"]}] placeName/placeId 모두 없음 — 스킵',
          );
          continue;
        }

        final place = places.firstWhere(
          (p) =>
              (alarmPlaceId != null &&
                  alarmPlaceId.isNotEmpty &&
                  p['id']?.toString() == alarmPlaceId) ||
              p['name'] == placeName,
          orElse: () => <String, dynamic>{},
        );
        if (place.isEmpty) {
          AppLogBuffer.record(
            'SLM',
            '🔴 알람 [${alarm["name"]}] 장소 매칭 실패! alarmPlaceId=$alarmPlaceId, placeName=$placeName',
          );
          continue;
        }

        final nativePlaceId =
            place['id']?.toString() ?? alarmPlaceId ?? placeName ?? '';
        if (nativePlaceId.isEmpty || seen.contains(nativePlaceId)) continue;

        final lat = (place['lat'] ?? place['latitude']);
        final lng = (place['lng'] ?? place['longitude']);
        final radius = (place['radius'] ?? place['geofenceRadius'] ?? 100);
        if (lat == null || lng == null) continue;

        final hasWifiModeAlarm = alarms.any((candidate) {
          final candidatePlaceId = candidate['placeId']?.toString();
          final candidatePlaceName =
              (candidate['place'] ?? candidate['locationName'])?.toString();
          final matchesPlace =
              (candidatePlaceId != null &&
                  candidatePlaceId.isNotEmpty &&
                  candidatePlaceId == nativePlaceId) ||
              candidatePlaceName == place['name']?.toString();
          return matchesPlace &&
              AlarmDetectionMode.resolve(candidate, place: place) ==
                  AlarmDetectionMode.wifi;
        });

        seen.add(nativePlaceId);
        AppLogBuffer.record(
          'SLM',
          '✅ 장소 추가: ${place["name"]} (id=$nativePlaceId, wifiMode=$hasWifiModeAlarm)',
        );
        result.add({
          'id': nativePlaceId,
          'ownerUid': place['ownerUid']?.toString() ?? '',
          'name': place['name'] ?? placeName,
          'latitude': (lat as num).toDouble(),
          'longitude': (lng as num).toDouble(),
          'radiusMeters': (radius as num).toDouble(),
          'triggerType': alarm['trigger'] ?? 'entry',
          'enabled': true,
          'isFirstOnly': alarm['isFirstOnly'] ?? false,
          'startTimeMs': alarm['startTimeMs'] ?? 0,
          'isTimeSpecified': alarm['isTimeSpecified'] ?? false,
          // Wi-Fi 모드 알람이 있는 장소에만 Wi-Fi 네트워크 데이터 전달
          'wifiNetworks':
              hasWifiModeAlarm
                  ? ((place['wifiNetworks'] as List?)
                          ?.map(
                            (w) => {
                              'ssid': (w as Map)['ssid'] ?? '',
                              'bssid': w['bssid'] ?? '',
                            },
                          )
                          .toList() ??
                      [])
                  : [],
          // ✅ 블루투스 기기 데이터 전달 (장소에 등록된 BT 기기 목록)
          'bluetoothDevices':
              AppConfig.enableBluetoothFeatures
                  ? ((place['bluetoothDevices'] as List?)
                          ?.map(
                            (d) => {
                              'name': (d as Map)['name'] ?? '',
                              'macAddress': d['macAddress'] ?? '',
                              'deviceType': d['deviceType'] ?? 0,
                              'alias': d['alias'] ?? '',
                            },
                          )
                          .toList() ??
                      [])
                  : [],
        });
      }
      return result;
    } catch (e) {
      AppLogBuffer.record('SLM', '❌ _buildNativePlacesList 실패: $e');
      return [];
    }
  }

  /// 활성화된 독립형 기기 알람의 MAC 주소 목록 반환 (네이티브 전달용)
  static Future<void> _recordNativeStatus(String source) async {
    try {
      final status = await _nativeChannel.invokeMethod('getStatus');
      if (status is! Map) return;
      final wifi = status['wifi'];
      final wifiCount =
          wifi is Map ? (wifi['wifiPlaceCount']?.toString() ?? '?') : '?';
      final wifiMonitoring =
          wifi is Map ? (wifi['isMonitoring']?.toString() ?? '?') : '?';
      final wifiConnected =
          wifi is Map ? (wifi['connectedPlaceIds']?.toString() ?? '?') : '?';
      final wifiPendingEnter =
          wifi is Map ? (wifi['pendingEnterDebounce']?.toString() ?? '?') : '?';
      final nativePlaceCount =
          status['alarmCount']?.toString() ??
          status['placeCount']?.toString() ??
          '?';
      final nativeState =
          status['state']?.toString() ??
          status['isMonitoring']?.toString() ??
          '?';
      AppLogBuffer.record(
        'SLM',
        'native status after $source: places=$nativePlaceCount, '
            'state=$nativeState, wifiPlaces=$wifiCount, '
            'wifiMonitoring=$wifiMonitoring, wifiConnected=$wifiConnected, '
            'wifiPendingEnter=$wifiPendingEnter',
      );
    } catch (e) {
      AppLogBuffer.record('SLM', 'native status read failed after $source: $e');
    }
  }

  static List<String> _buildDeviceAlarmMacList() {
    if (!AppConfig.enableBluetoothFeatures) return [];
    try {
      return HiveHelper.getActiveDeviceAlarms()
          .map((a) => (a['macAddress'] ?? '').toString().toUpperCase())
          .where((mac) => mac.isNotEmpty)
          .toSet()
          .toList();
    } catch (e) {
      print('[SLM] ❌ _buildDeviceAlarmMacList 실패: $e');
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

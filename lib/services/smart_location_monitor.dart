// lib/services/smart_location_monitor.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/background_service.dart'; // ✅ 올바른 import
import 'package:ringinout/services/hive_helper.dart';

class SmartLocationMonitor {
  static Timer? _precisionTimer;
  static Timer? _serviceCheckTimer;
  static StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  static bool _isMoving = false;
  static DateTime _lastMovementTime = DateTime.now();
  static LocationMonitorService? _locationService;

  // ✅ 통합 스마트 모니터링 시작 (수정된 구조)
  static Future<void> startSmartMonitoring() async {
    try {
      print('🧠 통합 스마트 모니터링 시작');

      // ✅ 1. 활성 알람 체크 (한 번만)
      final activeAlarms = await _getActiveAlarmsCount();
      print('🎯 활성 알람 $activeAlarms개 발견');

      if (activeAlarms == 0) {
        print('📭 활성 알람이 없어 지오펜스 서비스 중단');
        final locationService = LocationMonitorService();
        await locationService.stopMonitoring();
        return;
      }

      // ✅ 2. 백그라운드 서비스 상태 확인 (수정)
      if (await BackgroundServiceManager.isRunning()) {
        print('✅ 백그라운드 서비스 이미 실행 중');
      } else {
        print('🚀 백그라운드 서비스 시작 필요');
        await BackgroundServiceManager.startService();
      }

      // ✅ 3. LocationMonitorService 시작 (기존 메서드 사용)
      _locationService = LocationMonitorService();
      await _locationService!.startBackgroundMonitoring((type, alarm) {
        print('🚨 지오펜스 알람: ${alarm['name']} ($type)');
        // 알람 처리 로직은 LocationMonitorService에서 처리
      });

      // ✅ 4. 메인 앱 모니터링 시작
      await _startMainAppMonitoring();
    } catch (e) {
      print('❌ 스마트 모니터링 시작 실패: $e');
    }
  }

  // ✅ 메인 앱 모니터링 시작 (기존 로직 통합)
  static Future<void> _startMainAppMonitoring() async {
    try {
      print('✅ 메인 앱 위치 서비스 시작');

      // 움직임 감지 시작
      await _startMovementDetection();

      // 정밀 모니터링 모드 시작
      _startPrecisionMode();
    } catch (e) {
      print('❌ 메인 앱 모니터링 시작 실패: $e');
    }
  }

  // ✅ 활성 알람 개수 확인 (단순화된 버전)
  static Future<int> _getActiveAlarmsCount() async {
    try {
      // HiveHelper가 초기화되어 있으면 항상 HiveHelper만 사용
      if (HiveHelper.isInitialized) {
        final alarms = HiveHelper.getLocationAlarms();
        final count = alarms.where((alarm) => alarm['enabled'] == true).length;
        print('✅ HiveHelper로 활성 알람 $count개 확인 (SmartLocationMonitor)');
        return count;
      } else {
        print('⚠️ HiveHelper가 초기화되지 않음 (SmartLocationMonitor)');
        return 0;
      }
    } catch (e) {
      print('❌ 활성 알람 개수 확인 실패 (SmartLocationMonitor): $e');
      return 0;
    }
  }

  // ✅ 움직임 감지 시작
  static Future<void> _startMovementDetection() async {
    try {
      _accelerometerSubscription?.cancel();

      _accelerometerSubscription = accelerometerEvents.listen((
        AccelerometerEvent event,
      ) {
        double magnitude =
            (event.x * event.x + event.y * event.y + event.z * event.z);

        if (magnitude > 12.0) {
          // 움직임 임계값
          if (!_isMoving) {
            _isMoving = true;
            _lastMovementTime = DateTime.now();
            print('🚶‍♂️ 움직임 감지 - 정밀 모니터링 모드');
            _startPrecisionMode();
          } else {
            _lastMovementTime = DateTime.now();
          }
        }
      });

      // 정적 상태 감지 타이머
      Timer.periodic(const Duration(minutes: 5), (timer) {
        if (_isMoving &&
            DateTime.now().difference(_lastMovementTime).inMinutes > 5) {
          _isMoving = false;
          print('🛑 정적 상태 감지 - 일반 모니터링 모드');
          _switchToNormalMode();
        }
      });
    } catch (e) {
      print('❌ 움직임 감지 시작 실패: $e');
    }
  }

  // ✅ 정밀 모니터링 모드 (움직임 중)
  static void _startPrecisionMode() {
    _precisionTimer?.cancel();

    _precisionTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      try {
        print('🎯 정밀 모드: 1분마다 서비스 체크');
        await _checkAndMaintainService();
      } catch (e) {
        print('❌ 정밀 모드 체크 실패: $e');
      }
    });
  }

  // ✅ 일반 모니터링 모드 (정적 상태)
  static void _switchToNormalMode() {
    _precisionTimer?.cancel();

    _serviceCheckTimer?.cancel();
    _serviceCheckTimer = Timer.periodic(const Duration(minutes: 10), (
      timer,
    ) async {
      try {
        print('🔄 일반 모드: 10분마다 서비스 체크');
        await _checkAndMaintainService();
      } catch (e) {
        print('❌ 일반 모드 체크 실패: $e');
      }
    });
  }

  // ✅ 서비스 상태 체크 및 유지
  static Future<void> _checkAndMaintainService() async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();
      print('🎯 활성 알람 $activeAlarms개 발견');

      if (activeAlarms == 0) {
        print('📭 활성화된 알람이 없어 지오펜스 서비스를 시작하지 않음');
        if (_locationService != null) {
          await _locationService!.stopMonitoring();
          print('🛑 지오펜스 서비스 중단 완료');
        }
        return;
      }

      // 백그라운드 서비스 상태 확인
      if (await BackgroundServiceManager.isRunning()) {
        print('✅ 백그라운드 서비스 이미 실행 중');

        // LocationMonitorService가 실행 중인지 확인하고 재시작 (필요시)
        if (_locationService == null) {
          _locationService = LocationMonitorService();
          await _locationService!.startBackgroundMonitoring((type, alarm) {
            print('🚨 지오펜스 알람: ${alarm['name']} ($type)');
          });
        }
      } else {
        print('🚀 백그라운드 서비스 재시작 필요');
        await BackgroundServiceManager.startService();

        _locationService = LocationMonitorService();
        await _locationService!.startBackgroundMonitoring((type, alarm) {
          print('🚨 지오펜스 알람: ${alarm['name']} ($type)');
        });
      }
    } catch (e) {
      print('❌ 서비스 체크 실패: $e');
    }
  }

  // ✅ 모니터링 중단
  static Future<void> stopMonitoring() async {
    try {
      print('🛑 SmartLocationMonitor 중단');

      // 타이머 정리
      _precisionTimer?.cancel();
      _serviceCheckTimer?.cancel();
      _precisionTimer = null;
      _serviceCheckTimer = null;

      // 센서 구독 해제
      await _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;

      // LocationMonitorService 중단
      if (_locationService != null) {
        await _locationService!.stopMonitoring();
        _locationService = null;
      }

      _isMoving = false;

      print('✅ SmartLocationMonitor 완전 중단 완료');
    } catch (e) {
      print('❌ SmartLocationMonitor 중단 실패: $e');
    }
  }

  // ✅ 상태 정보 가져오기
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _precisionTimer != null || _serviceCheckTimer != null,
      'isMoving': _isMoving,
      'lastMovementTime': _lastMovementTime.toIso8601String(),
      'precisionModeActive': _precisionTimer != null,
      'normalModeActive': _serviceCheckTimer != null,
      'locationServiceActive': _locationService != null,
    };
  }

  // ✅ 디버그 정보 출력
  static void printDebugInfo() {
    final status = getStatus();
    print('📊 SmartLocationMonitor 상태:');
    print('   - 실행 중: ${status['isRunning']}');
    print('   - 움직임 중: ${status['isMoving']}');
    print('   - 마지막 움직임: ${status['lastMovementTime']}');
    print('   - 정밀 모드: ${status['precisionModeActive']}');
    print('   - 일반 모드: ${status['normalModeActive']}');
    print('   - 위치 서비스: ${status['locationServiceActive']}');
  }
}

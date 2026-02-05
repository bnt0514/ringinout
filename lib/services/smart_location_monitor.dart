// lib/services/smart_location_monitor.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/background_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/motion_detector.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geofence_service/geofence_service.dart' as geofence;

/// 거리 변화 추세
enum DistanceTrend { closer, farther, stable }

/// 모니터링 프로파일 설정
class MonitoringProfile {
  final int intervalMs;
  final int accuracyM;
  final int loiteringDelayMs;
  final int statusChangeDelayMs;

  const MonitoringProfile({
    required this.intervalMs,
    required this.accuracyM,
    required this.loiteringDelayMs,
    required this.statusChangeDelayMs,
  });

  @override
  String toString() =>
      'MonitoringProfile(interval: ${intervalMs}ms, accuracy: ${accuracyM}m, loitering: ${loiteringDelayMs}ms)';
}

/// A++ 등급 스마트 위치 모니터링 시스템
///
/// 핵심 개선사항:
/// 1. GeofenceService 콜백 기반 프로파일 업데이트 (중복 GPS 제거)
/// 2. 500m 이내: 최고 정밀도 모드 (20m 정확도)
/// 3. 1km 이내: 고정밀도 모드 (30m 정확도)
/// 4. 위치 변화량 + 속도 기반 정지 판별
/// 5. 거리 추세 기반 예측적 interval 조절 (가까워지면 40% 단축)
class SmartLocationMonitor {
  // 타이머
  static Timer? _precisionTimer;
  static Timer? _serviceCheckTimer;

  // 상태
  static bool _isMoving = false;
  static DateTime _lastMovementTime = DateTime.now();
  static LocationMonitorService? _locationService;
  static DateTime? _lastProfileUpdate;

  // 거리 추적
  static double? _lastNearestDistanceM;
  static Position? _lastPosition;
  static DateTime? _lastPositionTime;

  // 상수
  static const Duration _stationaryDetectWindow = Duration(minutes: 5);
  static const double _movingSpeedThresholdMps = 1.0;
  static const double _minMovementDistanceM = 30.0; // 30m 미만 이동 = 정지로 간주

  // ✅ GeofenceService 위치 콜백용 캐시
  static Position? _cachedPosition;
  static DateTime? _cachedPositionTime;

  // ✅ Activity Recognition 상태
  static geofence.ActivityType _currentActivityType =
      geofence.ActivityType.STILL;
  static bool _hasExitAlarm = false;
  static DateTime? _lastExitAlarmCheck;

  // ✅ MotionDetector (가속도계 기반 이동 감지)
  static bool _motionDetectorInitialized = false;

  /// MotionDetector 초기화 및 콜백 연결
  static Future<void> _initMotionDetector() async {
    if (_motionDetectorInitialized) return;

    MotionDetector.instance.onMovementStateChanged = _onMotionStateChanged;
    await MotionDetector.instance.startMonitoring();
    _motionDetectorInitialized = true;
    print('📱 MotionDetector 초기화 완료');
  }

  /// MotionDetector 콜백 - 가속도계 기반 이동/정지 감지
  static Future<void> _onMotionStateChanged(bool isMoving) async {
    print('📱 MotionDetector 상태 변경: ${isMoving ? "이동" : "정지"}');

    // 진출 알람 캐시 업데이트
    await _updateExitAlarmCache();

    if (_hasExitAlarm) {
      if (isMoving) {
        print('🏃 진출 알람 + 가속도계 이동 감지 → 10초 interval로 전환!');
        await _applyExitAlarmMovingProfile();
      } else {
        print('🛑 진출 알람 + 가속도계 정지 감지 → GPS 체크 중단');
        await _applyExitAlarmStillProfile();
      }
    }
  }

  /// Activity Recognition 변경 핸들러 (백업용 - MotionDetector가 주력)
  /// LocationMonitorService._onActivityChanged에서 호출됨
  static Future<void> onActivityChanged(
    geofence.ActivityType prevType,
    geofence.ActivityType currType,
  ) async {
    final wasStill = _currentActivityType == geofence.ActivityType.STILL;
    _currentActivityType = currType;

    print('🚶 SmartMonitor 활동 변경: $prevType -> $currType');

    // 진출 알람 캐시 업데이트 (1분마다)
    await _updateExitAlarmCache();

    // 진출 알람이 있고, 정지 → 이동으로 바뀌면 즉시 프로파일 업데이트
    if (_hasExitAlarm && wasStill && currType != geofence.ActivityType.STILL) {
      print('🏃 진출 알람 + 이동 감지 → 10초 interval로 전환!');
      await _applyExitAlarmMovingProfile();
    } else if (_hasExitAlarm && currType == geofence.ActivityType.STILL) {
      print('🛑 진출 알람 + 정지 감지 → 60분 interval로 전환!');
      await _applyExitAlarmStillProfile();
    }
  }

  /// 진출 알람 존재 여부 캐시 업데이트
  static Future<void> _updateExitAlarmCache() async {
    final now = DateTime.now();
    if (_lastExitAlarmCheck != null &&
        now.difference(_lastExitAlarmCheck!).inMinutes < 1) {
      return; // 1분 이내 중복 체크 방지
    }
    _lastExitAlarmCheck = now;

    try {
      if (!HiveHelper.isInitialized) {
        _hasExitAlarm = false;
        return;
      }

      final alarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();

      _hasExitAlarm = alarms.any((alarm) => alarm['trigger'] == 'exit');
      print('📋 진출 알람 존재: $_hasExitAlarm');
    } catch (e) {
      print('❌ 진출 알람 캐시 업데이트 실패: $e');
      _hasExitAlarm = false;
    }
  }

  /// 진출 알람 + 이동 중 프로파일 (10초)
  static Future<void> _applyExitAlarmMovingProfile() async {
    if (_locationService == null) return;

    await _locationService!.updateMonitoringProfile(
      intervalMs: 10000, // 10초
      accuracyM: 20,
      loiteringDelayMs: 5000,
      statusChangeDelayMs: 5000,
    );
    print('🏃 진출 알람 이동 프로파일 적용: 10초 interval');
  }

  /// 진출 알람 + 정지 프로파일 (GPS 거의 안 씀)
  /// MotionDetector(가속도계)가 이동 감지하면 그때 GPS 켬
  /// 정지 상태에서는 배터리 절약을 위해 GPS 체크 최소화
  static Future<void> _applyExitAlarmStillProfile() async {
    if (_locationService == null) return;

    await _locationService!.updateMonitoringProfile(
      intervalMs: 3600000, // 60분 (가속도계가 이동 감지하면 바로 10초로 전환됨)
      accuracyM: 100, // 낮은 정확도 (배터리 절약)
      loiteringDelayMs: 60000, // 1분
      statusChangeDelayMs: 60000, // 1분
    );
    print('🛑 진출 알람 정지 프로파일: GPS 최소화 (가속도계 대기 모드)');
  }

  /// 진출 알람만 있는지 확인 (진입 알람 없음)
  static Future<bool> _hasOnlyExitAlarms() async {
    try {
      if (!HiveHelper.isInitialized) return false;

      final alarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();

      final hasEntry = alarms.any((alarm) => alarm['trigger'] == 'entry');
      final hasExit = alarms.any((alarm) => alarm['trigger'] == 'exit');

      return hasExit && !hasEntry;
    } catch (e) {
      return false;
    }
  }

  /// GeofenceService에서 호출되는 위치 업데이트 핸들러
  /// 중복 GPS 호출 없이 프로파일 업데이트 가능
  static Future<void> onLocationUpdate(
    double lat,
    double lng,
    double speed,
  ) async {
    try {
      final now = DateTime.now();

      // 캐시 업데이트
      _cachedPosition = Position(
        latitude: lat,
        longitude: lng,
        timestamp: now,
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: speed,
        speedAccuracy: 0,
      );
      _cachedPositionTime = now;

      // 이동/정지 판별
      await _updateMovementState(speed, lat, lng);

      // 프로파일 업데이트 (캐시된 위치 사용)
      await _updateMonitoringProfileFromCache();
    } catch (e) {
      if (kDebugMode) print('❌ 위치 업데이트 처리 실패: $e');
    }
  }

  /// 이동/정지 상태 판별 (속도 + 위치 변화량)
  static Future<void> _updateMovementState(
    double speed,
    double lat,
    double lng,
  ) async {
    final now = DateTime.now();

    // 1. 속도 기반 이동 감지
    bool isMovingBySpeed = speed >= _movingSpeedThresholdMps;

    // 2. 위치 변화량 기반 이동 감지 (GPS 오차 보정)
    bool isMovingByDistance = false;
    if (_lastPosition != null && _lastPositionTime != null) {
      final timeDiff = now.difference(_lastPositionTime!);
      if (timeDiff.inSeconds >= 30) {
        final distanceMoved = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          lat,
          lng,
        );
        isMovingByDistance = distanceMoved >= _minMovementDistanceM;

        if (kDebugMode && distanceMoved > 0) {
          print(
            '📏 ${timeDiff.inSeconds}초간 ${distanceMoved.toStringAsFixed(1)}m 이동',
          );
        }
      }
    }

    // 3. 둘 중 하나라도 이동으로 판단되면 이동 상태
    final isCurrentlyMoving = isMovingBySpeed || isMovingByDistance;

    if (isCurrentlyMoving) {
      if (!_isMoving) {
        _isMoving = true;
        print('🚶‍♂️ 이동 감지 - 정밀 모니터링 모드');
        _startPrecisionMode();
      }
      _lastMovementTime = now;
      _lastPosition = _cachedPosition;
      _lastPositionTime = now;
    } else if (_isMoving &&
        now.difference(_lastMovementTime) > _stationaryDetectWindow) {
      _isMoving = false;
      print('🛑 정지 상태 감지 - 일반 모니터링 모드');
      _switchToNormalMode();
    }
  }

  /// 캐시된 위치를 사용하여 프로파일 업데이트 (GPS 호출 없음!)
  static Future<void> _updateMonitoringProfileFromCache() async {
    try {
      if (_locationService == null || _cachedPosition == null) return;

      final now = DateTime.now();
      if (_lastProfileUpdate != null) {
        final diff = now.difference(_lastProfileUpdate!);
        if (diff.inSeconds < 30) return; // 30초 이내 중복 업데이트 방지
      }

      final nearestDistance = await _getNearestAlarmDistance(_cachedPosition!);
      final speed = _cachedPosition!.speed.isNaN ? 0.0 : _cachedPosition!.speed;
      final distanceTrend = _getDistanceTrend(nearestDistance);

      final profile = _selectProfile(
        isMoving: _isMoving,
        nearestDistanceM: nearestDistance,
        speedMps: speed,
        distanceTrend: distanceTrend,
      );

      await _locationService!.updateMonitoringProfile(
        intervalMs: profile.intervalMs,
        accuracyM: profile.accuracyM,
        loiteringDelayMs: profile.loiteringDelayMs,
        statusChangeDelayMs: profile.statusChangeDelayMs,
      );

      _lastProfileUpdate = now;

      if (kDebugMode) {
        print(
          '🧭 프로파일: ${profile.intervalMs}ms, ${profile.accuracyM}m, '
          'dist=${nearestDistance?.toStringAsFixed(0) ?? '-'}m, '
          'speed=${speed.toStringAsFixed(1)}m/s, trend=${distanceTrend.name}',
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ 프로파일 업데이트 실패: $e');
    }
  }

  /// 통합 스마트 모니터링 시작
  /// ⚠️ DEPRECATED: 네이티브 SmartLocationService로 대체됨
  /// 기존 호출 호환성을 위해 빈 함수로 유지
  static Future<void> startSmartMonitoring() async {
    print('⚠️ SmartLocationMonitor.startSmartMonitoring() - DEPRECATED');
    print('   → 네이티브 SmartLocationService 사용 중');
    // 기존 시스템 비활성화 - 아무 동작 안 함
    return;
  }

  /// 통합 스마트 모니터링 시작 (레거시 - 실제 구현)
  /// 기존 코드 백업용으로 남겨둠
  static Future<void> _legacyStartSmartMonitoring() async {
    try {
      print('🧠 A++ 스마트 모니터링 시작');

      await BackgroundServiceManager.initialize();

      final activeAlarms = await _getActiveAlarmsCount();
      print('🎯 활성 알람 $activeAlarms개 발견');

      if (activeAlarms == 0) {
        print('📭 활성 알람이 없어 지오펜스 서비스 중단');
        final locationService = LocationMonitorService();
        await locationService.stopMonitoring();
        await MotionDetector.instance.stopMonitoring();
        return;
      }

      // ✅ MotionDetector 초기화 (가속도계 기반 이동 감지)
      await _initMotionDetector();

      if (await BackgroundServiceManager.isRunning()) {
        print('✅ 백그라운드 서비스 이미 실행 중');
      } else {
        print('🚀 백그라운드 서비스 시작');
        await BackgroundServiceManager.startService();
      }

      _locationService = LocationMonitorService();
      await _locationService!.startBackgroundMonitoring((type, alarm) {
        print('🚨 지오펜스 알람: ${alarm['name']} ($type)');
      });

      await _startMainAppMonitoring();
      await _updateMonitoringProfile(force: true);
    } catch (e) {
      print('❌ 스마트 모니터링 시작 실패: $e');
    }
  }

  /// 메인 앱 모니터링 시작
  static Future<void> _startMainAppMonitoring() async {
    try {
      print('✅ 메인 앱 위치 서비스 시작');
      await _updateMonitoringProfile(force: true);
      // ✅ 배터리 최적화: 정밀 모드 무조건 시작 제거
      // MotionDetector가 이동 감지하면 그때 정밀 모드로 전환
      _switchToNormalMode();
    } catch (e) {
      print('❌ 메인 앱 모니터링 시작 실패: $e');
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
      print('❌ 활성 알람 개수 확인 실패: $e');
      return 0;
    }
  }

  /// 정밀 모니터링 모드 (이동 중)
  static void _startPrecisionMode() {
    _precisionTimer?.cancel();
    _serviceCheckTimer?.cancel();

    _precisionTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      try {
        if (kDebugMode) print('🎯 정밀 모드: 2분마다 서비스 체크');
        await _checkAndMaintainService();
        // ✅ 캐시가 오래된 경우에만 GPS 호출
        if (_cachedPosition == null ||
            DateTime.now()
                    .difference(_cachedPositionTime ?? DateTime(2000))
                    .inMinutes >
                3) {
          await _updateMonitoringProfile(force: false);
        }
      } catch (e) {
        print('❌ 정밀 모드 체크 실패: $e');
      }
    });
  }

  /// 일반 모니터링 모드 (정지 상태)
  /// ✅ 배터리 최적화: 10분 → 30분으로 변경, GPS 호출 제거
  static void _switchToNormalMode() {
    _precisionTimer?.cancel();
    _serviceCheckTimer?.cancel();

    _serviceCheckTimer = Timer.periodic(const Duration(minutes: 30), (
      timer,
    ) async {
      try {
        if (kDebugMode) print('🔄 일반 모드: 30분마다 서비스 체크');
        await _checkAndMaintainService();
        // ✅ 일반 모드에서는 GPS 호출 안 함 (배터리 절약)
        // GeofenceService가 지오펜스 이벤트를 처리함
      } catch (e) {
        print('❌ 일반 모드 체크 실패: $e');
      }
    });
  }

  /// 프로파일 업데이트 (GPS 호출 필요 시)
  static Future<void> _updateMonitoringProfile({bool force = false}) async {
    try {
      if (_locationService == null) return;

      final now = DateTime.now();
      if (!force && _lastProfileUpdate != null) {
        final diff = now.difference(_lastProfileUpdate!);
        if (diff.inMinutes < 2) return;
      }

      // ✅ 저전력 GPS 사용
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 100,
        ),
      );

      // 캐시 업데이트
      _cachedPosition = position;
      _cachedPositionTime = now;

      final nearestDistance = await _getNearestAlarmDistance(position);
      final speed = position.speed.isNaN ? 0.0 : position.speed;
      final distanceTrend = _getDistanceTrend(nearestDistance);

      // 이동/정지 판별
      await _updateMovementState(speed, position.latitude, position.longitude);

      final profile = _selectProfile(
        isMoving: _isMoving,
        nearestDistanceM: nearestDistance,
        speedMps: speed,
        distanceTrend: distanceTrend,
      );

      await _locationService!.updateMonitoringProfile(
        intervalMs: profile.intervalMs,
        accuracyM: profile.accuracyM,
        loiteringDelayMs: profile.loiteringDelayMs,
        statusChangeDelayMs: profile.statusChangeDelayMs,
      );

      _lastProfileUpdate = now;

      print(
        '🧭 프로파일 적용: interval=${profile.intervalMs}ms, acc=${profile.accuracyM}m, '
        'dist=${nearestDistance?.toStringAsFixed(0) ?? '-'}m, speed=${speed.toStringAsFixed(1)}m/s',
      );
    } catch (e) {
      print('❌ 모니터링 프로파일 업데이트 실패: $e');
    }
  }

  /// 가장 가까운 알람 장소까지의 거리 계산
  static Future<double?> _getNearestAlarmDistance(Position position) async {
    try {
      if (!HiveHelper.isInitialized) return null;

      final alarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();
      if (alarms.isEmpty) return null;

      final places = HiveHelper.getSavedLocations();
      if (places.isEmpty) return null;

      double? nearest;
      for (final alarm in alarms) {
        final placeName = alarm['place'];
        if (placeName == null) continue;

        final place = places.firstWhere(
          (p) => p['name'] == placeName,
          orElse: () => {},
        );
        if (place.isEmpty) continue;

        final lat = (place['latitude'] ?? place['lat']) as double?;
        final lng = (place['longitude'] ?? place['lng']) as double?;
        if (lat == null || lng == null) continue;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        if (nearest == null || distance < nearest) {
          nearest = distance;
        }
      }

      return nearest;
    } catch (e) {
      print('❌ 최근접 거리 계산 실패: $e');
      return null;
    }
  }

  /// A++ 프로파일 선택 로직 (v2 - 원거리 최적화)
  ///
  /// 핵심 원칙:
  /// - 근거리(1km 이내): 정확도 우선 → 짧은 interval
  /// - 원거리(20km+): 배터리 우선 → 도달 예상 시간 기반 interval
  /// - 가까워짐/멀어짐 추세 반영
  ///
  /// 거리별 interval 요약 (빠른 이동 기준):
  /// - 500m: 10초 | 1km: 15초 | 5km: 1.5분 | 20km: 4분
  /// - 50km: 8분 | 100km: 15분 | 100km+: 30분
  static MonitoringProfile _selectProfile({
    required bool isMoving,
    required double? nearestDistanceM,
    required double speedMps,
    required DistanceTrend distanceTrend,
  }) {
    // ✅ 진출 알람만 있는 경우: Activity 기반 프로파일
    if (_hasExitAlarm) {
      // 진출 알람이 있으면 Activity 상태에 따라 결정
      if (_currentActivityType == geofence.ActivityType.STILL) {
        // 정지 상태: 60분 interval (어차피 안 나감)
        return const MonitoringProfile(
          intervalMs: 3600000, // 60분
          accuracyM: 100,
          loiteringDelayMs: 180000,
          statusChangeDelayMs: 180000,
        );
      } else {
        // 이동 중 (WALKING, RUNNING, IN_VEHICLE 등): 10초 interval
        return const MonitoringProfile(
          intervalMs: 10000, // 10초
          accuracyM: 20,
          loiteringDelayMs: 5000,
          statusChangeDelayMs: 5000,
        );
      }
    }

    // ✅ 진입 알람: 기존 거리 기반 로직 유지
    // 정지 상태: 초절전 모드
    if (!isMoving) {
      return const MonitoringProfile(
        intervalMs: 3600000, // 60분
        accuracyM: 100,
        loiteringDelayMs: 180000,
        statusChangeDelayMs: 180000,
      );
    }

    if (nearestDistanceM != null) {
      // ✅ 500m 이내: 최고 정밀도 모드 (도착 임박)
      if (nearestDistanceM <= 500) {
        final intervalMs =
            speedMps < 2.0
                ? 30000 // 걷기: 30초
                : (speedMps < 6.0 ? 15000 : 10000); // 빠른 이동: 10~15초
        return MonitoringProfile(
          intervalMs: _applyTrend(intervalMs, distanceTrend),
          accuracyM: 20,
          loiteringDelayMs: 5000,
          statusChangeDelayMs: 5000,
        );
      }

      // ✅ 1km 이내: 고정밀도 모드 (곧 도착)
      if (nearestDistanceM <= 1000) {
        final intervalMs =
            speedMps < 2.0
                ? 45000 // 걷기: 45초
                : (speedMps < 6.0 ? 25000 : 15000); // 빠른: 15초
        return MonitoringProfile(
          intervalMs: _applyTrend(intervalMs, distanceTrend),
          accuracyM: 30,
          loiteringDelayMs: 8000,
          statusChangeDelayMs: 8000,
        );
      }

      // ✅ 1-5km: 도시 내 이동
      if (nearestDistanceM <= 5000) {
        final base =
            speedMps < 2.0
                ? 300000 // 걷기: 5분
                : (speedMps < 6.0 ? 180000 : 90000); // 빠른: 1.5분
        return MonitoringProfile(
          intervalMs: _applyTrend(base, distanceTrend),
          accuracyM: 50,
          loiteringDelayMs: 30000,
          statusChangeDelayMs: 30000,
        );
      }

      // ✅ 5-20km: 지역 간 이동
      if (nearestDistanceM <= 20000) {
        final base =
            speedMps < 2.0
                ? 900000 // 걷기: 15분
                : (speedMps < 6.0 ? 480000 : 240000); // 빠른: 4분
        return MonitoringProfile(
          intervalMs: _applyTrend(base, distanceTrend),
          accuracyM: 50,
          loiteringDelayMs: 60000,
          statusChangeDelayMs: 60000,
        );
      }

      // ✅ 20-50km: 도시 간 이동
      if (nearestDistanceM <= 50000) {
        final base =
            speedMps < 2.0
                ? 1800000 // 걷기: 30분
                : (speedMps < 6.0 ? 900000 : 480000); // 빠른: 8분
        return MonitoringProfile(
          intervalMs: _applyTrend(base, distanceTrend),
          accuracyM: 100,
          loiteringDelayMs: 120000,
          statusChangeDelayMs: 120000,
        );
      }

      // ✅ 50-100km: 장거리 이동
      if (nearestDistanceM <= 100000) {
        final base =
            speedMps < 2.0
                ? 3600000 // 걷기: 60분
                : (speedMps < 6.0 ? 1800000 : 900000); // 빠른: 15분
        return MonitoringProfile(
          intervalMs: _applyTrend(base, distanceTrend),
          accuracyM: 100,
          loiteringDelayMs: 180000,
          statusChangeDelayMs: 180000,
        );
      }
    }

    // ✅ 100km+: 초장거리 - 최대 절전
    final base =
        speedMps < 2.0
            ? 7200000 // 걷기: 120분 (2시간)
            : (speedMps < 6.0 ? 3600000 : 1800000); // 빠른: 30분
    return MonitoringProfile(
      intervalMs: _applyTrend(base, distanceTrend),
      accuracyM: 100,
      loiteringDelayMs: 300000,
      statusChangeDelayMs: 300000,
    );
  }

  /// 거리 변화 추세 계산
  static DistanceTrend _getDistanceTrend(double? currentDistance) {
    if (currentDistance == null) return DistanceTrend.stable;

    if (_lastNearestDistanceM == null) {
      _lastNearestDistanceM = currentDistance;
      return DistanceTrend.stable;
    }

    final delta = currentDistance - _lastNearestDistanceM!;
    _lastNearestDistanceM = currentDistance;

    // 50m 이상 변화가 있어야 추세로 판단
    if (delta.abs() < 50) return DistanceTrend.stable;
    return delta < 0 ? DistanceTrend.closer : DistanceTrend.farther;
  }

  /// 추세에 따른 interval 조절
  static int _applyTrend(int baseIntervalMs, DistanceTrend trend) {
    if (trend == DistanceTrend.closer) {
      return (baseIntervalMs * 0.6).round(); // ✅ 가까워지면 40% 단축
    }
    if (trend == DistanceTrend.farther) {
      return (baseIntervalMs * 1.5).round(); // 멀어지면 50% 연장
    }
    return baseIntervalMs;
  }

  /// 서비스 상태 체크 및 유지
  static Future<void> _checkAndMaintainService() async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();

      if (activeAlarms == 0) {
        print('📭 활성화된 알람 없음 - 서비스 중단');
        if (_locationService != null) {
          await _locationService!.stopMonitoring();
        }
        return;
      }

      if (await BackgroundServiceManager.isRunning()) {
        if (_locationService == null) {
          _locationService = LocationMonitorService();
          await _locationService!.startBackgroundMonitoring((type, alarm) {
            print('🚨 지오펜스 알람: ${alarm['name']} ($type)');
          });
        }
      } else {
        print('🚀 백그라운드 서비스 재시작');
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

  /// 모니터링 중단
  static Future<void> stopMonitoring() async {
    try {
      print('🛑 SmartLocationMonitor 중단');

      _precisionTimer?.cancel();
      _serviceCheckTimer?.cancel();
      _precisionTimer = null;
      _serviceCheckTimer = null;

      if (_locationService != null) {
        await _locationService!.stopMonitoring();
        _locationService = null;
      }

      _isMoving = false;
      _cachedPosition = null;
      _cachedPositionTime = null;
      _lastPosition = null;
      _lastPositionTime = null;

      print('✅ SmartLocationMonitor 완전 중단 완료');
    } catch (e) {
      print('❌ SmartLocationMonitor 중단 실패: $e');
    }
  }

  /// 상태 정보 가져오기
  static Map<String, dynamic> getStatus() {
    return {
      'isRunning': _precisionTimer != null || _serviceCheckTimer != null,
      'isMoving': _isMoving,
      'lastMovementTime': _lastMovementTime.toIso8601String(),
      'precisionModeActive': _precisionTimer != null,
      'normalModeActive': _serviceCheckTimer != null,
      'locationServiceActive': _locationService != null,
      'cachedPositionAge':
          _cachedPositionTime != null
              ? DateTime.now().difference(_cachedPositionTime!).inSeconds
              : null,
    };
  }

  /// 디버그 정보 출력
  static void printDebugInfo() {
    final status = getStatus();
    print('📊 SmartLocationMonitor 상태:');
    print('   - 실행 중: ${status['isRunning']}');
    print('   - 이동 중: ${status['isMoving']}');
    print('   - 정밀 모드: ${status['precisionModeActive']}');
    print('   - 일반 모드: ${status['normalModeActive']}');
    print('   - 위치 캐시 나이: ${status['cachedPositionAge']}초');
  }

  /// 장소별 상태 초기화
  static Future<void> resetPlaceState(String placeName) async {
    try {
      if (_locationService != null) {
        await _locationService!.resetPlaceState(placeName);
        print('✅ 장소 상태 초기화 완료: $placeName');
      }
    } catch (e) {
      print('❌ 장소 상태 초기화 실패: $e');
    }
  }
}

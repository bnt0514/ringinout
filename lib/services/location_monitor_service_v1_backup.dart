// location_monitor_service.dart
//
// ✅ 지오펜스 + 모션 감지 하이브리드 아키텍처
//
// 설계 원칙:
// 1. ENTER 감지:
//    - Outer 지오펜스 ENTER → 준비 상태만 (배터리 0%)
//    - Inner 지오펜스 (R+100m) ENTER → 모션 감시 시작 → 움직이면 GPS → R 이내 확정
// 2. EXIT 감지: 내부 + EXIT 알람 → 모션 감시 → 움직이면 GPS → R+15m 벗어나면 확정
// 3. 공통 Hot Mode: 가속도계 모션 감지 → 5초 GPS 폴링 → 10초 정지 시 GPS 해제
// 4. 배터리 최적화: 움직이지 않으면 GPS 0%, 이동 시에만 GPS 가동

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/system_ringtone.dart';
import 'package:ringinout/services/motion_detector.dart';

import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/hive_helper.dart';

@pragma('vm:entry-point')
class LocationMonitorService {
  // ========== Singleton ==========
  static final LocationMonitorService instance =
      LocationMonitorService._internal();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  factory LocationMonitorService() => instance;
  LocationMonitorService._internal();

  // ========== 상태 ==========
  bool _isRunning = false;
  Timer? _watchdogTimer;
  Timer? _snoozeTimer;
  Timer? _gpsVerifyTimer; // GPS 확인 모드 타이머
  Position? _currentPosition;

  // inside/outside 상태
  final Map<String, bool> _lastInside = {};
  final Map<String, bool> _alreadyInside = {}; // 초기 ENTER 억제용

  // ========== GPS 확인 모드 상태 ==========
  bool _isVerifying = false; // GPS 확인 중 여부
  String? _verifyPlaceId; // 확인 중인 장소 ID
  bool _verifyIsEnter = true; // 진입/진출 확인 중
  int _verifyCount = 0; // 현재 확인 횟수
  int _verifyConfirmCount = 0; // 연속 성공 횟수
  static const int _maxVerifyAttempts = 5; // 최대 GPS 확인 횟수
  static const int _requiredConfirms = 1; // 확정에 필요한 확인 수
  static const int _verifyIntervalMs = 5000; // GPS 확인 간격 (5초)

  // ========== 모션 기반 Hot Mode (EXIT + ENTER 감지) ==========
  // EXIT: 내부 + EXIT 알람 → 모션 감시 → 움직이면 GPS → R+15m 벗어나면 확정
  // ENTER: Inner 지오펜스(R+100m) ENTER → 모션 감시 → 움직이면 GPS → R 이내 확정
  // 공통: 10초 정지 → GPS 해제, 가속도계만 유지
  bool _isMotionMonitoring = false; // 모션 감시 중 여부
  bool _isHotMode = false; // Hot Mode (GPS 폴링 중)
  Timer? _hotModeGpsTimer; // Hot Mode GPS 폴링 타이머
  static const int _hotModeIntervalSec = 5; // Hot Mode: 5초 GPS 간격
  final Map<String, int> _hotModeConfirmCount = {}; // 장소별 연속 확인 횟수
  static const int _hotModeRequiredConfirms = 1; // 1회 확인 시 확정
  final Set<String> _approachingPlaces = {}; // Outer ENTER 접근 감지 (준비 상태)
  final Set<String> _innerEnteredPlaces = {}; // Inner ENTER 감지 → 모션 감시 트리거

  // ========== 콜백 ==========
  void Function(String type, Map<String, dynamic> alarm)? _onTriggerCallback;

  // 현재 추적 중인 장소 이름 집합
  Set<String> _trackedPlaceNames = {};

  // ========== Getters ==========
  bool get isRunning => _isRunning;
  Set<String> get trackedPlaceNames => Set.unmodifiable(_trackedPlaceNames);
  Map<String, bool> get lastInsideStatus => Map.unmodifiable(_lastInside);
  Map<String, bool> get alreadyInsideStatus => Map.unmodifiable(_alreadyInside);
  Position? get currentPosition => _currentPosition;
  int get currentIntervalMs => _isVerifying ? _verifyIntervalMs : 0;

  // ========== 모션+지오펜스 상태 Getters (GPS 페이지 개발자 도구용) ==========
  bool get isMotionMonitoring => _isMotionMonitoring;
  bool get isHotMode => _isHotMode;
  bool get isVerifying => _isVerifying;
  Set<String> get approachingPlaces => Set.unmodifiable(_approachingPlaces);
  Set<String> get innerEnteredPlaces => Set.unmodifiable(_innerEnteredPlaces);
  Map<String, int> get hotModeConfirmCount =>
      Map.unmodifiable(_hotModeConfirmCount);

  Map<String, dynamic> get currentMonitoringProfile {
    return <String, dynamic>{
      'intervalMs': _isVerifying ? _verifyIntervalMs : 0,
      'tier': _isVerifying ? 0 : -1,
      'isRunning': _isRunning,
    };
  }

  // ========== 테스트 GPS 좌표 오버라이드 ==========
  Position? _testPosition; // null이면 실제 GPS 사용
  bool get isTestMode => _testPosition != null;

  /// 테스트 좌표 설정 (GPS 시뮬레이션용)
  void setTestPosition(double lat, double lng, {double speed = 0.0}) {
    _testPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );
  }

  /// 테스트 모드 해제
  void clearTestPosition() {
    _testPosition = null;
    print('[LMS] 🧪 테스트 모드 해제 → 실제 GPS로 복귀');
  }

  /// 테스트용: 특정 장소에 대해 내/외부 상태를 강제 설정
  /// 진출 시뮬레이션 전에 호출해서 wasInside=true 세팅
  void setInsideStateForTest(String placeName, {required bool inside}) {
    _lastInside[placeName] = inside;
    _alreadyInside[placeName] = false; // 초기진입 억제 해제
    print('[LMS] 🧪 [$placeName] inside 강제 설정: $inside');
  }

  /// GPS 위치 가져오기 (테스트 오버라이드 지원)
  /// 테스트 모드일 때는 _testPosition 반환, 아니면 실제 GPS
  Future<Position> _getPositionForCheck({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_testPosition != null) {
      print(
        '[LMS] 🧪 테스트 좌표 사용: '
        '${_testPosition!.latitude.toStringAsFixed(5)}, '
        '${_testPosition!.longitude.toStringAsFixed(5)}',
      );
      return _testPosition!;
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).timeout(timeout);
  }

  // ========== 위치 스트림 (GPS 페이지용) ==========
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  // ========== 초기화 & 시작 ==========

  @pragma('vm:entry-point')
  Future<void> startBackgroundMonitoring(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    if (_isRunning) {
      print('[LMS] ℹ️ 이미 실행 중');
      return;
    }

    _onTriggerCallback = onTrigger;

    final hasPermission = await _checkPermissionsSafely();
    if (!hasPermission) {
      print('[LMS] ⚠️ 위치 권한 없음 - 모니터링 시작 불가');
      return;
    }

    final activeAlarms = await _getActiveAlarms();
    if (activeAlarms.isEmpty) {
      print('[LMS] 📭 활성화된 알람이 없음');
      return;
    }

    _trackedPlaceNames =
        activeAlarms
            .map((a) => (a['place'] ?? a['locationName'] ?? '') as String)
            .where((n) => n.isNotEmpty)
            .toSet();

    print(
      '[LMS] 🚀 시작 (${activeAlarms.length}개 알람, 추적 장소: $_trackedPlaceNames)',
    );

    await _loadLastInsideState();
    await _initializeInsideStatus(activeAlarms);

    _startSnoozeChecker(onTrigger);
    _startWatchdogHeartbeat();

    _isRunning = true;
    await _saveServiceState(true);

    // 모션 기반 EXIT 감시 시작 (내부 + EXIT 알람이 있으면)
    await _evaluateAndStartMotionMonitoring(activeAlarms);

    print('[LMS] ✅ 시작 완료 — 지오펜스 + 모션 감지 하이브리드');
  }

  Future<void> stopMonitoring() async {
    _gpsVerifyTimer?.cancel();
    _gpsVerifyTimer = null;
    _stopHotMode();
    _stopMotionMonitoring();
    _approachingPlaces.clear();
    _innerEnteredPlaces.clear();
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    _isRunning = false;
    _isVerifying = false;
    _onTriggerCallback = null;
    _trackedPlaceNames = {};
    await _saveServiceState(false);
    print('[LMS] 🛑 중지');
  }

  // ========== 지오펜스 이벤트 수신 (핵심 진입점) ==========

  /// 네이티브 지오펜스 이벤트 수신
  /// isOuter=true: Outer 지오펜스 (접근 준비 상태만 등록)
  /// isOuter=false: Inner 지오펜스 (ENTER → 모션 감시 시작, EXIT → GPS 확인 보조)
  void onGeofenceEvent(String placeId, bool isEnter, bool isOuter) {
    if (!_isRunning) return;

    final fenceType = isOuter ? 'Outer' : 'Inner';
    print('[LMS] 📡 $fenceType 지오펜스: $placeId ${isEnter ? "ENTER" : "EXIT"}');

    if (isOuter) {
      if (isEnter) {
        // Outer ENTER: 준비 상태만 등록 (모션 감시 X, GPS X)
        _approachingPlaces.add(placeId);
        print('[LMS] 🔵 Outer 접근 준비: $placeId (Inner 이벤트 대기)');
      } else {
        // Outer EXIT: 완전 이탈 → 준비 & Inner 플래그 모두 해제
        _approachingPlaces.remove(placeId);
        _innerEnteredPlaces.remove(placeId);
        print('[LMS] 🔵 Outer 이탈: $placeId → 모션 감시 재평가');
        _evaluateAndStartMotionMonitoringAsync();
      }
      return;
    }

    // Inner 이벤트
    if (isEnter) {
      // Inner ENTER (R+100m 진입):
      // - ENTER 알람: 바로 Hot Mode 진입 (5초 GPS 폴링 → 실제 반경 내 확인)
      // - EXIT 알람: 모션 감시 시작 (내부에서 나가는 것 감지)
      _innerEnteredPlaces.add(placeId);
      print('[LMS] 🟢 Inner 진입: $placeId → Hot Mode 진입');
      _evaluateAndStartMotionMonitoringAsync();
      // ENTER 알람이면 모션 감시와 무관하게 Hot Mode 즉시 시작
      _enterHotMode();
    } else {
      // Inner EXIT: 이탈 → Inner 플래그 해제 + GPS 확인 보조
      _innerEnteredPlaces.remove(placeId);
      print('[LMS] 🔴 Inner 이탈: $placeId → 모션 감시 재평가');
      _evaluateAndStartMotionMonitoringAsync();
      // 보조: GPS 확인 모드도 시작 (EXIT 확인용)
      _startGpsVerification(placeId, isEnter);
    }
  }

  /// 비동기 모션 감시 재평가 (onGeofenceEvent에서 호출)
  void _evaluateAndStartMotionMonitoringAsync() {
    _getActiveAlarms()
        .then((alarms) {
          _evaluateAndStartMotionMonitoring(alarms);
        })
        .catchError((e) {
          print('[LMS] ⚠️ 모션 감시 재평가 실패: $e');
        });
  }

  // ========== GPS 확인 모드 ==========

  /// Inner 지오펜스 이벤트 수신 시 GPS 확인 모드 시작
  /// 5초 간격으로 최대 5회 GPS 측정, 2회 연속 확인 시 확정
  void _startGpsVerification(String placeId, bool isEnter) {
    // 이미 같은 장소에 대해 확인 중이면 무시
    if (_isVerifying &&
        _verifyPlaceId == placeId &&
        _verifyIsEnter == isEnter) {
      print('[LMS] ⏭️ 이미 $placeId 확인 중 — 스킵');
      return;
    }

    // 기존 확인 중단
    _gpsVerifyTimer?.cancel();

    _isVerifying = true;
    _verifyPlaceId = placeId;
    _verifyIsEnter = isEnter;
    _verifyCount = 0;
    _verifyConfirmCount = 0;

    final label = isEnter ? 'ENTER' : 'EXIT';
    print('[LMS] 🔍 GPS 확인 모드 시작: $placeId $label (5회×5초)');

    // 즉시 첫 확인 + 후속 타이머
    _doGpsVerify();
  }

  /// GPS 1회 확인
  Future<void> _doGpsVerify() async {
    if (!_isRunning || !_isVerifying) return;

    _verifyCount++;
    final label = _verifyIsEnter ? 'ENTER' : 'EXIT';

    try {
      final position = await _getPositionForCheck();

      _currentPosition = position;
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }

      // 정확도 체크: > 200m → 무시 (테스트 모드에서는 항상 통과)
      if (!isTestMode && position.accuracy > 200.0) {
        print('[LMS] 🚫 GPS 정확도 낮음 (${position.accuracy.toInt()}m) → 스킵');
        _scheduleNextVerify();
        return;
      }

      // 해당 장소 정보 조회
      final placeInfo = await _getPlaceInfo(_verifyPlaceId!);
      if (placeInfo == null) {
        print('[LMS] ❌ 장소 정보 없음 → 확인 중단');
        _stopGpsVerification();
        return;
      }

      final placeLat = _toDouble(placeInfo['latitude'] ?? placeInfo['lat']);
      final placeLng = _toDouble(placeInfo['longitude'] ?? placeInfo['lng']);
      final baseRadius = _toDouble(
        placeInfo['radius'] ?? placeInfo['geofenceRadius'] ?? 100,
      );
      final placeName = (placeInfo['name'] ?? 'Unknown') as String;

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        placeLat,
        placeLng,
      );

      // 히스테리시스: 진입=R, 이탈=R+15m
      final enterThreshold = baseRadius;
      final exitThreshold = baseRadius + 15.0;

      bool confirmed = false;
      if (_verifyIsEnter) {
        confirmed = distance <= enterThreshold;
      } else {
        confirmed = distance > exitThreshold;
      }

      if (confirmed) {
        _verifyConfirmCount++;
        print(
          '[LMS] ✅ [$placeName] $label 확인 '
          '($_verifyConfirmCount/$_requiredConfirms) '
          'dist=${distance.toInt()}m R=${baseRadius.toInt()}m',
        );

        if (_verifyConfirmCount >= _requiredConfirms) {
          // 확정!
          print('[LMS] 🎯 [$placeName] $label 확정!');
          _stopGpsVerification();

          final activeAlarms = await _getActiveAlarms();
          await _onStateConfirmed(
            placeName,
            _verifyIsEnter,
            activeAlarms,
            position,
            DateTime.now(),
          );
          return;
        }
      } else {
        // 불일치 → 연속 카운트 리셋
        _verifyConfirmCount = 0;
        print(
          '[LMS] ❌ [$placeName] $label 불일치 '
          '(dist=${distance.toInt()}m R=${baseRadius.toInt()}m) '
          '($_verifyCount/$_maxVerifyAttempts)',
        );
      }

      // 최대 횟수 도달 시 중단
      if (_verifyCount >= _maxVerifyAttempts) {
        print(
          '[LMS] ⏹️ [$placeName] GPS 확인 실패 (${_maxVerifyAttempts}회 소진) → 대기',
        );
        _stopGpsVerification();
        return;
      }

      // 다음 확인 예약
      _scheduleNextVerify();
    } on TimeoutException {
      print('[LMS] ⚠️ GPS 타임아웃 ($_verifyCount/$_maxVerifyAttempts)');
      if (_verifyCount >= _maxVerifyAttempts) {
        _stopGpsVerification();
      } else {
        _scheduleNextVerify();
      }
    } catch (e) {
      print('[LMS] ❌ GPS 획득 실패: $e');
      if (_verifyCount >= _maxVerifyAttempts) {
        _stopGpsVerification();
      } else {
        _scheduleNextVerify();
      }
    }
  }

  void _scheduleNextVerify() {
    _gpsVerifyTimer?.cancel();
    _gpsVerifyTimer = Timer(
      const Duration(milliseconds: _verifyIntervalMs),
      _doGpsVerify,
    );
  }

  void _stopGpsVerification() {
    _gpsVerifyTimer?.cancel();
    _gpsVerifyTimer = null;
    _isVerifying = false;
    _verifyPlaceId = null;
    _verifyCount = 0;
    _verifyConfirmCount = 0;
  }

  /// 장소 ID로 장소 정보 조회
  Future<Map<String, dynamic>?> _getPlaceInfo(String placeId) async {
    try {
      final places = HiveHelper.getSavedLocations();
      final activeAlarms = await _getActiveAlarms();

      // 1순위: placeId 형식이 "{alarmId}_{placeName}_{trigger}" 인 경우 파싱
      //   예) "60a38bff-da4d-486f-9c56-bb1ba231cdb5_회사_exit"
      //   알람 ID는 UUID 형식 (8-4-4-4-12), 이후 첫 번째 '_' 뒤가 장소명+트리거
      final uuidPattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_(.+)_(entry|exit)$',
        caseSensitive: false,
      );
      final uuidMatch = uuidPattern.firstMatch(placeId);
      if (uuidMatch != null) {
        final extractedName = uuidMatch.group(1)!;
        for (final place in places) {
          if (place['name'] == extractedName) return place;
        }
        print('[LMS] ⚠️ placeId에서 추출한 장소명 "$extractedName" 찾지 못함');
      }

      // 2순위: placeId가 알람 id와 정확히 일치하는 경우
      for (final alarm in activeAlarms) {
        if (alarm['id'] == placeId) {
          final placeName =
              (alarm['place'] ?? alarm['locationName']) as String?;
          if (placeName != null) {
            for (final place in places) {
              if (place['name'] == placeName) return place;
            }
          }
          break;
        }
      }

      // 3순위: placeId 자체가 장소 이름인 경우 (네이티브 지오펜스 등)
      for (final place in places) {
        if (place['name'] == placeId) return place;
      }

      print('[LMS] ❌ placeId "$placeId" 에 해당하는 장소 정보 없음');
      return null;
    } catch (e) {
      print('[LMS] ❌ 장소 정보 조회 실패: $e');
      return null;
    }
  }

  /// inside/outside 상태 확정 후 알람 트리거
  Future<void> _onStateConfirmed(
    String placeName,
    bool isNowInside,
    List<Map<String, dynamic>> activeAlarms,
    Position position,
    DateTime now,
  ) async {
    // 초기 ENTER 무시 (앱 시작 시 이미 내부에 있는 경우)
    if (isNowInside && (_alreadyInside[placeName] ?? false)) {
      print('[LMS] ⏭️ [$placeName] 초기 ENTER 무시 (이미 내부)');
      _alreadyInside[placeName] = false;
      _lastInside[placeName] = true;
      await _saveLastInsideState(placeName, true);
      return;
    }

    // 해당 장소의 알람들을 찾아서 트리거
    final matchingAlarms =
        activeAlarms.where((alarm) {
          final alarmPlace = alarm['place'] ?? alarm['locationName'];
          return alarmPlace == placeName;
        }).toList();

    for (final alarm in matchingAlarms) {
      final trigger = alarm['trigger'] ?? 'entry';
      final wasInside = _lastInside[placeName] ?? false;

      bool shouldTrigger = false;
      String triggerType = '';

      if (isNowInside && !wasInside && trigger == 'entry') {
        shouldTrigger = true;
        triggerType = 'entry';
      } else if (!isNowInside && wasInside && trigger == 'exit') {
        shouldTrigger = true;
        triggerType = 'exit';
      }

      if (shouldTrigger) {
        // Hive에서 최신 상태 확인
        final alarmId = alarm['id'];
        if (alarmId is String) {
          try {
            final latestAlarm = HiveHelper.alarmBox.get(alarmId);
            if (latestAlarm == null || latestAlarm['enabled'] != true) {
              print('[LMS] ⏭️ [$placeName] 알람 비활성화됨 - 트리거 안함');
              continue;
            }
          } catch (e) {
            print('[LMS] ⚠️ 알람 상태 확인 실패: $e');
          }

          // ✅ 네이티브 "알람 종료" 동기화: SharedPreferences → Hive
          try {
            final prefs = await SharedPreferences.getInstance();
            final isDisabled =
                prefs.getBool('alarm_disabled_$alarmId') ?? false;
            if (isDisabled) {
              print('[LMS] 🔒 [$placeName] 네이티브 종료 감지 → Hive 비활성화');
              final box = HiveHelper.alarmBox;
              final current = box.get(alarmId);
              if (current != null) {
                final updated = Map<String, dynamic>.from(current);
                updated['enabled'] = false;
                await box.put(alarmId, updated);
              }
              await prefs.remove('alarm_disabled_$alarmId');
              continue;
            }
          } catch (e) {
            print('[LMS] ⚠️ alarm_disabled 동기화 실패: $e');
          }

          // ✅ 지나치는 중(passing) 억제 체크
          try {
            final prefs = await SharedPreferences.getInstance();
            final passingUntilMs = prefs.getInt('passing_until_$alarmId') ?? 0;
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            if (passingUntilMs > nowMs) {
              final remaining = (passingUntilMs - nowMs) ~/ 1000;
              print(
                '[LMS] ⏭️ [$placeName] passing 억제 중 (${remaining}초 남음) - 트리거 안함',
              );
              continue;
            }
          } catch (e) {
            print('[LMS] ⚠️ passing_until 체크 실패 (무시): $e');
          }
        }

        // 요일/시간 조건 확인
        if (!_checkDayCondition(alarm) || !_checkTimeCondition(alarm)) {
          print('[LMS] ⏭️ [$placeName] 요일/시간 조건 불만족');
          continue;
        }

        print('[LMS] 🚨 [$placeName] 알람 트리거! (${alarm['name']}, $triggerType)');
        await _triggerAlarm(
          Map<String, dynamic>.from(alarm),
          triggerType,
          _onTriggerCallback ?? (_, __) {},
        );
      }
    }

    // 상태 업데이트
    _lastInside[placeName] = isNowInside;
    await _saveLastInsideState(placeName, isNowInside);
    print('[LMS] 📝 [$placeName] 상태 업데이트: ${isNowInside ? "내부" : "외부"}');

    // 상태 변경 후 모션 감시 재평가
    _hotModeConfirmCount.remove(placeName);
    await _evaluateAndStartMotionMonitoring(activeAlarms);
  }

  // ========== 초기 상태 설정 ==========

  Future<void> _initializeInsideStatus(
    List<Map<String, dynamic>> activeAlarms,
  ) async {
    final places = _extractAlarmedPlaces(activeAlarms);
    bool gpsOk = false;

    try {
      final pos = await _getPositionForCheck();

      if (isTestMode || pos.accuracy <= 100.0) {
        for (final p in places) {
          final name = (p['name'] ?? 'Unknown') as String;
          final lat = _toDouble(p['latitude'] ?? p['lat']);
          final lng = _toDouble(p['longitude'] ?? p['lng']);
          final radius = _toDouble(p['radius'] ?? p['geofenceRadius'] ?? 100);

          final distance = Geolocator.distanceBetween(
            pos.latitude,
            pos.longitude,
            lat,
            lng,
          );
          final insideNow = distance <= radius;

          _lastInside[name] = insideNow;
          _alreadyInside[name] = insideNow;
          await _saveLastInsideState(name, insideNow);

          print(
            '[LMS] 📍 초기: "$name" ${insideNow ? "내부" : "외부"} '
            '(${distance.toInt()}m, R=${radius.toInt()}m)',
          );
        }
        _currentPosition = pos;
        gpsOk = true;
      }
    } catch (e) {
      print('[LMS] ⚠️ 초기 GPS 실패: $e');
    }

    if (!gpsOk) {
      await _loadLastInsideState();
      for (final p in places) {
        final name = (p['name'] ?? 'Unknown') as String;
        _alreadyInside[name] = true;
        print(
          '[LMS] 📦 "$name" SharedPrefs 복원: ${_lastInside[name]} (ENTER 차단)',
        );
      }
    }

    // 초기 상태 기반으로 폴링 필요 여부 평가는 startBackgroundMonitoring에서 수행
  }

  // ========== 강제 알람 트리거 (개발자 도구용) ==========

  /// GPS 페이지 개발자 도구에서 직접 알람을 트리거 (전체 흐름 E2E 테스트)
  /// 실제 _triggerAlarm과 동일한 경로 사용: Hive 상태 확인 → 비활성화 → 벨소리 → 전체화면 알람
  Future<void> forceTriggerAlarm(Map<String, dynamic> alarmData) async {
    final trigger = (alarmData['trigger'] as String?) ?? 'entry';
    final callback = _onTriggerCallback ?? (_, __) {};
    print('[LMS] 🧪 강제 알람 트리거: ${alarmData['name']} ($trigger)');
    await _triggerAlarm(alarmData, trigger, callback);
  }

  // ========== 알람 트리거 ==========

  @pragma('vm:entry-point')
  Future<void> _triggerAlarm(
    Map<String, dynamic> alarmData,
    String trigger,
    void Function(String, Map<String, dynamic>) onTrigger, {
    bool isSnoozeAlarm = false,
  }) async {
    final alarmId = alarmData['id'];

    // Hive에서 최신 상태 확인
    if (alarmId is String) {
      try {
        final box = HiveHelper.alarmBox;
        final latestAlarm = box.get(alarmId);
        if (latestAlarm == null) {
          print('[LMS] ⛔ 알람 삭제됨 - 트리거 중단: ${alarmData['name']}');
          return;
        }

        if (isSnoozeAlarm) {
          final updated = Map<String, dynamic>.from(latestAlarm);
          updated['snoozePending'] = false;
          await box.put(alarmId, updated);
          alarmData = updated;
        } else {
          if (latestAlarm['enabled'] != true) {
            print('[LMS] ⛔ 알람 비활성화됨 - 트리거 중단: ${alarmData['name']}');
            return;
          }
          alarmData = Map<String, dynamic>.from(latestAlarm);
        }
      } catch (e) {
        print('[LMS] ⚠️ 최신 알람 상태 확인 실패: $e');
      }
    }

    // SharedPreferences 비활성화 체크 (네이티브 "알람 종료" 동기화 백업)
    if (alarmId != null) {
      final prefs = await SharedPreferences.getInstance();
      final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
      if (isDisabled) {
        print('[LMS] ⏭️ 알람 비활성화됨 (SharedPrefs): ${alarmData['name']}');
        if (alarmId is String) {
          try {
            final box = HiveHelper.alarmBox;
            final current = box.get(alarmId);
            if (current != null) {
              final updated = Map<String, dynamic>.from(current);
              updated['enabled'] = false;
              await box.put(alarmId, updated);
            }
            await prefs.remove('alarm_disabled_$alarmId');
          } catch (_) {}
        }
        return;
      }
    }

    print('[LMS] ✅ 알람 트리거: ${alarmData['name']}');

    // 0. 즉시 쿨다운 설정: 동일 알람 재트리거 방지 (60초)
    if (alarmId is String) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cooldownUntil = DateTime.now().millisecondsSinceEpoch + 60000;
        await prefs.setInt('passing_until_$alarmId', cooldownUntil);
        print('[LMS] ⏸️ 쿨다운 설정 (60초): ${alarmData['name']}');
      } catch (e) {
        print('[LMS] ⚠️ 쿨다운 설정 실패: $e');
      }
    }

    // 1. 트리거 카운트 업데이트
    try {
      dynamic currentCount = alarmData['triggerCount'];
      int triggerCount = 0;
      if (currentCount is int) {
        triggerCount = currentCount;
      } else if (currentCount is double) {
        triggerCount = currentCount.toInt();
      } else if (currentCount is String) {
        triggerCount = int.tryParse(currentCount) ?? 0;
      }

      final updated = Map<String, dynamic>.from(alarmData);
      updated['triggerCount'] = triggerCount + 1;

      if (alarmId is String) {
        await HiveHelper.updateLocationAlarmById(alarmId, updated);
      }
      alarmData['triggerCount'] = triggerCount + 1;
    } catch (e) {
      print('[LMS] ❌ 트리거 카운트 실패: $e');
    }

    // 1.5. 알람 즉시 비활성화 (Hive → UI 자동 반영)
    if (alarmId is String) {
      try {
        final box = HiveHelper.alarmBox;
        final current = box.get(alarmId);
        if (current != null) {
          final updated = Map<String, dynamic>.from(current);
          updated['enabled'] = false;
          await box.put(alarmId, updated);
          print('[LMS] 🔒 알람 비활성화 완료: ${alarmData['name']}');
        }
      } catch (e) {
        print('[LMS] ⚠️ 알람 비활성화 실패: $e');
      }
    }

    // 2. 시스템 벨소리
    try {
      await SystemRingtone.play();
    } catch (e) {
      print('[LMS] ❌ 벨소리 재생 실패: $e');
    }

    // 3. 진동
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('[LMS] ❌ 진동 실패: $e');
    }

    // 4. Native 전체화면 알람
    try {
      await AlarmNotificationHelper.showNativeAlarm(
        title: alarmData['name'] ?? 'Ringinout',
        message: trigger == 'exit' ? '지정 장소에서 벗어났습니다' : '지정 장소에 도착했습니다',
        sound: alarmData['sound'] ?? 'assets/sounds/thoughtfulringtone.mp3',
        vibrate: (alarmData['vibrate'] ?? true) == true,
        alarmData: alarmData,
      );
      await SystemRingtone.play();
    } catch (e) {
      print('[LMS] ❌ Native 전체화면 실패: $e');
      try {
        final isEntry = trigger == 'entry';
        final placeName = alarmData['place'] ?? '지정 장소';
        await AlarmNotificationHelper.showPersistentAlarmNotification(
          title: '🚨 ${alarmData['name']}',
          body: isEntry ? '$placeName에 도착했습니다!' : '$placeName에서 벗어났습니다!',
          alarmData: alarmData,
        );
      } catch (e2) {
        print('[LMS] ❌ 푸시 알림도 실패: $e2');
      }
    }

    // 5. 콜백
    try {
      onTrigger(trigger, alarmData);
    } catch (e) {
      print('[LMS] ❌ onTrigger 콜백 실패: $e');
    }
  }

  // ========== 조건 체크 ==========

  @pragma('vm:entry-point')
  bool _checkDayCondition(Map<String, dynamic> alarm) {
    final repeat = alarm['repeat'];
    if (repeat == null) return true;

    final now = DateTime.now();

    if (repeat is String) {
      final targetDate = DateTime.tryParse(repeat);
      if (targetDate != null) {
        final todayOnly = DateTime(now.year, now.month, now.day);
        final targetOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        return todayOnly.isAtSameMomentAs(targetOnly);
      }
      return false;
    }

    if (repeat is List && repeat.isNotEmpty) {
      final weekdayStr = ['일', '월', '화', '수', '목', '금', '토'][now.weekday % 7];
      final days = repeat.map((e) => e.toString()).toList();
      return days.contains(weekdayStr);
    }

    return true;
  }

  @pragma('vm:entry-point')
  bool _checkTimeCondition(Map<String, dynamic> alarm) {
    final now = DateTime.now();

    final startTimeMs = alarm['startTimeMs'] ?? 0;
    if (startTimeMs is int && startTimeMs > 0) {
      return now.millisecondsSinceEpoch >= startTimeMs;
    }

    final targetHour = alarm['hour'];
    final targetMinute = alarm['minute'];
    if (targetHour != null) {
      final h = targetHour as int;
      final m = (targetMinute ?? 0) as int;
      return now.hour > h || (now.hour == h && now.minute >= m);
    }

    return true;
  }

  // ========== 활성 알람 조회 ==========

  @pragma('vm:entry-point')
  Future<List<Map<String, dynamic>>> _getActiveAlarms() async {
    try {
      if (!HiveHelper.isInitialized) {
        await HiveHelper.init();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (HiveHelper.isInitialized) {
        return HiveHelper.getActiveAlarmsForMonitoring();
      }

      // Hive 직접 접근 폴백
      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        final directory = await getApplicationDocumentsDirectory();
        final uniquePath = '${directory.path}/ringinout_unique_v3';
        final hiveDir = Directory(uniquePath);
        if (!await hiveDir.exists()) {
          await hiveDir.create(recursive: true);
        }
        try {
          Hive.init(uniquePath);
        } catch (_) {}
        await Hive.openBox('locationAlarms_v2');
      }

      if (Hive.isBoxOpen('locationAlarms_v2')) {
        final box = Hive.box('locationAlarms_v2');
        return box.values
            .whereType<Map>()
            .map((a) => Map<String, dynamic>.from(a))
            .where(
              (a) => HiveHelper.isAlarmActiveForMonitoring(a, DateTime.now()),
            )
            .toList();
      }

      return [];
    } catch (e) {
      print('[LMS] ❌ 활성 알람 조회 실패: $e');
      return [];
    }
  }

  // ========== 모션 기반 Hot Mode (EXIT 감지) ==========
  //
  // 흐름:
  // 1. 내부 + EXIT 알람 → _startMotionMonitoring() → MotionDetector 가속도계 감시
  // 2. 움직임 감지 → _enterHotMode() → 5초 GPS 폴링 시작
  // 3. 10초 정지 → _exitHotMode() → GPS 해제, 가속도계만 유지
  // 4. EXIT 확정 → _stopMotionMonitoring() → 모션+GPS 모두 해제
  //
  // 배터리: 사무실 업무 중 가속도계만 → 배터리 ≈ 0%
  //         이동 시에만 GPS → 최대 30-60초 정도만 사용

  /// 현재 상태를 기반으로 모션 감시가 필요한지 평가 (EXIT + ENTER)
  Future<void> _evaluateAndStartMotionMonitoring(
    List<Map<String, dynamic>> activeAlarms,
  ) async {
    final monitorPlaces = _getMotionMonitoringPlaces(activeAlarms);

    if (monitorPlaces.isEmpty) {
      if (_isMotionMonitoring) {
        print('[LMS] ⏹️ 모션 감시 중단 — 감시 필요 장소 없음');
        _stopMotionMonitoring();
      }
      return;
    }

    if (!_isMotionMonitoring) {
      final exitCount =
          monitorPlaces.where((p) => p['checkType'] == 'exit').length;
      final enterCount =
          monitorPlaces.where((p) => p['checkType'] == 'enter').length;
      print('[LMS] 📱 모션 감시 시작 (EXIT: ${exitCount}개, ENTER: ${enterCount}개)');
      for (final info in monitorPlaces) {
        print(
          '[LMS]    📍 ${info['placeName']}: ${(info['checkType'] as String).toUpperCase()} 감시 (모션 대기)',
        );
      }
      _startMotionMonitoring();
    }
  }

  /// 모션 감시가 필요한 장소 목록 반환 (EXIT + ENTER)
  /// EXIT: 내부 + EXIT 알람
  /// ENTER: Inner 지오펜스(R+100m) 진입 + 외부 + ENTER 알람
  List<Map<String, dynamic>> _getMotionMonitoringPlaces(
    List<Map<String, dynamic>> activeAlarms,
  ) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final alarm in activeAlarms) {
      final placeName = (alarm['place'] ?? alarm['locationName']) as String?;
      if (placeName == null || seen.contains(placeName)) continue;
      seen.add(placeName);

      final trigger = alarm['trigger'] ?? 'entry';
      final isInside = _lastInside[placeName] ?? false;

      String? checkType;

      if (isInside && trigger == 'exit') {
        // EXIT: 내부에 있고 EXIT 알람 활성
        checkType = 'exit';
      } else if (!isInside && trigger == 'entry') {
        // ENTER: 외부 + ENTER 알람 + Inner 지오펜스(R+100m) 진입됨
        if (_isPlaceInnerEntered(placeName, activeAlarms)) {
          checkType = 'enter';
        }
      }

      if (checkType != null) {
        try {
          final places = HiveHelper.getSavedLocations();
          final place = places.firstWhere(
            (p) => p['name'] == placeName,
            orElse: () => <String, dynamic>{},
          );
          if (place.isNotEmpty) {
            result.add({
              'placeName': placeName,
              'lat': _toDouble(place['latitude'] ?? place['lat']),
              'lng': _toDouble(place['longitude'] ?? place['lng']),
              'radius': _toDouble(
                place['radius'] ?? place['geofenceRadius'] ?? 100,
              ),
              'checkType': checkType,
            });
          }
        } catch (e) {
          print('[LMS] ❌ 장소 조회 실패: $e');
        }
      }
    }
    return result;
  }

  /// 해당 장소가 Inner 지오펜스(R+100m) 안에 진입한 상태인지 확인
  bool _isPlaceInnerEntered(
    String placeName,
    List<Map<String, dynamic>> activeAlarms,
  ) {
    // 1) _innerEnteredPlaces에 직접 장소명이 있으면
    if (_innerEnteredPlaces.contains(placeName)) return true;

    // 2) 알람 ID로 매핑 (정확한 ID 일치)
    for (final alarm in activeAlarms) {
      final alarmPlace = (alarm['place'] ?? alarm['locationName']) as String?;
      final alarmId = alarm['id'] as String?;
      if (alarmPlace == placeName) {
        if (alarmId != null && _innerEnteredPlaces.contains(alarmId)) {
          return true;
        }
      }
    }

    // 3) 시뮬레이션에서 주입되는 'UUID_placeName_trigger' 형태 매칭
    //    _innerEnteredPlaces에 저장된 값이 이 형태일 수 있음
    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}_(.+)_(entry|exit)$',
      caseSensitive: false,
    );
    for (final id in _innerEnteredPlaces) {
      final m = uuidPattern.firstMatch(id);
      if (m != null && m.group(1) == placeName) return true;
    }

    return false;
  }

  /// MotionDetector 가속도계 감시 시작 (배터리 ≈ 0%)
  void _startMotionMonitoring() {
    if (_isMotionMonitoring) return;
    _isMotionMonitoring = true;

    final detector = MotionDetector.instance;
    detector.setInsideIdleMode(true); // idle 모드: 1.8m/s², 10초 윈도우
    detector.onMovementStateChanged = _onMotionStateChanged;
    detector.startMonitoring();

    print('[LMS] 📱 MotionDetector 시작 (idle 모드 — 가속도계만)');
  }

  /// MotionDetector 감시 중지
  void _stopMotionMonitoring() {
    if (!_isMotionMonitoring) return;
    _isMotionMonitoring = false;
    _stopHotMode();

    final detector = MotionDetector.instance;
    detector.onMovementStateChanged = null;
    detector.stopMonitoring();

    print('[LMS] 📱 MotionDetector 중지');
  }

  /// MotionDetector 콜백: 움직임 상태 변경
  void _onMotionStateChanged(bool isMoving) {
    if (!_isRunning || !_isMotionMonitoring) return;

    if (isMoving) {
      print('[LMS] 🚶 움직임 감지! → Hot Mode 진입 (5초 GPS 폴링)');
      _enterHotMode();
    } else {
      print('[LMS] 🛑 정지 감지 (10초) → Hot Mode 해제 (GPS 꺼짐)');
      _exitHotMode();
    }
  }

  /// Hot Mode 진입: 5초 간격 GPS 폴링 시작
  void _enterHotMode() {
    if (_isHotMode) return;
    _isHotMode = true;
    _hotModeConfirmCount.clear();

    print('[LMS] 🔥 Hot Mode ON — 5초 GPS 폴링 시작');

    // 즉시 첫 체크
    _doHotModeGpsCheck();

    // 5초 간격 반복
    _hotModeGpsTimer?.cancel();
    _hotModeGpsTimer = Timer.periodic(
      const Duration(seconds: _hotModeIntervalSec),
      (_) => _doHotModeGpsCheck(),
    );
  }

  /// Hot Mode 해제: GPS 폴링 중지 (모션 감시는 유지)
  void _exitHotMode() {
    if (!_isHotMode) return;
    _stopHotMode();
    print('[LMS] ❄️ Hot Mode OFF — GPS 꺼짐 (모션 감시 유지)');
  }

  /// Hot Mode 타이머/상태 정리
  void _stopHotMode() {
    _hotModeGpsTimer?.cancel();
    _hotModeGpsTimer = null;
    _isHotMode = false;
    _hotModeConfirmCount.clear();
  }

  /// Hot Mode: GPS 1회 체크
  Future<void> _doHotModeGpsCheck() async {
    if (!_isRunning || !_isHotMode) return;

    // GPS 확인 모드(지오펜스)와 충돌 방지
    if (_isVerifying) {
      print('[LMS] ⏭️ GPS 확인 모드 진행 중 — Hot Mode 스킵');
      return;
    }

    try {
      final position = await _getPositionForCheck(
        timeout: const Duration(seconds: 10),
      );

      _currentPosition = position;
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }

      if (!isTestMode && position.accuracy > 200.0) {
        print('[LMS] 🚫 Hot Mode: GPS 정확도 낮음 (${position.accuracy.toInt()}m)');
        return;
      }

      final activeAlarms = await _getActiveAlarms();
      final monitorPlaces = _getMotionMonitoringPlaces(activeAlarms);

      if (monitorPlaces.isEmpty) {
        print('[LMS] ⏹️ Hot Mode: 감시 장소 없음 → 모션 감시 해제');
        _stopMotionMonitoring();
        return;
      }

      for (final info in monitorPlaces) {
        final placeName = info['placeName'] as String;
        final lat = info['lat'] as double;
        final lng = info['lng'] as double;
        final radius = info['radius'] as double;
        final checkType = info['checkType'] as String;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          lat,
          lng,
        );

        bool confirmed = false;
        if (checkType == 'exit') {
          // EXIT 감지: distance > radius + 15m
          confirmed = distance > (radius + 15.0);
        } else {
          // ENTER 감지: distance <= radius
          confirmed = distance <= radius;
        }

        final label = checkType.toUpperCase();

        if (confirmed) {
          final count = (_hotModeConfirmCount[placeName] ?? 0) + 1;
          _hotModeConfirmCount[placeName] = count;

          print(
            '[LMS] 🔍 Hot Mode [$placeName] $label 감지 '
            '($count/$_hotModeRequiredConfirms) '
            'dist=${distance.toInt()}m R=${radius.toInt()}m',
          );

          if (count >= _hotModeRequiredConfirms) {
            // 확정!
            final isNowInside = checkType == 'enter';
            print('[LMS] 🎯 Hot Mode [$placeName] $label 확정!');
            _hotModeConfirmCount.remove(placeName);

            // ENTER 확정 시 Inner/Outer 플래그 해제
            if (isNowInside) {
              _innerEnteredPlaces.remove(placeName);
              _approachingPlaces.remove(placeName);
              for (final alarm in activeAlarms) {
                final ap = alarm['place'] ?? alarm['locationName'];
                if (ap == placeName) {
                  final aid = alarm['id'] as String?;
                  if (aid != null) {
                    _innerEnteredPlaces.remove(aid);
                    _approachingPlaces.remove(aid);
                  }
                }
              }
            }

            // Hot Mode 해제 (확정 후 재평가됨)
            _stopHotMode();

            await _onStateConfirmed(
              placeName,
              isNowInside,
              activeAlarms,
              position,
              DateTime.now(),
            );
            return; // 한 번에 하나만 처리
          }
        } else {
          // 아직 미확정 → 연속 카운트 리셋
          if (_hotModeConfirmCount.containsKey(placeName)) {
            _hotModeConfirmCount[placeName] = 0;
          }
          final status = checkType == 'exit' ? '아직 내부' : '아직 외부';
          print(
            '[LMS] 📍 Hot Mode [$placeName] $status '
            '(dist=${distance.toInt()}m R=${radius.toInt()}m)',
          );
        }
      }
    } on TimeoutException {
      print('[LMS] ⚠️ Hot Mode: GPS 타임아웃');
    } catch (e) {
      print('[LMS] ❌ Hot Mode: GPS 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  List<Map<String, dynamic>> _extractAlarmedPlaces(
    List<Map<String, dynamic>> alarms,
  ) {
    final Set<String> alarmPlaceNames =
        alarms
            .where(
              (a) =>
                  a['enabled'] == true &&
                  (a['place'] ?? a['locationName']) != null,
            )
            .map((a) => (a['place'] ?? a['locationName']) as String)
            .toSet();

    try {
      final allPlaces = HiveHelper.getSavedLocations();
      return allPlaces
          .where((p) => alarmPlaceNames.contains(p['name']))
          .toList();
    } catch (e) {
      print('[LMS] ❌ _extractAlarmedPlaces 실패: $e');
      return [];
    }
  }

  // ========== SharedPreferences 영속성 ==========

  Future<void> _loadLastInsideState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (key.startsWith('last_inside_')) {
          final placeName = key.substring('last_inside_'.length);
          _lastInside[placeName] = prefs.getBool(key) ?? false;
        }
      }
      print('[LMS] ✅ _lastInside 복원: $_lastInside');
    } catch (e) {
      print('[LMS] ❌ _lastInside 복원 실패: $e');
    }
  }

  Future<void> _saveLastInsideState(String placeName, bool isInside) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('last_inside_$placeName', isInside);
    } catch (e) {
      print('[LMS] ❌ _lastInside 저장 실패: $e');
    }
  }

  Future<void> _saveServiceState(bool running) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('geofence_running', running);
    } catch (e) {
      print('[LMS] ⚠️ 서비스 상태 저장 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  Future<void> restoreServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasRunning = prefs.getBool('geofence_running') ?? false;
      if (wasRunning && !_isRunning) {
        print('[LMS] 🔄 서비스 상태 복원 → startBackgroundMonitoring 예약');
      }
    } catch (e) {
      print('[LMS] ⚠️ 서비스 상태 복구 실패: $e');
    }
  }

  Future<bool> _checkPermissionsSafely() async {
    try {
      final status = await Permission.locationAlways.status;
      if (status.isGranted) return true;
      final foreground = await Permission.locationWhenInUse.status;
      return foreground.isGranted;
    } catch (e) {
      print('[LMS] ⚠️ 권한 확인 실패: $e');
      return false;
    }
  }

  // ========== 장소 상태 초기화 ==========

  @pragma('vm:entry-point')
  Future<void> resetPlaceState(String placeName) async {
    try {
      final pos = await _getPositionForCheck();

      if (!isTestMode && pos.accuracy > 100.0) {
        print('[LMS] ⚠️ GPS 정확도 낮음 - resetPlaceState 스킵');
        return;
      }

      final places = HiveHelper.getSavedLocations();
      final place = places.firstWhere(
        (p) => p['name'] == placeName,
        orElse: () => <String, dynamic>{},
      );
      if (place.isEmpty) return;

      final lat = _toDouble(place['latitude'] ?? place['lat']);
      final lng = _toDouble(place['longitude'] ?? place['lng']);
      final radius = _toDouble(
        place['radius'] ?? place['geofenceRadius'] ?? 100,
      );

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );
      final isInside = distance <= radius;

      _lastInside[placeName] = isInside;
      _alreadyInside[placeName] = isInside;
      await _saveLastInsideState(placeName, isInside);

      print('[LMS] ✅ resetPlaceState: $placeName → ${isInside ? "내부" : "외부"}');
    } catch (e) {
      print('[LMS] ❌ resetPlaceState 실패: $e');
    }
  }

  // ========== Watchdog Heartbeat ==========

  static const _watchdogChannel = MethodChannel(
    'com.example.ringinout/watchdog',
  );

  void _startWatchdogHeartbeat() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => sendWatchdogHeartbeat(),
    );
    sendWatchdogHeartbeat();
    print('[LMS] ⏰ Watchdog heartbeat 시작 (15분 간격)');
  }

  static Future<void> sendWatchdogHeartbeat() async {
    try {
      final activeCount = await _getActiveAlarmsStatic();
      await _watchdogChannel.invokeMethod('sendHeartbeat', {
        'activeAlarmsCount': activeCount,
      });
      if (activeCount == 0) {
        await _watchdogChannel.invokeMethod('stopWatchdog');
      } else {
        await _watchdogChannel.invokeMethod('startWatchdog');
      }
    } on MissingPluginException {
      // 채널 미등록 - 정상
    } catch (e) {
      print('[LMS] ⚠️ Watchdog heartbeat 실패: $e');
    }
  }

  static Future<int> _getActiveAlarmsStatic() async {
    try {
      final box = HiveHelper.alarmBox;
      int count = 0;
      for (var key in box.keys) {
        final value = box.get(key);
        if (value is Map) {
          final converted = Map<String, dynamic>.from(value);
          if (HiveHelper.isAlarmActiveForMonitoring(
            converted,
            DateTime.now(),
          )) {
            count++;
          }
        }
      }
      return count;
    } catch (e) {
      return 0;
    }
  }

  // ========== 스누즈 체크 ==========

  void _startSnoozeChecker(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) {
    _snoozeTimer?.cancel();
    _snoozeTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      await _checkSnoozeAlarms(onTrigger);
    });
  }

  Future<void> _checkSnoozeAlarms(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    try {
      var box = await Hive.openBox('snoozeSchedules');
      final now = DateTime.now().millisecondsSinceEpoch;

      for (var key in box.keys.toList()) {
        final schedule = box.get(key);
        if (schedule == null) continue;

        final scheduledTime = schedule['scheduledTime'] as int?;
        if (scheduledTime == null) continue;

        if (now >= scheduledTime) {
          await box.delete(key);

          final dynamic alarmDataRaw = schedule['alarmData'];
          Map<String, dynamic>? alarmData;
          if (alarmDataRaw is Map<String, dynamic>) {
            alarmData = alarmDataRaw;
          } else if (alarmDataRaw is Map) {
            alarmData = Map<String, dynamic>.from(alarmDataRaw);
          }

          if (alarmData != null) {
            final alarmId = alarmData['id'];
            final scheduleType = schedule['type'] ?? 'snooze';

            if (scheduleType == 'passing') {
              await _reactivateAlarmById(alarmId);
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('passing_until_$alarmId');
              } catch (_) {}
              print('[LMS] ✅ 패싱 만료 → 알람 재활성화: ${alarmData['name']}');
            } else {
              print('[LMS] ⏰ 스누즈 만료 → 일회성 리마인더 트리거: ${schedule['alarmTitle']}');
              await _triggerAlarm(
                alarmData,
                alarmData['trigger'] ?? 'entry',
                onTrigger,
                isSnoozeAlarm: true,
              );
            }
          }
        }
      }
    } catch (e) {
      print('[LMS] ❌ 스누즈/패싱 체크 실패: $e');
    }
  }

  Future<void> _reactivateAlarmById(dynamic alarmId) async {
    if (alarmId == null) return;
    try {
      final box = HiveHelper.alarmBox;
      for (var key in box.keys) {
        final alarm = box.get(key);
        if (alarm != null && alarm['id'] == alarmId) {
          final updated = Map<String, dynamic>.from(alarm);
          updated['enabled'] = true;
          updated['snoozePending'] = false;
          await box.put(key, updated);
          print('[LMS] ✅ 알람 재활성화 완료: ${updated['name']} (id: $alarmId)');
          break;
        }
      }
    } catch (e) {
      print('[LMS] ❌ 알람 재활성화 실패: $e');
    }
  }

  // ========== 스누즈 스케줄 삭제 ==========

  static Future<void> clearAllSnoozeSchedules() async {
    try {
      final box = await Hive.openBox('snoozeSchedules');
      await box.clear();
      print('[LMS] 🗑️ 모든 스누즈 스케줄 삭제');
    } catch (e) {
      print('[LMS] ❌ 스누즈 스케줄 삭제 실패: $e');
    }
  }

  // ========== 하위 호환 API ==========

  Future<void> startServiceIfSafe() async {
    if (!_isRunning) {
      await startBackgroundMonitoring(_onTriggerCallback ?? (_, __) {});
    }
  }

  /// 알람 목록이 변경된 경우 장소 업데이트 (지오펜스 재등록은 네이티브 SLM에서 처리)
  Future<void> updatePlaces() async {
    if (!_isRunning) return;

    final activeAlarms = await _getActiveAlarms();
    _trackedPlaceNames =
        activeAlarms
            .map((a) => (a['place'] ?? a['locationName'] ?? '') as String)
            .where((n) => n.isNotEmpty)
            .toSet();

    // 알람 변경 시 모션 감시 재평가
    await _evaluateAndStartMotionMonitoring(activeAlarms);

    print('[LMS] ✅ 장소 업데이트 완료 (추적: $_trackedPlaceNames)');
  }

  /// GPS 위치 조회 (외부 호출용)
  Future<Position?> getCurrentPositionSafe() async {
    try {
      final position = await _getPositionForCheck();
      if (!isTestMode && position.accuracy > 50.0) return null;
      return position;
    } catch (e) {
      return null;
    }
  }

  // ========== inside 상태 조회 (외부 호출용) ==========

  bool? getInsideStatus(String placeName) => _lastInside[placeName];

  Map<String, bool> getAllInsideStatus() => Map.unmodifiable(_lastInside);

  // ========== 유틸리티 ==========

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

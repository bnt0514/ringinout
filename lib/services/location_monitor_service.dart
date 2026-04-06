// location_monitor_service.dart
//
// ✅ LMS v3 — 3-State 위치 엔진 (재설계)
//
// 상태머신:
//   OUTSIDE           — 장소 밖. 지오펜스 ENTER 대기. GPS OFF.
//   INSIDE_IDLE       — 장소 안 + 정지. GPS OFF. 모션/지오펜스 EXIT 대기.
//   INSIDE_MOVING     — 장소 안 + 이동 중. GPS ON. 반경 이탈 감시.
//
// 핵심 원칙:
//   1. ENTER 즉시 알람 (검증 없음)
//   2. INSIDE_IDLE → GPS OFF (배터리 절약)
//   3. 모션 감지 → INSIDE_MOVING (GPS ON, 반경 이탈 감시)
//   4. INSIDE_MOVING 종료 조건 = "정지 안정화" (고정 타임아웃 금지)
//   5. 단일 canonical placeId (= 저장된 장소 ID)
//
// 금지 사항:
//   - ENTER 검증 / ENTER_PENDING / ENTER_VERIFY
//   - placeId 변형 (suffix, 장소명 혼합)
//   - 고정 타임아웃 핫모드 (1~2분 자동 종료)
//   - big/small geofence 이중 구조
//   - 내부 정지 상태에서 GPS 상시 갱신

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/app_log_buffer.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/holiday_service.dart';

// ═══════════════════════════════════════════════════════════
//  v3 상태 열거형
// ═══════════════════════════════════════════════════════════

/// 장소별 v3 상태머신
enum PlaceState {
  /// 장소 밖에 있음. 지오펜스 ENTER 대기.
  outside,

  /// 장소 안 + 정지 상태. GPS OFF. 모션 감시만 활성.
  insideIdle,

  /// 장소 안 + 이동 중. GPS ON. 반경 이탈 감시 활성.
  insideMoving,
}

// ═══════════════════════════════════════════════════════════
//  LMS v3 — LocationMonitorService
// ═══════════════════════════════════════════════════════════

@pragma('vm:entry-point')
class LocationMonitorService {
  // ───────── Singleton ─────────
  static final LocationMonitorService instance =
      LocationMonitorService._internal();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  factory LocationMonitorService() => instance;
  LocationMonitorService._internal();

  // ───────── 핵심 상태 ─────────
  bool _isRunning = false;
  Timer? _watchdogTimer;
  Timer? _snoozeTimer;
  Position? _currentPosition;

  /// 알람별 v3 상태 (key = alarmId UUID)
  final Map<String, PlaceState> _placeStates = {};

  /// Init Guard: 앱 시작 후 5초간 ENTER 억제
  DateTime? _initGuardUntil;

  // ───────── INSIDE_MOVING: GPS 감시 ─────────
  /// GPS 폴링 타이머 (전역 1개 — 어떤 장소라도 INSIDE_MOVING이면 활성)
  Timer? _movingGpsTimer;

  /// 정지 안정화 타이머 (모션 STOP 후 N초 뒤 INSIDE_IDLE 복귀)
  Timer? _stillStabilizeTimer;

  /// 마지막 모션 이벤트 시각 (이동/정지)
  DateTime? _lastMotionTime;

  /// 현재 모션 상태 (true=이동중, false=정지)
  bool _isCurrentlyMoving = false;

  /// GPS 폴링 간격 (INSIDE_MOVING 상태에서)
  static const int _movingGpsIntervalMs = 10000; // 10초

  /// 정지 안정화 대기 시간 (모션 STOP 후 이 시간 동안 정지 유지 시 IDLE 복귀)
  static const int _stillStabilizeDurationMs = 120000; // 2분

  /// 반경 이탈 버퍼 (radius + 이 값 초과 시 EXIT 확정)
  static const double _exitBufferMeters = 15.0;

  // ───────── 콜백 ─────────
  void Function(String type, Map<String, dynamic> alarm)? _onTriggerCallback;

  // ───────── 추적 장소 ─────────
  Set<String> _trackedPlaceNames = {};

  // ───────── 위치 스트림 (GPS 페이지용) ─────────
  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  // ───────── 테스트 GPS 오버라이드 ─────────
  Position? _testPosition;
  bool get isTestMode => _testPosition != null;

  // ═══════════════════════════════════════════════════════════
  //  Getters
  // ═══════════════════════════════════════════════════════════

  bool get isRunning => _isRunning;
  Set<String> get trackedPlaceNames => Set.unmodifiable(_trackedPlaceNames);
  Position? get currentPosition => _currentPosition;
  Map<String, PlaceState> get placeStates => Map.unmodifiable(_placeStates);

  /// INSIDE_MOVING 상태인 장소가 있는지
  bool get hasMovingMonitoring =>
      _placeStates.values.any((s) => s == PlaceState.insideMoving);

  /// v2 호환: hasExitVerify → hasMovingMonitoring으로 매핑
  bool get hasExitVerify => hasMovingMonitoring;

  /// 모니터링 프로필 (GPS 페이지 표시용)
  Map<String, dynamic> get currentMonitoringProfile {
    return <String, dynamic>{
      'intervalMs': hasMovingMonitoring ? _movingGpsIntervalMs : 0,
      'isRunning': _isRunning,
      'placeStates': _placeStates.map((k, v) => MapEntry(k, v.name)),
      'isMoving': _isCurrentlyMoving,
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  테스트 GPS 오버라이드
  // ═══════════════════════════════════════════════════════════

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

  void clearTestPosition() {
    _testPosition = null;
    _log('🧪 테스트 모드 해제 → 실제 GPS로 복귀');
  }

  void setPlaceStateForTest(String alarmId, PlaceState state) {
    _placeStates[alarmId] = state;
    _log('🧪 [$alarmId] 상태 강제 설정: ${state.name}');
  }

  Future<Position> _getPosition({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_testPosition != null) return _testPosition!;
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).timeout(timeout);
  }

  // ═══════════════════════════════════════════════════════════
  //  초기화 & 시작
  // ═══════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  Future<void> startBackgroundMonitoring(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    if (_isRunning) {
      _log('ℹ️ 이미 실행 중');
      return;
    }

    _onTriggerCallback = onTrigger;

    final hasPermission = await _checkPermissionsSafely();
    if (!hasPermission) {
      _log('⚠️ 위치 권한 없음 — 시작 불가');
      return;
    }

    final activeAlarms = await _getActiveAlarms();
    if (activeAlarms.isEmpty) {
      _log('📭 활성화된 알람 없음');
      return;
    }

    _trackedPlaceNames =
        activeAlarms
            .map((a) => (a['place'] ?? a['locationName'] ?? '') as String)
            .where((n) => n.isNotEmpty)
            .toSet();

    _log('🚀 v3 시작 (${activeAlarms.length}개 알람, 장소: $_trackedPlaceNames)');

    // 상태 복원 → 초기화 → stale 정리
    await _loadPlaceStates();
    await _initializePlaceStates(activeAlarms);
    await _pruneStaleStates(activeAlarms);

    // Init Guard: 5초간 ENTER 억제
    _initGuardUntil = DateTime.now().add(const Duration(seconds: 5));
    _log('🛡️ Init Guard ON (5초)');

    _startSnoozeChecker(onTrigger);
    _startWatchdogHeartbeat();

    _isRunning = true;
    await _saveServiceState(true);

    _log('✅ v3 시작 완료 — OUTSIDE/INSIDE_IDLE/INSIDE_MOVING 상태머신');
  }

  Future<void> stopMonitoring() async {
    _stopMovingGps();
    _stillStabilizeTimer?.cancel();
    _stillStabilizeTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
    _snoozeTimer?.cancel();
    _snoozeTimer = null;
    _isRunning = false;
    _isCurrentlyMoving = false;
    _onTriggerCallback = null;
    _trackedPlaceNames = {};
    await _saveServiceState(false);
    _log('🛑 v3 중지');
  }

  // ═══════════════════════════════════════════════════════════
  //  핵심: 지오펜스 이벤트 수신
  // ═══════════════════════════════════════════════════════════

  /// 네이티브 지오펜스 이벤트 수신 (유일한 진입점)
  /// ★ placeId = 저장된 장소 ID. 같은 장소의 여러 알람 상태를 함께 동기화한다.
  void onGeofenceEvent(String placeId, bool isEnter) {
    if (!_isRunning) return;

    _log('📡 지오펜스: $placeId ${isEnter ? "ENTER" : "EXIT"}');

    final activeAlarms = HiveHelper.getActiveAlarmsForMonitoring();
    final alarmIds = _getAlarmIdsForPlace(placeId, activeAlarms);

    if (alarmIds.isEmpty) {
      _log('⚠️ placeId "$placeId" 에 연결된 활성 알람 없음');
      return;
    }

    if (isEnter) {
      _handleGeofenceEnter(placeId, alarmIds);
    } else {
      _handleGeofenceExit(placeId, alarmIds);
    }
  }

  List<String> _getAlarmIdsForPlace(
    String placeId,
    List<Map<String, dynamic>> activeAlarms,
  ) {
    return activeAlarms
        .where((alarm) {
          final alarmId = alarm['id'] as String?;
          if (alarmId == null || alarmId.isEmpty) return false;

          final alarmPlaceId = alarm['placeId']?.toString();
          if (alarmPlaceId != null && alarmPlaceId.isNotEmpty) {
            return alarmPlaceId == placeId;
          }

          final alarmPlaceName =
              (alarm['place'] ?? alarm['locationName']) as String?;
          final fallbackPlaceName = _getSavedPlaceName(placeId);
          return fallbackPlaceName != null &&
              alarmPlaceName == fallbackPlaceName;
        })
        .map((alarm) => alarm['id'] as String)
        .toList();
  }

  String? _getSavedPlaceName(String placeId) {
    try {
      final places = HiveHelper.getSavedLocations();
      for (final place in places) {
        if (place['id']?.toString() == placeId) {
          return place['name'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  PlaceState _getAggregatePlaceState(List<String> alarmIds) {
    var hasInsideIdle = false;
    for (final alarmId in alarmIds) {
      final state = _placeStates[alarmId];
      if (state == PlaceState.insideMoving) {
        return PlaceState.insideMoving;
      }
      if (state == PlaceState.insideIdle) {
        hasInsideIdle = true;
      }
    }
    return hasInsideIdle ? PlaceState.insideIdle : PlaceState.outside;
  }

  void _setStatesForAlarms(List<String> alarmIds, PlaceState state) {
    for (final alarmId in alarmIds) {
      _setPlaceState(alarmId, state);
    }
  }

  // ─── ENTER 처리 ───

  void _handleGeofenceEnter(String placeId, List<String> alarmIds) {
    // Init Guard 체크
    if (_initGuardUntil != null && DateTime.now().isBefore(_initGuardUntil!)) {
      _log('🛡️ Init Guard — ENTER 무시, INSIDE_IDLE 설정: $placeId');
      _setStatesForAlarms(alarmIds, PlaceState.insideIdle);
      return;
    }

    final currentState = _getAggregatePlaceState(alarmIds);

    if (currentState == PlaceState.insideIdle ||
        currentState == PlaceState.insideMoving) {
      // 이미 INSIDE 계열 → ENTER 무시
      if (currentState == PlaceState.insideMoving) {
        // INSIDE_MOVING 중에 다시 ENTER 수신 → 아직 안 나감 → IDLE로 안정화
        _log('🔙 [$placeId] INSIDE_MOVING 중 재 ENTER → INSIDE_IDLE 복원');
        _setStatesForAlarms(alarmIds, PlaceState.insideIdle);
        _evaluateMovingGpsNeed();
      } else {
        _log('⏭️ [$placeId] 이미 INSIDE_IDLE — ENTER 무시');
      }
      return;
    }

    // OUTSIDE → ENTER: 즉시 알람!
    _log('🎯 [$placeId] OUTSIDE → ENTER → 즉시 알람!');
    _setStatesForAlarms(alarmIds, PlaceState.insideIdle);
    _processEntryAlarm(placeId);
  }

  // ─── EXIT 처리 ───

  void _handleGeofenceExit(String placeId, List<String> alarmIds) {
    final currentState = _getAggregatePlaceState(alarmIds);

    if (currentState == PlaceState.outside) {
      _log('⏭️ [$placeId] 이미 OUTSIDE — EXIT 무시');
      return;
    }

    // INSIDE_IDLE 또는 INSIDE_MOVING → 지오펜스 EXIT 수신
    // 즉시 EXIT 알람 + OUTSIDE 전환
    _log('🎯 [$placeId] ${currentState.name} → 지오펜스 EXIT → 즉시 진출 처리!');
    _setStatesForAlarms(alarmIds, PlaceState.outside);
    _evaluateMovingGpsNeed();
    _processExitAlarm(placeId);
  }

  // ═══════════════════════════════════════════════════════════
  //  핵심: ActivityTransition (모션) 이벤트 수신
  // ═══════════════════════════════════════════════════════════

  /// 모션 이벤트 수신: isMoving=true (이동 시작), false (정지)
  void onActivityTransition(bool isMoving) {
    if (!_isRunning) return;

    _lastMotionTime = DateTime.now();
    _isCurrentlyMoving = isMoving;

    _log('🚶 모션: ${isMoving ? "이동 시작 🏃" : "정지 🛑"}');

    if (isMoving) {
      _onMotionStarted();
    } else {
      _onMotionStopped();
    }
  }

  // ─── 이동 시작 ───

  void _onMotionStarted() {
    // 정지 안정화 타이머 취소 (다시 움직이기 시작했으므로)
    _stillStabilizeTimer?.cancel();
    _stillStabilizeTimer = null;

    // INSIDE_IDLE인 모든 장소를 INSIDE_MOVING으로 전환
    bool anyTransitioned = false;
    for (final entry in _placeStates.entries.toList()) {
      if (entry.value == PlaceState.insideIdle) {
        _log('📍 [${_shortId(entry.key)}] INSIDE_IDLE → INSIDE_MOVING (모션 시작)');
        _setPlaceState(entry.key, PlaceState.insideMoving);
        anyTransitioned = true;
      }
    }

    if (anyTransitioned) {
      _startMovingGps();
    }
  }

  // ─── 이동 정지 ───

  void _onMotionStopped() {
    // 바로 IDLE로 전환하지 않음!
    // 정지 안정화 타이머 시작: _stillStabilizeDurationMs 동안 정지 유지 시 IDLE 복귀
    _stillStabilizeTimer?.cancel();

    if (!hasMovingMonitoring) {
      // INSIDE_MOVING인 장소가 없으면 안정화 불필요
      return;
    }

    _log('⏳ 정지 안정화 시작 (${_stillStabilizeDurationMs ~/ 1000}초 후 IDLE 복귀)');

    _stillStabilizeTimer = Timer(
      Duration(milliseconds: _stillStabilizeDurationMs),
      () {
        _log('✅ 정지 안정화 완료 → INSIDE_MOVING → INSIDE_IDLE 복귀');
        _transitionAllMovingToIdle();
      },
    );
  }

  /// 모든 INSIDE_MOVING 장소를 INSIDE_IDLE로 전환 + GPS OFF
  void _transitionAllMovingToIdle() {
    for (final entry in _placeStates.entries.toList()) {
      if (entry.value == PlaceState.insideMoving) {
        _log(
          '📍 [${_shortId(entry.key)}] INSIDE_MOVING → INSIDE_IDLE (정지 안정화)',
        );
        _setPlaceState(entry.key, PlaceState.insideIdle);
      }
    }
    _stopMovingGps();
  }

  // ═══════════════════════════════════════════════════════════
  //  GPS 감시 (INSIDE_MOVING 상태에서만)
  // ═══════════════════════════════════════════════════════════

  void _startMovingGps() {
    if (_movingGpsTimer != null) return; // 이미 활성

    _log('📡 GPS 폴링 시작 (${_movingGpsIntervalMs ~/ 1000}초 간격)');

    // 즉시 1회 체크 + 주기적 폴링
    _doMovingGpsCheck();
    _movingGpsTimer = Timer.periodic(
      Duration(milliseconds: _movingGpsIntervalMs),
      (_) => _doMovingGpsCheck(),
    );
  }

  void _stopMovingGps() {
    if (_movingGpsTimer == null) return;
    _movingGpsTimer?.cancel();
    _movingGpsTimer = null;
    _log('📡 GPS 폴링 중지');
  }

  /// GPS 폴링 1회: 모든 INSIDE_MOVING 장소에 대해 반경 이탈 확인
  Future<void> _doMovingGpsCheck() async {
    if (!_isRunning) return;

    // INSIDE_MOVING 장소 목록
    final movingPlaces =
        _placeStates.entries
            .where((e) => e.value == PlaceState.insideMoving)
            .map((e) => e.key)
            .toList();

    if (movingPlaces.isEmpty) {
      _stopMovingGps();
      return;
    }

    try {
      final position = await _getPosition();
      _currentPosition = position;
      if (!_positionController.isClosed) {
        _positionController.add(position);
      }

      if (!isTestMode && position.accuracy > 200.0) {
        _log('⚠️ GPS 정확도 낮음 (${position.accuracy.toInt()}m) — 정확도 보정 모드');
      }

      for (final alarmId in movingPlaces) {
        await _checkExitForPlace(alarmId, position);
      }
    } on TimeoutException {
      _log('⚠️ GPS 타임아웃');
    } catch (e) {
      _log('❌ GPS 실패: $e');
    }
  }

  /// 특정 장소에 대해 반경 이탈 확인
  Future<void> _checkExitForPlace(String alarmId, Position position) async {
    final placeInfo = await _getPlaceInfo(alarmId);
    if (placeInfo == null) {
      _log('❌ [${_shortId(alarmId)}] 장소 정보 없음');
      return;
    }

    final placeLat = _toDouble(placeInfo['latitude'] ?? placeInfo['lat']);
    final placeLng = _toDouble(placeInfo['longitude'] ?? placeInfo['lng']);
    final radius = _toDouble(
      placeInfo['radius'] ?? placeInfo['geofenceRadius'] ?? 100,
    );
    final placeName = (placeInfo['name'] ?? 'Unknown') as String;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      placeLat,
      placeLng,
    );

    // GPS 정확도가 낮으면 (지하주차장 등) 정확도만큼 버퍼 확대
    // 정확도 300m이더라도 distance > radius + 300m이면 확실히 나간 것
    final accuracyBuffer =
        position.accuracy > _exitBufferMeters
            ? position.accuracy
            : _exitBufferMeters;
    final exitThreshold = radius + accuracyBuffer;

    if (distance > exitThreshold) {
      _log(
        '🚨 [$placeName] GPS EXIT 확정! '
        'dist=${distance.toInt()}m > R+${accuracyBuffer.toInt()}=${exitThreshold.toInt()}m '
        '(accuracy=${position.accuracy.toInt()}m)',
      );
      _setPlaceState(alarmId, PlaceState.outside);
      _evaluateMovingGpsNeed();
      await _processExitAlarm(alarmId);
    } else {
      _log(
        '📍 [$placeName] 아직 내부 '
        '(dist=${distance.toInt()}m ≤ ${exitThreshold.toInt()}m, '
        'accuracy=${position.accuracy.toInt()}m)',
      );
    }
  }

  /// INSIDE_MOVING 장소가 남아있는지 확인 → 없으면 GPS 중지
  void _evaluateMovingGpsNeed() {
    if (!hasMovingMonitoring) {
      _stopMovingGps();
      _stillStabilizeTimer?.cancel();
      _stillStabilizeTimer = null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  ENTER 알람 즉시 처리
  // ═══════════════════════════════════════════════════════════

  Future<void> _processEntryAlarm(String placeId) async {
    final activeAlarms = await _getActiveAlarms();
    final placeName = await _getPlaceNameFromId(placeId);

    if (placeName == null) {
      _log('❌ placeId "$placeId" 장소 정보 없음');
      return;
    }

    // ★ "이미 내부" GPS 체크 제거
    //   이전에는 INITIAL_TRIGGER_ENTER 방지용이었으나,
    //   Init Guard (5초)가 이미 같은 역할을 수행하고 있음.
    //   차량으로 빠르게 진입 시 ENTER 이벤트 처리 시점에
    //   이미 중심 가까이 있어 알람이 억제되는 버그가 있었음.

    final matchingAlarms =
        activeAlarms.where((alarm) {
          final alarmPlaceId = alarm['placeId']?.toString();
          final alarmPlace = alarm['place'] ?? alarm['locationName'];
          final trigger = alarm['trigger'] ?? 'entry';
          if (trigger != 'entry') return false;
          return alarmPlaceId == placeId || alarmPlace == placeName;
        }).toList();

    for (final alarm in matchingAlarms) {
      final alarmId = alarm['id'] as String?;

      if (alarmId != null) {
        if (!await _isAlarmStillActive(alarmId)) continue;
        if (await _isAlarmDisabledByNative(alarmId)) continue;
        if (await _isAlarmInCooldown(alarmId, placeName)) continue;
        if (await _hasAlreadyTriggeredToday(alarmId, alarm, placeName))
          continue;
      }

      if (!await _checkDayCondition(alarm) || !_checkTimeCondition(alarm)) {
        _log('⏭️ [$placeName] 요일/시간 조건 불만족');
        continue;
      }

      _log('🚨 [$placeName] ENTRY 알람 트리거!');
      await _triggerAlarm(
        Map<String, dynamic>.from(alarm),
        'entry',
        _onTriggerCallback ?? (_, __) {},
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  EXIT 알람 처리
  // ═══════════════════════════════════════════════════════════

  Future<void> _processExitAlarm(String placeId) async {
    final activeAlarms = await _getActiveAlarms();
    final placeName = await _getPlaceNameFromId(placeId);

    if (placeName == null) {
      _log('❌ placeId "$placeId" 장소 정보 없음 (EXIT)');
      return;
    }

    final matchingAlarms =
        activeAlarms.where((alarm) {
          final alarmPlaceId = alarm['placeId']?.toString();
          final alarmPlace = alarm['place'] ?? alarm['locationName'];
          final trigger = alarm['trigger'] ?? 'entry';
          if (trigger != 'exit') return false;
          return alarmPlaceId == placeId || alarmPlace == placeName;
        }).toList();

    for (final alarm in matchingAlarms) {
      final alarmId = alarm['id'] as String?;

      if (alarmId != null) {
        if (!await _isAlarmStillActive(alarmId)) continue;
        if (await _isAlarmDisabledByNative(alarmId)) continue;
        if (await _isAlarmInCooldown(alarmId, placeName)) continue;
        if (await _hasAlreadyTriggeredToday(alarmId, alarm, placeName))
          continue;
      }

      if (!await _checkDayCondition(alarm) || !_checkTimeCondition(alarm)) {
        _log('⏭️ [$placeName] 요일/시간 조건 불만족');
        continue;
      }

      _log('🚨 [$placeName] EXIT 알람 트리거!');
      await _triggerAlarm(
        Map<String, dynamic>.from(alarm),
        'exit',
        _onTriggerCallback ?? (_, __) {},
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  상태 관리 & 영속성
  // ═══════════════════════════════════════════════════════════

  void _setPlaceState(String alarmId, PlaceState state) {
    final prev = _placeStates[alarmId];
    _placeStates[alarmId] = state;
    _savePlaceState(alarmId, state);

    if (prev != null && prev != state) {
      _log('📝 [${_shortId(alarmId)}] ${prev.name} → ${state.name}');
    }
  }

  Future<void> _savePlaceState(String alarmId, PlaceState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('place_state_$alarmId', state.name);
    } catch (e) {
      _log('❌ placeState 저장 실패: $e');
    }
  }

  Future<void> _loadPlaceStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('place_state_')) continue;
        final alarmId = key.substring('place_state_'.length);
        final stateStr = prefs.getString(key) ?? 'outside';
        _placeStates[alarmId] = _parseState(stateStr);
      }
      if (_placeStates.isNotEmpty) {
        _log('✅ placeStates 복원: ${_placeStates.length}개');
      }
    } catch (e) {
      _log('❌ placeStates 복원 실패: $e');
    }
  }

  PlaceState _parseState(String s) {
    switch (s) {
      case 'insideIdle':
        return PlaceState.insideIdle;
      case 'insideMoving':
        return PlaceState.insideMoving;
      case 'inside': // v2 호환
        return PlaceState.insideIdle;
      case 'exitVerify': // v2 호환 → insideMoving으로 매핑
        return PlaceState.insideMoving;
      default:
        return PlaceState.outside;
    }
  }

  /// ★ stale 상태 정리: 활성 알람에 없는 placeState 제거
  Future<void> _pruneStaleStates(
    List<Map<String, dynamic>> activeAlarms,
  ) async {
    final activeIds =
        activeAlarms.map((a) => a['id'] as String?).whereType<String>().toSet();

    // 메모리에서 제거
    final staleKeys =
        _placeStates.keys.where((k) => !activeIds.contains(k)).toList();
    for (final key in staleKeys) {
      _placeStates.remove(key);
    }

    // SharedPreferences에서 제거
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        if (!key.startsWith('place_state_')) continue;
        final alarmId = key.substring('place_state_'.length);
        if (!activeIds.contains(alarmId)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      _log('⚠️ stale 정리 SharedPrefs 실패: $e');
    }

    if (staleKeys.isNotEmpty) {
      _log('🧹 stale 상태 ${staleKeys.length}개 정리 완료');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  초기 상태 설정
  // ═══════════════════════════════════════════════════════════

  Future<void> _initializePlaceStates(
    List<Map<String, dynamic>> activeAlarms,
  ) async {
    final places = _extractAlarmedPlaces(activeAlarms);

    try {
      final pos = await _getPosition();

      if (isTestMode || pos.accuracy <= 100.0) {
        for (final alarm in activeAlarms) {
          final placeName =
              (alarm['place'] ?? alarm['locationName']) as String?;
          final placeId = alarm['placeId']?.toString();
          final alarmId = alarm['id'] as String?;
          if (alarmId == null) continue;

          final place = places.firstWhere(
            (p) =>
                (placeId != null &&
                    placeId.isNotEmpty &&
                    p['id']?.toString() == placeId) ||
                p['name'] == placeName,
            orElse: () => <String, dynamic>{},
          );
          if (place.isEmpty) continue;

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

          // v3: INSIDE → INSIDE_IDLE (GPS OFF). OUTSIDE → OUTSIDE.
          final state =
              distance <= radius ? PlaceState.insideIdle : PlaceState.outside;
          _placeStates[alarmId] = state;
          await _savePlaceState(alarmId, state);

          _log(
            '📍 초기: "$placeName" (${_shortId(alarmId)}) '
            '${state.name} (${distance.toInt()}m, R=${radius.toInt()}m)',
          );
        }
        _currentPosition = pos;
        return;
      }
    } catch (e) {
      _log('⚠️ 초기 GPS 실패: $e → 복원/기본값 사용');
    }

    // GPS 실패: 복원 안 된 항목은 OUTSIDE로 가정 (v3: 오탐 방지)
    for (final alarm in activeAlarms) {
      final alarmId = alarm['id'] as String?;
      final placeName = (alarm['place'] ?? alarm['locationName']) as String?;
      if (alarmId == null) continue;

      if (!_placeStates.containsKey(alarmId)) {
        _placeStates[alarmId] = PlaceState.outside;
        _log('📦 "$placeName" GPS 실패 → OUTSIDE 가정');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  알람 유효성 체크
  // ═══════════════════════════════════════════════════════════

  Future<bool> _isAlarmStillActive(String alarmId) async {
    try {
      final latestAlarm = HiveHelper.alarmBox.get(alarmId);
      if (latestAlarm == null || latestAlarm['enabled'] != true) {
        _log('⏭️ 알람 비활성화됨: ${_shortId(alarmId)}');
        return false;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<bool> _isAlarmDisabledByNative(String alarmId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // ★ 네이티브에서 직접 쓴 값을 읽기 위해 리로드

      // 1) 영구 비활성화 플래그 (알람 종료)
      final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
      if (isDisabled) {
        _log('🔒 네이티브 비활성화 감지: ${_shortId(alarmId)}');
        final box = HiveHelper.alarmBox;
        final current = box.get(alarmId);
        if (current != null) {
          final updated = Map<String, dynamic>.from(current);
          // ✅ 반복 알람이면 enabled=false 하지 않음 (safety check)
          final repeat = current['repeat'];
          final isRepeat = (repeat is List && repeat.isNotEmpty);
          if (isRepeat) {
            _log('🔄 반복 알람 — enabled 유지 (alarm_disabled 플래그만 제거)');
          } else {
            updated['enabled'] = false;
          }
          await box.put(alarmId, updated);
        }
        await prefs.remove('alarm_disabled_$alarmId');
        return true;
      }

      // 2) 스누즈 중 재트리거 방지 플래그 (일시적 — 알람은 비활성화하지 않음)
      final isSnoozed = prefs.getBool('alarm_snoozed_$alarmId') ?? false;
      if (isSnoozed) {
        _log('⏰ 스누즈 중 재트리거 차단: ${_shortId(alarmId)} (알람은 유지)');
        return true; // 플래그 제거 안 함 — 스누즈 알람 울릴 때까지 유지
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isAlarmInCooldown(String alarmId, String? placeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // ★ 네이티브에서 직접 쓴 값을 읽기 위해 리로드
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 트리거 직후 중복 방지 쿨다운 (60초)
      final cooldownMs = prefs.getInt('cooldown_until_$alarmId') ?? 0;
      if (cooldownMs > nowMs) {
        final remaining = (cooldownMs - nowMs) ~/ 1000;
        _log('⏭️ [${placeName ?? alarmId}] 쿨다운 중 (${remaining}초 남음)');
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  당일 중복 트리거 방지 (반복 알람용)
  // ═══════════════════════════════════════════════════════════

  /// 오늘 날짜 문자열 (yyyy-MM-dd)
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 반복 알람(요일별)이 오늘 이미 트리거되었는지 확인.
  /// - repeat == null (최초 1회 알람): 트리거 후 비활성화되므로 체크 불필요 → false
  /// - repeat가 날짜(String ISO8601): 특정 날짜 1회 알람 → 체크 불필요 → false
  /// - repeat가 요일 List: 오늘 이미 트리거되었으면 true (재트리거 차단)
  Future<bool> _hasAlreadyTriggeredToday(
    String alarmId,
    Map<String, dynamic> alarm,
    String? placeName,
  ) async {
    final repeat = alarm['repeat'];

    // 반복 알람(요일 리스트)만 체크 — 최초 1회 알람이나 특정 날짜 알람은 해당 없음
    if (repeat == null || repeat is! List || repeat.isEmpty) {
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final lastTriggeredDate = prefs.getString(
        'alarm_triggered_date_$alarmId',
      );
      final today = _todayDateString();

      if (lastTriggeredDate == today) {
        _log('📅 [${placeName ?? alarmId}] 오늘 이미 트리거됨 — 재트리거 차단');
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  강제 알람 트리거 (개발자 도구)
  // ═══════════════════════════════════════════════════════════

  Future<void> forceTriggerAlarm(Map<String, dynamic> alarmData) async {
    final trigger = (alarmData['trigger'] as String?) ?? 'entry';
    final callback = _onTriggerCallback ?? (_, __) {};
    _log('🧪 강제 알람: ${alarmData['name']} ($trigger)');

    // ★ 스누즈 체커가 안 돌고 있으면 시작 (강제 테스트 시 스누즈 동작 보장)
    if (_snoozeTimer == null || !_snoozeTimer!.isActive) {
      _startSnoozeChecker(callback);
      _log('🧪 스누즈 체커 강제 시작 (테스트용)');
    }

    await _triggerAlarm(alarmData, trigger, callback);
  }

  // ═══════════════════════════════════════════════════════════
  //  알람 트리거 (공용)
  // ═══════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  Future<void> _triggerAlarm(
    Map<String, dynamic> alarmData,
    String trigger,
    void Function(String, Map<String, dynamic>) onTrigger, {
    bool isSnoozeAlarm = false,
  }) async {
    final alarmId = alarmData['id'];

    // Hive 최신 상태 확인
    if (alarmId is String) {
      try {
        final box = HiveHelper.alarmBox;
        final latestAlarm = box.get(alarmId);
        if (latestAlarm == null) {
          _log('⛔ 알람 삭제됨 — 중단: ${alarmData['name']}');
          return;
        }

        if (isSnoozeAlarm) {
          final updated = Map<String, dynamic>.from(latestAlarm);
          updated['snoozePending'] = false;
          updated['enabled'] = true; // ★ 스누즈 알람 트리거 시 알람 재활성화
          await box.put(alarmId, updated);
          alarmData = updated;
        } else {
          if (latestAlarm['enabled'] != true) {
            _log('⛔ 알람 비활성 — 중단: ${alarmData['name']}');
            return;
          }
          alarmData = Map<String, dynamic>.from(latestAlarm);
        }
      } catch (e) {
        _log('⚠️ 최신 알람 확인 실패: $e');
      }
    }

    // SharedPreferences 비활성화 체크
    if (alarmId != null) {
      final prefs = await SharedPreferences.getInstance();
      final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
      if (isDisabled) {
        _log('⏭️ 알람 비활성 (SharedPrefs): ${alarmData['name']}');
        if (alarmId is String) {
          try {
            final box = HiveHelper.alarmBox;
            final current = box.get(alarmId);
            if (current != null) {
              final updated = Map<String, dynamic>.from(current);
              // ✅ 반복 알람이면 enabled=false 하지 않음
              final repeat = current['repeat'];
              final isRepeat = (repeat is List && repeat.isNotEmpty);
              if (!isRepeat) {
                updated['enabled'] = false;
              }
              await box.put(alarmId, updated);
            }
            await prefs.remove('alarm_disabled_$alarmId');
          } catch (_) {}
        }
        return;
      }
    }

    _log('✅ 알람 트리거: ${alarmData['name']} ($trigger)');

    // 트리거 직후 중복 방지 쿨다운 (3초)
    // ★ 'cooldown_until_' 키 사용 — 트리거 직후 중복 방지 (3초)
    if (alarmId is String) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cooldownUntil = DateTime.now().millisecondsSinceEpoch + 3000;
        await prefs.setInt('cooldown_until_$alarmId', cooldownUntil);

        // ★ 당일 트리거 기록 — 반복 알람의 같은 날 재트리거 방지
        final todayStr = _todayDateString();
        await prefs.setString('alarm_triggered_date_$alarmId', todayStr);
        _log('📅 당일 트리거 기록: ${_shortId(alarmId)} → $todayStr');
      } catch (e) {
        _log('⚠️ 쿨다운/트리거 기록 설정 실패: $e');
      }
    }

    // 트리거 카운트
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
      _log('❌ 트리거 카운트 실패: $e');
    }

    // ★ 알람 즉시 비활성화 제거
    // 사용자 선택에 따라 처리:
    //   - "다시 울림" → 비활성화 후 n분 후 재트리거
    //   - "알람 종료" → 영구 비활성화
    // 중복 트리거는 cooldown_until_ (60초)로 방지
    _log('ℹ️ 알람 유지 (사용자 선택 대기): ${alarmData['name']}');

    // 진동
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    // Native 전체화면 알람 (벨소리는 AlarmFullscreenActivity에서 직접 재생)
    try {
      await AlarmNotificationHelper.showNativeAlarm(
        title: alarmData['name'] ?? 'Ringinout',
        message: trigger == 'exit' ? '지정 장소에서 벗어났습니다' : '지정 장소에 도착했습니다',
        sound: alarmData['sound'] ?? 'assets/sounds/thoughtfulringtone.mp3',
        vibrate: (alarmData['vibrate'] ?? true) == true,
        alarmData: alarmData,
      );
    } catch (e) {
      _log('❌ 알람 표시 실패: $e');
    }

    // 콜백
    try {
      onTrigger(trigger, alarmData);
    } catch (e) {
      _log('❌ onTrigger 콜백 실패: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  장소 정보 조회
  // ═══════════════════════════════════════════════════════════

  Future<String?> _getPlaceNameFromId(String placeId) async {
    final info = await _getPlaceInfo(placeId);
    return info?['name'] as String?;
  }

  Future<Map<String, dynamic>?> _getPlaceInfo(String placeId) async {
    try {
      final places = HiveHelper.getSavedLocations();
      final allAlarms = HiveHelper.getLocationAlarms();

      for (final place in places) {
        if (place['id']?.toString() == placeId) {
          return place;
        }
      }

      // 하위 호환: 과거 alarmId 기반 이벤트도 알람 레코드를 통해 장소 복원
      for (final alarm in allAlarms) {
        if (alarm['id'] == placeId) {
          final alarmPlaceId = alarm['placeId']?.toString();
          if (alarmPlaceId != null && alarmPlaceId.isNotEmpty) {
            for (final place in places) {
              if (place['id']?.toString() == alarmPlaceId) return place;
            }
          }

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

      // 폴백: placeId 자체가 장소 이름
      for (final place in places) {
        if (place['name'] == placeId) return place;
      }

      return null;
    } catch (e) {
      _log('❌ 장소 정보 조회 실패: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  조건 체크
  // ═══════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  Future<bool> _checkDayCondition(Map<String, dynamic> alarm) async {
    final repeat = alarm['repeat'];

    final now = DateTime.now();

    if (repeat == null) {
      return _checkHolidayCondition(alarm, now);
    }

    if (repeat is String) {
      final targetDate = DateTime.tryParse(repeat);
      if (targetDate != null) {
        final todayOnly = DateTime(now.year, now.month, now.day);
        final targetOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        return todayOnly.isAtSameMomentAs(targetOnly) &&
            await _checkHolidayCondition(alarm, now);
      }
      return false;
    }

    if (repeat is List && repeat.isNotEmpty) {
      final weekdayStr =
          ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][now.weekday % 7];
      // 구 데이터(한글/일본어/중국어 요일) 호환: 영문 코드로 정규화 후 비교
      final days = repeat.map((e) => _toWeekdayCode(e.toString())).toList();
      return days.contains(weekdayStr) &&
          await _checkHolidayCondition(alarm, now);
    }

    return _checkHolidayCondition(alarm, now);
  }

  /// 구 데이터(한글/일본어/중국어 요일 등) → 영문 코드 변환 (마이그레이션 호환)
  static const _weekdayCodeMap = <String, String>{
    // Korean
    '일': 'sun',
    '월': 'mon',
    '화': 'tue',
    '수': 'wed',
    '목': 'thu',
    '금': 'fri',
    '토': 'sat',
    // Japanese
    '日': 'sun',
    '月': 'mon',
    '火': 'tue',
    '水': 'wed',
    '木': 'thu',
    '金': 'fri',
    '土': 'sat',
    // Chinese
    '一': 'mon', '二': 'tue', '三': 'wed', '四': 'thu', '五': 'fri', '六': 'sat',
    // English abbreviated (대소문자)
    'Sun': 'sun',
    'Mon': 'mon',
    'Tue': 'tue',
    'Wed': 'wed',
    'Thu': 'thu',
    'Fri': 'fri',
    'Sat': 'sat',
  };

  static String _toWeekdayCode(String val) => _weekdayCodeMap[val] ?? val;

  Future<bool> _checkHolidayCondition(
    Map<String, dynamic> alarm,
    DateTime date,
  ) async {
    if (alarm['excludeHolidays'] != true) {
      return true;
    }

    final holidayStatus = await HolidayService.instance.getHolidayStatus(date);
    if (!holidayStatus.isHoliday) {
      return true;
    }

    if (!holidayStatus.isSubstituteOrTemporary) {
      _log('⛔ [${alarm['name'] ?? alarm['id']}] 공휴일 제외 조건으로 차단');
      return false;
    }

    final holidayBehavior = (alarm['holidayBehavior'] as String?) ?? 'on';
    final allow = holidayBehavior == 'on';
    if (!allow) {
      _log('⛔ [${alarm['name'] ?? alarm['id']}] 대체/임시 공휴일 차단');
    }
    return allow;
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

  // ═══════════════════════════════════════════════════════════
  //  활성 알람 조회
  // ═══════════════════════════════════════════════════════════

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
      _log('❌ 활성 알람 조회 실패: $e');
      return [];
    }
  }

  @pragma('vm:entry-point')
  List<Map<String, dynamic>> _extractAlarmedPlaces(
    List<Map<String, dynamic>> alarms,
  ) {
    final alarmPlaceIds =
        alarms
            .where((a) => a['enabled'] == true)
            .map((a) => a['placeId']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet();

    final fallbackPlaceNames =
        alarms
            .where(
              (a) =>
                  a['enabled'] == true &&
                  ((a['placeId']?.toString().isEmpty ?? true)) &&
                  (a['place'] ?? a['locationName']) != null,
            )
            .map((a) => (a['place'] ?? a['locationName']) as String)
            .toSet();

    try {
      return HiveHelper.getSavedLocations()
          .where(
            (p) =>
                alarmPlaceIds.contains(p['id']?.toString()) ||
                fallbackPlaceNames.contains(p['name']),
          )
          .toList();
    } catch (e) {
      _log('❌ _extractAlarmedPlaces 실패: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  서비스 상태 영속성
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveServiceState(bool running) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('geofence_running', running);
    } catch (e) {
      _log('⚠️ 서비스 상태 저장 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  Future<void> restoreServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasRunning = prefs.getBool('geofence_running') ?? false;
      if (wasRunning && !_isRunning) {
        _log('🔄 서비스 복원 예약');
      }
    } catch (e) {
      _log('⚠️ 서비스 복원 실패: $e');
    }
  }

  Future<bool> _checkPermissionsSafely() async {
    try {
      final status = await Permission.locationAlways.status;
      if (status.isGranted) return true;
      final foreground = await Permission.locationWhenInUse.status;
      return foreground.isGranted;
    } catch (e) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  Watchdog Heartbeat
  // ═══════════════════════════════════════════════════════════

  static const _watchdogChannel = MethodChannel(
    'com.bnt0514.ringinout/watchdog',
  );

  void _startWatchdogHeartbeat() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => sendWatchdogHeartbeat(),
    );
    sendWatchdogHeartbeat();
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
      // 채널 미등록
    } catch (e) {
      debugPrint('[LMS] ⚠️ Watchdog heartbeat 실패: $e');
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

  // ═══════════════════════════════════════════════════════════
  //  스누즈 체크
  // ═══════════════════════════════════════════════════════════

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
    // ★ 네이티브 dismissAlarm()이 SharedPrefs에 남긴 비활성화 플래그 처리
    await _checkNativeDisabledFlags();

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
            _log('⏰ 스누즈 만료 → 리마인더: ${schedule['alarmTitle']}');
            await _triggerAlarm(
              alarmData,
              alarmData['trigger'] ?? 'entry',
              onTrigger,
              isSnoozeAlarm: true,
            );
          }
        }
      }
    } catch (e) {
      _log('❌ 스누즈 체크 실패: $e');
    }
  }

  /// 네이티브 AlarmFullscreenActivity의 dismissAlarm()이 SharedPreferences에 남긴
  /// alarm_disabled_ 플래그를 주기적으로 확인하여 Hive에 반영
  Future<void> _checkNativeDisabledFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final box = HiveHelper.alarmBox;
      for (var key in box.keys) {
        final alarm = box.get(key);
        if (alarm == null) continue;
        final alarmId = alarm['id'] as String?;
        if (alarmId == null) continue;

        final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
        if (isDisabled) {
          _log('🔕 네이티브 비활성화 플래그 감지: ${alarm['name']} (${_shortId(alarmId)})');
          final updated = Map<String, dynamic>.from(alarm);

          // ✅ 반복 알람이면 enabled=false 하지 않음
          final repeat = alarm['repeat'];
          final isRepeat = (repeat is List && repeat.isNotEmpty);
          if (isRepeat) {
            _log(
              '🔄 반복 알람 — enabled 유지 (alarm_disabled 플래그만 제거): ${alarm['name']}',
            );
            updated['snoozePending'] = false;
          } else {
            updated['enabled'] = false;
            updated['snoozePending'] = false;

            // 트리거 카운트 제거 (일회성만)
            try {
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
            } catch (_) {}
          }

          await box.put(alarmId, updated);
          await prefs.remove('alarm_disabled_$alarmId');

          // 스누즈 스케줄 제거 (반복/일회 모두)
          try {
            final snoozeBox = await Hive.openBox('snoozeSchedules');
            await snoozeBox.delete(alarmId);
          } catch (_) {}

          _log('✅ 네이티브 비활성화 → Hive 반영 완료: ${alarm['name']} (repeat=$isRepeat)');
        }
      }
    } catch (e) {
      _log('⚠️ 네이티브 비활성화 플래그 체크 실패: $e');
    }
  }

  static Future<void> clearAllSnoozeSchedules() async {
    try {
      final box = await Hive.openBox('snoozeSchedules');
      await box.clear();
    } catch (_) {}
  }

  /// 앱 복귀(resume) 시 즉시 네이티브 비활성화 플래그를 처리
  /// _checkNativeDisabledFlags()와 동일 로직이지만 static으로 어디서든 호출 가능
  static Future<void> processNativeDisabledFlagsNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final box = HiveHelper.alarmBox;
      for (var key in box.keys) {
        final alarm = box.get(key);
        if (alarm == null) continue;
        final alarmId = alarm['id'] as String?;
        if (alarmId == null) continue;

        final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
        if (isDisabled) {
          final updated = Map<String, dynamic>.from(alarm);

          // ✅ 반복 알람이면 enabled=false 하지 않음
          final repeat = alarm['repeat'];
          final isRepeat = (repeat is List && repeat.isNotEmpty);
          if (isRepeat) {
            debugPrint('[LMS] 🔄 반복 알람 — enabled 유지 (즉시): ${alarm['name']}');
            updated['snoozePending'] = false;
          } else {
            debugPrint('[LMS] 🔕 네이티브 비활성화 플래그 감지 (즉시): ${alarm['name']}');
            updated['enabled'] = false;
            updated['snoozePending'] = false;

            // 트리거 카운트 제거 (일회성만)
            try {
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
            } catch (_) {}
          }

          await box.put(alarmId, updated);
          await prefs.remove('alarm_disabled_$alarmId');

          // 스누즈 스케줄 제거 (반복/일회 모두)
          try {
            final snoozeBox = await Hive.openBox('snoozeSchedules');
            await snoozeBox.delete(alarmId);
          } catch (_) {}

          debugPrint(
            '[LMS] ✅ 네이티브 비활성화 → Hive 반영 완료 (즉시): ${alarm['name']} (repeat=$isRepeat)',
          );
        }
      }
    } catch (e) {
      debugPrint('[LMS] ⚠️ processNativeDisabledFlagsNow 실패: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  하위 호환 API
  // ═══════════════════════════════════════════════════════════

  Future<void> startServiceIfSafe() async {
    if (!_isRunning) {
      await startBackgroundMonitoring(_onTriggerCallback ?? (_, __) {});
    }
  }

  Future<void> updatePlaces() async {
    if (!_isRunning) return;

    final activeAlarms = await _getActiveAlarms();
    _trackedPlaceNames =
        activeAlarms
            .map((a) => (a['place'] ?? a['locationName'] ?? '') as String)
            .where((n) => n.isNotEmpty)
            .toSet();

    // ★ 새로 추가된 알람의 초기 상태 설정
    //   기존에 _placeStates에 없는 알람 → GPS로 현재 위치 확인 → INSIDE/OUTSIDE 설정
    //   이미 반경 안에 있는데 지오펜스 재등록으로 INITIAL_TRIGGER_ENTER가
    //   발생해도 INSIDE_IDLE이므로 ENTER 무시됨
    final newAlarms =
        activeAlarms.where((a) {
          final id = a['id'] as String?;
          return id != null && !_placeStates.containsKey(id);
        }).toList();

    if (newAlarms.isNotEmpty) {
      await _initializePlaceStates(newAlarms);
      _log('📍 신규 알람 ${newAlarms.length}개 초기 상태 설정 완료');

      // Init Guard: 지오펜스 재등록에 의한 INITIAL_TRIGGER 방어
      _initGuardUntil = DateTime.now().add(const Duration(seconds: 5));
      _log('🛡️ Init Guard ON (장소 업데이트 — 5초)');
    }

    // stale 상태 정리
    await _pruneStaleStates(activeAlarms);
    _log('✅ 장소 업데이트 (추적: $_trackedPlaceNames)');
  }

  Future<Position?> getCurrentPositionSafe() async {
    try {
      final position = await _getPosition();
      if (!isTestMode && position.accuracy > 50.0) return null;
      return position;
    } catch (e) {
      return null;
    }
  }

  bool? getInsideStatus(String placeName) => null;

  PlaceState? getPlaceState(String alarmId) => _placeStates[alarmId];

  Map<String, PlaceState> getAllPlaceStates() => Map.unmodifiable(_placeStates);

  // ═══════════════════════════════════════════════════════════
  //  장소 상태 리셋
  // ═══════════════════════════════════════════════════════════

  @pragma('vm:entry-point')
  Future<void> resetPlaceState(String placeKey) async {
    try {
      final pos = await _getPosition();

      if (!isTestMode && pos.accuracy > 100.0) return;

      final places = HiveHelper.getSavedLocations();
      final place = places.firstWhere(
        (p) =>
            p['id']?.toString() == placeKey ||
            p['name']?.toString() == placeKey,
        orElse: () => <String, dynamic>{},
      );
      if (place.isEmpty) return;

      final resolvedPlaceId = place['id']?.toString();
      final resolvedPlaceName = place['name']?.toString();

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
      final state =
          distance <= radius ? PlaceState.insideIdle : PlaceState.outside;

      final activeAlarms = await _getActiveAlarms();
      for (final alarm in activeAlarms) {
        final alarmPlaceName = alarm['place'] ?? alarm['locationName'];
        final alarmPlaceId = alarm['placeId']?.toString();
        final matchesPlace =
            (resolvedPlaceId != null && alarmPlaceId == resolvedPlaceId) ||
            alarmPlaceName == resolvedPlaceName;
        if (matchesPlace) {
          final alarmId = alarm['id'] as String?;
          if (alarmId != null) {
            _setPlaceState(alarmId, state);
          }
        }
      }

      _log(
        '✅ resetPlaceState: ${resolvedPlaceName ?? placeKey} → ${state.name}',
      );
    } catch (e) {
      _log('❌ resetPlaceState 실패: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  유틸리티
  // ═══════════════════════════════════════════════════════════

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _shortId(String id) => id.length > 8 ? id.substring(0, 8) : id;

  void _log(String message) {
    final tag = 'LMS';
    debugPrint('[$tag] $message');
    try {
      AppLogBuffer.record(tag, message);
    } catch (_) {}
  }
}

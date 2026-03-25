// lib/location/place_state_engine.dart
//
// Step D: 판정 엔진(PlaceStateEngine) - 3-state 상태머신
//
// 절대 규칙:
// - big/small geofence는 판정 반경이 아님 (모드 전환용)
// - 실제 진입/진출 알림은 사용자 반경 R + accuracy 기반 판정으로만 발생
// - Exit는 빠르게(FAST path), Enter는 보수적으로
// - UNKNOWN 상태에서 알림 금지(워밍업)
// - 모든 키는 불변 ID 기반

import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/location/geofence_tuning.dart';

// ========== 상태/결과 타입 ==========

/// 장소의 3-state
enum PlaceState {
  UNKNOWN,
  INSIDE,
  OUTSIDE;

  static PlaceState fromString(String? s) {
    switch (s) {
      case 'INSIDE':
        return PlaceState.INSIDE;
      case 'OUTSIDE':
        return PlaceState.OUTSIDE;
      default:
        return PlaceState.UNKNOWN;
    }
  }
}

/// 모니터링 모드 (big/small geofence에 의해 결정)
enum MonitorMode {
  IDLE, // 위치 샘플 수집 없음
  ARMED, // big inside - 저전력 간헐 확인
  HOT, // small inside - 짧고 강한 판정
}

/// 판정 결과
class DecisionResult {
  /// 새로운 상태
  final PlaceState newState;

  /// Exit 알림 발생 여부
  final bool shouldExitAlert;

  /// Enter 알림 발생 여부 (옵션)
  final bool shouldEnterAlert;

  /// 판정 이유 (로그용)
  final String reason;

  const DecisionResult({
    required this.newState,
    this.shouldExitAlert = false,
    this.shouldEnterAlert = false,
    required this.reason,
  });

  @override
  String toString() =>
      'DecisionResult(state=$newState, exit=$shouldExitAlert, enter=$shouldEnterAlert, reason=$reason)';
}

/// 위치 샘플
class LocationSample {
  final double latitude;
  final double longitude;
  final double accuracy; // meters
  final double speed; // m/s (-1 if unknown)
  final int timestampMs; // epoch ms

  const LocationSample({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed = -1,
    required this.timestampMs,
  });
}

/// 장소 정보
class PlaceInfo {
  final String placeId; // 불변 ID
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters; // 사용자 설정 반경 R
  final TuningParams tuning;

  PlaceInfo({
    required this.placeId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  }) : tuning = computeTuning(radiusMeters);
}

// ========== 장소별 상태 레코드 ==========

class _PlaceRecord {
  PlaceState state;
  int lastConfirmedAtMs;
  int snoozeUntilMs;
  int placeVersion;

  // confirm 카운터 (메모리)
  int outsideStreakCount;
  int outsideSinceMs;
  int insideStreakCount;
  int insideSinceMs;

  _PlaceRecord({
    this.state = PlaceState.UNKNOWN,
    this.lastConfirmedAtMs = 0,
    this.snoozeUntilMs = 0,
    this.placeVersion = 0,
    this.outsideStreakCount = 0,
    this.outsideSinceMs = 0,
    this.insideStreakCount = 0,
    this.insideSinceMs = 0,
  });
}

// ========== 판정 엔진 ==========

class PlaceStateEngine {
  // 장소별 레코드 (메모리 캐시)
  final Map<String, _PlaceRecord> _records = {};

  // SharedPreferences 키 접두사
  static const _prefix = 'pse_';

  // (쿨다운 제거됨 - 사용자 선택 스누즈로 대체)

  // Exit confirm: N=2, dwell 짧게
  static const _exitConfirmN = 2;
  static const _exitConfirmDwellVehicleMs = 3000; // 차량: 0~3초
  static const _exitConfirmDwellWalkMs = 8000; // 도보: 3~8초

  // Enter/재무장 confirm: N=3, dwell 보수적
  static const _enterConfirmN = 3;
  static const _enterConfirmDwellMs = 8000; // 5~12초

  /// SharedPreferences에서 상태 로드
  Future<void> loadStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith('${_prefix}state_')) {
          final placeId = key.substring('${_prefix}state_'.length);
          final stateStr = prefs.getString(key);
          final record = _getOrCreate(placeId);
          record.state = PlaceState.fromString(stateStr);
          record.lastConfirmedAtMs =
              prefs.getInt('${_prefix}lastConfirmedAt_$placeId') ?? 0;
          record.snoozeUntilMs =
              prefs.getInt('${_prefix}snoozeUntil_$placeId') ?? 0;
          record.placeVersion =
              prefs.getInt('${_prefix}placeVersion_$placeId') ?? 0;
        }
      }
      print('✅ PlaceStateEngine 상태 로드: ${_records.length}개');
    } catch (e) {
      print('❌ PlaceStateEngine 로드 실패: $e');
    }
  }

  /// SharedPreferences에 상태 저장
  Future<void> _saveState(String placeId) async {
    try {
      final record = _records[placeId];
      if (record == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_prefix}state_$placeId', record.state.name);
      await prefs.setInt(
        '${_prefix}lastConfirmedAt_$placeId',
        record.lastConfirmedAtMs,
      );
      await prefs.setInt(
        '${_prefix}snoozeUntil_$placeId',
        record.snoozeUntilMs,
      );
      await prefs.setInt(
        '${_prefix}placeVersion_$placeId',
        record.placeVersion,
      );
    } catch (e) {
      print('❌ PlaceStateEngine 저장 실패: $e');
    }
  }

  /// 장소 레코드 가져오기 (없으면 생성)
  _PlaceRecord _getOrCreate(String placeId) {
    return _records.putIfAbsent(placeId, () => _PlaceRecord());
  }

  /// 장소의 현재 상태 조회
  PlaceState getState(String placeId) {
    return _records[placeId]?.state ?? PlaceState.UNKNOWN;
  }

  /// 장소 좌표/반경 변경 시 상태 리셋
  Future<void> onPlaceConfigChanged(String placeId) async {
    final record = _getOrCreate(placeId);
    record.state = PlaceState.UNKNOWN;
    record.placeVersion++;
    record.outsideStreakCount = 0;
    record.insideStreakCount = 0;
    record.outsideSinceMs = 0;
    record.insideSinceMs = 0;
    record.lastConfirmedAtMs = 0;
    record.snoozeUntilMs = 0;
    await _saveState(placeId);
    print('🔄 PlaceStateEngine: $placeId 설정 변경 → UNKNOWN 리셋');
  }

  /// 장소 삭제 시 레코드 정리
  Future<void> removePlaceState(String placeId) async {
    _records.remove(placeId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_prefix}state_$placeId');
      await prefs.remove('${_prefix}lastConfirmedAt_$placeId');
      await prefs.remove('${_prefix}snoozeUntil_$placeId');
      await prefs.remove('${_prefix}placeVersion_$placeId');
    } catch (_) {}
  }

  // ========== 판정 순수 함수 ==========

  /// Exit FAST 판정: distance - accuracy > R → 즉시 OUTSIDE
  static bool evaluateExitFast(double distance, double accuracy, double R) {
    return (distance - accuracy) > R;
  }

  /// Enter/재무장 FAST 판정: distance + accuracy < R_rearm → 즉시 INSIDE
  static bool evaluateInsideFast(
    double distance,
    double accuracy,
    double R_rearm,
  ) {
    return (distance + accuracy) < R_rearm;
  }

  /// 애매한 영역인지 판정
  /// distance > R 이지만 FAST 조건이 안 됨 (accuracy 큼)
  static bool isAmbiguousExit(double distance, double accuracy, double R) {
    return distance > R && !evaluateExitFast(distance, accuracy, R);
  }

  /// 애매한 Enter인지 판정
  static bool isAmbiguousEnter(
    double distance,
    double accuracy,
    double R_rearm,
  ) {
    return distance <= R_rearm &&
        !evaluateInsideFast(distance, accuracy, R_rearm);
  }

  // ========== 메인 판정 ==========

  /// 위치 샘플에 대한 판정 수행
  ///
  /// [place] 장소 정보
  /// [sample] 위치 샘플
  /// [mode] 현재 모니터링 모드 (ARMED/HOT)
  ///
  /// 반환: 판정 결과 (newState, shouldExitAlert, shouldEnterAlert, reason)
  Future<DecisionResult> onLocationSample(
    PlaceInfo place,
    LocationSample sample,
    MonitorMode mode,
  ) async {
    final record = _getOrCreate(place.placeId);
    final tuning = place.tuning;
    final now = sample.timestampMs;

    // 거리 계산
    final distance = _haversineDistance(
      sample.latitude,
      sample.longitude,
      place.latitude,
      place.longitude,
    );

    // 로그
    print(
      '🧠 PSE [${place.name}] mode=$mode state=${record.state} '
      'd=${distance.toInt()}m acc=${sample.accuracy.toInt()}m '
      'R=${tuning.R.toInt()} H=${tuning.H.toInt()} R_rearm=${tuning.R_rearm.toInt()} '
      'speed=${sample.speed.toStringAsFixed(1)}m/s',
    );

    // 1) ARMED 모드에서는 Exit Alert를 발생시키지 않음 (HOT에서만)
    if (mode == MonitorMode.ARMED) {
      return _handleArmedSample(record, place, sample, distance, now);
    }

    // 2) HOT 모드: 정밀 판정
    return _handleHotSample(record, place, sample, distance, now);
  }

  /// ARMED 모드 처리: 워밍업/상태 확인만, 알림 없음
  DecisionResult _handleArmedSample(
    _PlaceRecord record,
    PlaceInfo place,
    LocationSample sample,
    double distance,
    int now,
  ) {
    final tuning = place.tuning;

    // ARMED에서는 상태 워밍업만 수행
    if (record.state == PlaceState.UNKNOWN) {
      // UNKNOWN → 확정은 할 수 있지만 알림 금지
      if (evaluateInsideFast(distance, sample.accuracy, tuning.R_rearm)) {
        record.state = PlaceState.INSIDE;
        record.lastConfirmedAtMs = now;
        _saveState(place.placeId);
        return DecisionResult(
          newState: PlaceState.INSIDE,
          reason: 'ARMED: UNKNOWN→INSIDE 워밍업 (알림X)',
        );
      }
      if (evaluateExitFast(distance, sample.accuracy, tuning.R)) {
        record.state = PlaceState.OUTSIDE;
        record.lastConfirmedAtMs = now;
        _saveState(place.placeId);
        return DecisionResult(
          newState: PlaceState.OUTSIDE,
          reason: 'ARMED: UNKNOWN→OUTSIDE 워밍업 (알림X)',
        );
      }
      return DecisionResult(
        newState: PlaceState.UNKNOWN,
        reason: 'ARMED: UNKNOWN 유지 (애매)',
      );
    }

    // 이미 INSIDE/OUTSIDE → 상태 유지, HOT 전환 판단은 상위에서
    return DecisionResult(
      newState: record.state,
      reason: 'ARMED: 상태 유지 (${record.state})',
    );
  }

  /// HOT 모드 처리: 정밀 판정, 알림 발생 가능
  Future<DecisionResult> _handleHotSample(
    _PlaceRecord record,
    PlaceInfo place,
    LocationSample sample,
    double distance,
    int now,
  ) async {
    final tuning = place.tuning;

    // === 1) UNKNOWN 처리: 확정만, 알림 절대 금지 ===
    if (record.state == PlaceState.UNKNOWN) {
      if (evaluateInsideFast(distance, sample.accuracy, tuning.R_rearm)) {
        record.state = PlaceState.INSIDE;
        record.lastConfirmedAtMs = now;
        await _saveState(place.placeId);
        print('🧠 PSE: UNKNOWN→INSIDE 확정 (알림X)');
        return DecisionResult(
          newState: PlaceState.INSIDE,
          reason: 'HOT: UNKNOWN→INSIDE (워밍업, 알림X)',
        );
      }
      if (evaluateExitFast(distance, sample.accuracy, tuning.R)) {
        record.state = PlaceState.OUTSIDE;
        record.lastConfirmedAtMs = now;
        await _saveState(place.placeId);
        print('🧠 PSE: UNKNOWN→OUTSIDE 확정 (알림X)');
        return DecisionResult(
          newState: PlaceState.OUTSIDE,
          reason: 'HOT: UNKNOWN→OUTSIDE (워밍업, 알림X)',
        );
      }
      return DecisionResult(
        newState: PlaceState.UNKNOWN,
        reason: 'HOT: UNKNOWN 유지 (애매)',
      );
    }

    // === 2) Exit 우선 (FAST path) ===
    if (record.state == PlaceState.INSIDE) {
      // 스누즈 체크 (사용자가 Passing 시 선택한 시간)
      if (now < record.snoozeUntilMs) {
        final remaining = record.snoozeUntilMs - now;
        print('🧠 PSE: 스누즈 중 (${remaining ~/ 1000}초 남음)');
        // 스누즈 중에도 INSIDE→OUTSIDE 상태 전이는 가능 (알림만 막음)
        if (evaluateExitFast(distance, sample.accuracy, tuning.R)) {
          record.state = PlaceState.OUTSIDE;
          record.lastConfirmedAtMs = now;
          _resetConfirmCounters(record);
          await _saveState(place.placeId);
          return DecisionResult(
            newState: PlaceState.OUTSIDE,
            shouldExitAlert: false, // 스누즈로 알림 막음
            reason: 'HOT: INSIDE→OUTSIDE (스누즈 중, 알림X)',
          );
        }
        return DecisionResult(
          newState: PlaceState.INSIDE,
          reason: 'HOT: 스누즈 중',
        );
      }

      // Exit FAST: distance - accuracy > R → 즉시 Exit Alert
      if (evaluateExitFast(distance, sample.accuracy, tuning.R)) {
        record.state = PlaceState.OUTSIDE;
        record.lastConfirmedAtMs = now;
        _resetConfirmCounters(record);
        await _saveState(place.placeId);
        print(
          '🚨 PSE: EXIT FAST! d=${distance.toInt()} - acc=${sample.accuracy.toInt()} > R=${tuning.R.toInt()}',
        );
        return DecisionResult(
          newState: PlaceState.OUTSIDE,
          shouldExitAlert: true,
          reason: 'HOT: Exit FAST (d-acc > R)',
        );
      }

      // Exit CONFIRM: distance > R이지만 FAST 조건 불충분
      if (isAmbiguousExit(distance, sample.accuracy, tuning.R)) {
        record.outsideStreakCount++;
        if (record.outsideSinceMs == 0) {
          record.outsideSinceMs = now;
        }

        // dwell 시간 결정 (속도 기반)
        final isVehicle = sample.speed > 5.0;
        final dwellRequired =
            isVehicle ? _exitConfirmDwellVehicleMs : _exitConfirmDwellWalkMs;
        final elapsed = now - record.outsideSinceMs;

        print(
          '🧠 PSE: Exit CONFIRM streak=${record.outsideStreakCount}/$_exitConfirmN '
          'dwell=${elapsed}ms/${dwellRequired}ms '
          '${isVehicle ? "(차량)" : "(도보)"}',
        );

        if (record.outsideStreakCount >= _exitConfirmN &&
            elapsed >= dwellRequired) {
          record.state = PlaceState.OUTSIDE;
          record.lastConfirmedAtMs = now;
          _resetConfirmCounters(record);
          await _saveState(place.placeId);
          print('🚨 PSE: EXIT CONFIRM 성공!');
          return DecisionResult(
            newState: PlaceState.OUTSIDE,
            shouldExitAlert: true,
            reason: 'HOT: Exit CONFIRM (N=$_exitConfirmN, dwell=${elapsed}ms)',
          );
        }

        return DecisionResult(
          newState: PlaceState.INSIDE,
          reason: 'HOT: Exit CONFIRM 진행 중',
        );
      }

      // 여전히 INSIDE (확실히 안에 있음)
      _resetExitConfirm(record);
      return DecisionResult(
        newState: PlaceState.INSIDE,
        reason: 'HOT: INSIDE 유지 (d=${distance.toInt()}m)',
      );
    }

    // === 3) Enter/재무장 (OUTSIDE → INSIDE 확정) ===
    if (record.state == PlaceState.OUTSIDE) {
      // OUTSIDE 상태에서는 Exit Alert 발생 불가 (재무장 전 재진출 금지)

      // Enter FAST: distance + accuracy < R_rearm → INSIDE 확정
      if (evaluateInsideFast(distance, sample.accuracy, tuning.R_rearm)) {
        record.insideStreakCount++;
        if (record.insideSinceMs == 0) {
          record.insideSinceMs = now;
        }

        final elapsed = now - record.insideSinceMs;

        print(
          '🧠 PSE: Enter FAST streak=${record.insideStreakCount}/$_enterConfirmN '
          'dwell=${elapsed}ms/${_enterConfirmDwellMs}ms',
        );

        if (record.insideStreakCount >= _enterConfirmN &&
            elapsed >= _enterConfirmDwellMs) {
          record.state = PlaceState.INSIDE;
          record.lastConfirmedAtMs = now;
          _resetConfirmCounters(record);
          await _saveState(place.placeId);
          print('✅ PSE: INSIDE 확정 (재무장 완료)');
          return DecisionResult(
            newState: PlaceState.INSIDE,
            shouldEnterAlert: true, // 옵션: Enter Alert
            reason: 'HOT: Enter 재무장 (OUTSIDE→INSIDE)',
          );
        }

        return DecisionResult(
          newState: PlaceState.OUTSIDE,
          reason: 'HOT: Enter 확정 진행 중',
        );
      }

      // 아직 밖에 있음
      _resetEnterConfirm(record);
      return DecisionResult(
        newState: PlaceState.OUTSIDE,
        reason: 'HOT: OUTSIDE 유지 (d=${distance.toInt()}m)',
      );
    }

    // 도달 불가 (안전)
    return DecisionResult(newState: record.state, reason: 'HOT: 알 수 없는 상태');
  }

  // ========== 헬퍼 ==========

  void _resetConfirmCounters(_PlaceRecord record) {
    record.outsideStreakCount = 0;
    record.outsideSinceMs = 0;
    record.insideStreakCount = 0;
    record.insideSinceMs = 0;
  }

  void _resetExitConfirm(_PlaceRecord record) {
    record.outsideStreakCount = 0;
    record.outsideSinceMs = 0;
  }

  void _resetEnterConfirm(_PlaceRecord record) {
    record.insideStreakCount = 0;
    record.insideSinceMs = 0;
  }

  /// Haversine 거리 계산 (미터)
  static double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;

  /// 전체 상태 디버그 출력
  Map<String, dynamic> getDebugInfo() {
    final result = <String, dynamic>{};
    for (final entry in _records.entries) {
      result[entry.key] = {
        'state': entry.value.state.name,
        'lastConfirmedAtMs': entry.value.lastConfirmedAtMs,
        'snoozeUntilMs': entry.value.snoozeUntilMs,
        'outsideStreak': entry.value.outsideStreakCount,
        'insideStreak': entry.value.insideStreakCount,
      };
    }
    return result;
  }

  /// 모든 상태 초기화 (테스트/디버그용)
  Future<void> clearAll() async {
    _records.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

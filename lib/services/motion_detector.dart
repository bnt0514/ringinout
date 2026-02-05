import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

/// 가속도계 기반 이동 감지 서비스
/// Activity Recognition 대신 직접 움직임을 감지
class MotionDetector {
  static MotionDetector? _instance;
  static MotionDetector get instance => _instance ??= MotionDetector._();

  MotionDetector._();

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;

  // 콜백
  Function(bool isMoving)? onMovementStateChanged;

  // 상태
  bool _isMoving = false;
  bool get isMoving => _isMoving;

  DateTime? _lastMovementTime;
  DateTime? _movementStartTime;

  // 이동 감지 버퍼 (최근 N초간의 움직임 기록)
  final List<_MotionSample> _motionBuffer = [];

  // ===== 설정값 =====
  // 중력 제거 후 움직임 임계값 (m/s²)
  // 걷기: ~2-4 m/s², 차량: ~0.5-2 m/s², 폰 들기: ~1-3 m/s² (짧게)
  static const double _motionThreshold = 0.8; // 민감하게 설정

  // 이동 판정: N초 동안 M% 이상 움직임 감지되면 "이동 중"
  static const int _movingWindowSeconds = 15; // 15초 윈도우
  static const double _movingRatioThreshold = 0.4; // 40% 이상 움직임

  // 정지 판정: N분 동안 움직임 없으면 "정지"
  static const int _stillTimeoutMinutes = 5; // 5분

  // 샘플링 간격 - ✅ 배터리 최적화: 2초로 증가
  static const int _sampleIntervalMs = 2000; // 2초마다 샘플링 (기존 200ms)

  DateTime? _lastSampleTime;

  /// 모니터링 시작
  Future<void> startMonitoring() async {
    if (_accelerometerSubscription != null) {
      print('📱 MotionDetector 이미 실행 중');
      return;
    }

    print('📱 MotionDetector 시작 (저전력 모드)');

    // ✅ 배터리 최적화: 500ms 샘플링 (기존 100ms)
    // 사용자 가속도 (중력 제거됨) 사용
    _accelerometerSubscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 500),
    ).listen(_onAccelerometerEvent);
  }

  /// 모니터링 중지
  Future<void> stopMonitoring() async {
    await _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _motionBuffer.clear();
    print('📱 MotionDetector 중지');
  }

  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    final now = DateTime.now();

    // 샘플링 간격 체크 (너무 자주 처리하면 배터리 소모)
    if (_lastSampleTime != null &&
        now.difference(_lastSampleTime!).inMilliseconds < _sampleIntervalMs) {
      return;
    }
    _lastSampleTime = now;

    // 가속도 크기 계산 (유클리드 거리)
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // 움직임 여부 판정
    final hasMotion = magnitude > _motionThreshold;

    // 버퍼에 추가
    _motionBuffer.add(_MotionSample(timestamp: now, hasMotion: hasMotion));

    // 오래된 샘플 제거 (윈도우 크기 + 여유)
    final cutoff = now.subtract(Duration(seconds: _movingWindowSeconds + 5));
    _motionBuffer.removeWhere((s) => s.timestamp.isBefore(cutoff));

    // 이동 상태 판정
    _updateMovementState(now);
  }

  void _updateMovementState(DateTime now) {
    // 최근 N초간 움직임 비율 계산
    final windowStart = now.subtract(Duration(seconds: _movingWindowSeconds));
    final recentSamples =
        _motionBuffer.where((s) => s.timestamp.isAfter(windowStart)).toList();

    if (recentSamples.isEmpty) return;

    final motionCount = recentSamples.where((s) => s.hasMotion).length;
    final motionRatio = motionCount / recentSamples.length;

    final wasMoving = _isMoving;

    if (!_isMoving) {
      // 정지 → 이동 판정
      if (motionRatio >= _movingRatioThreshold) {
        _isMoving = true;
        _movementStartTime = now;
        _lastMovementTime = now;
        print(
          '🚶 MotionDetector: 이동 시작 감지! '
          '(${(motionRatio * 100).toStringAsFixed(0)}% 움직임)',
        );
      }
    } else {
      // 이동 중 상태 유지/해제 판정
      if (motionRatio > 0.1) {
        // 10% 이상 움직임 있으면 이동 유지
        _lastMovementTime = now;
      }

      // 5분간 움직임 없으면 정지로 전환
      if (_lastMovementTime != null) {
        final stillDuration = now.difference(_lastMovementTime!);
        if (stillDuration.inMinutes >= _stillTimeoutMinutes) {
          _isMoving = false;
          print(
            '🛑 MotionDetector: 정지 감지 '
            '(${stillDuration.inMinutes}분간 움직임 없음)',
          );
        }
      }
    }

    // 상태 변경 시 콜백 호출
    if (wasMoving != _isMoving) {
      onMovementStateChanged?.call(_isMoving);
    }
  }

  /// 현재 상태 정보 (디버그용)
  Map<String, dynamic> getDebugInfo() {
    final now = DateTime.now();
    final windowStart = now.subtract(Duration(seconds: _movingWindowSeconds));
    final recentSamples =
        _motionBuffer.where((s) => s.timestamp.isAfter(windowStart)).toList();

    final motionCount = recentSamples.where((s) => s.hasMotion).length;
    final motionRatio =
        recentSamples.isEmpty ? 0.0 : motionCount / recentSamples.length;

    return {
      'isMoving': _isMoving,
      'motionRatio': '${(motionRatio * 100).toStringAsFixed(0)}%',
      'sampleCount': recentSamples.length,
      'lastMovement': _lastMovementTime?.toIso8601String(),
      'movementStart': _movementStartTime?.toIso8601String(),
    };
  }
}

class _MotionSample {
  final DateTime timestamp;
  final bool hasMotion;

  _MotionSample({required this.timestamp, required this.hasMotion});
}

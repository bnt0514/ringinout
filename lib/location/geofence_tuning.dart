// lib/location/geofence_tuning.dart
//
// Step B: GeofenceTuning 유틸 - 순수 함수로 작성
// 사용자 반경 R(30~500)에서 H, E, small, big, R_rearm 산정

import 'dart:math';

/// 지오펜스 튜닝 파라미터
class TuningParams {
  /// 사용자가 설정한 기본 반경 (m)
  final double R;

  /// 히스테리시스 버퍼 (INSIDE 재확정용): clamp(round(0.25 * R), 10, 60)
  final double H;

  /// Enter 알림 여유 마진 (옵션): clamp(round(0.15 * R), 5, 40)
  final double E;

  /// 작은 지오펜스 반경 (ARMED→HOT 전환용): clamp(round(R + 80), 150, 350)
  final double smallRadius;

  /// 큰 지오펜스 반경 (IDLE→ARMED 전환용): clamp(round(max(700, small+500)), 700, 1500)
  final double bigRadius;

  /// 재무장 확정 반경 (INSIDE 확정): max(10, R - H)
  final double R_rearm;

  const TuningParams._({
    required this.R,
    required this.H,
    required this.E,
    required this.smallRadius,
    required this.bigRadius,
    required this.R_rearm,
  });

  @override
  String toString() =>
      'TuningParams(R=${R.toInt()}, H=${H.toInt()}, E=${E.toInt()}, '
      'small=${smallRadius.toInt()}, big=${bigRadius.toInt()}, '
      'R_rearm=${R_rearm.toInt()})';

  Map<String, dynamic> toJson() => {
    'R': R,
    'H': H,
    'E': E,
    'smallRadius': smallRadius,
    'bigRadius': bigRadius,
    'R_rearm': R_rearm,
  };
}

/// 사용자 반경 R에서 튜닝 파라미터를 산정한다.
///
/// **순수 함수** - 부작용 없음, 테스트 가능
///
/// ```dart
/// final params = computeTuning(100); // R=100m
/// // H=25, E=15, small=180, big=700, R_rearm=75
/// ```
TuningParams computeTuning(double rMeters) {
  // 반경 범위 제한 (안전)
  final R = rMeters.clamp(10.0, 2000.0);

  // H: 히스테리시스 (Exit→INSIDE 재확정 시 안쪽으로 더 들어와야 함)
  final H = (0.25 * R).roundToDouble().clamp(10.0, 60.0);

  // E: Enter 알림 여유 마진 (Enter Alert를 R+E에서 울리고 싶을 때 사용)
  final E = (0.15 * R).roundToDouble().clamp(5.0, 40.0);

  // small: 작은 지오펜스 (ARMED→HOT 전환 트리거)
  final smallRadius = (R + 80).roundToDouble().clamp(150.0, 350.0);

  // big: 큰 지오펜스 (IDLE→ARMED 전환 트리거)
  final bigRaw = max(700.0, smallRadius + 500);
  final bigRadius = bigRaw.roundToDouble().clamp(700.0, 1500.0);

  // R_rearm: INSIDE 확정(재무장) 반경 = R - H
  // ✅ 하한 25m 적용 (R=30 엣지케이스 방어: GPS accuracy 20m에서도 inside 확정 가능)
  final R_rearm = max(25.0, R - H);

  return TuningParams._(
    R: R,
    H: H,
    E: E,
    smallRadius: smallRadius,
    bigRadius: bigRadius,
    R_rearm: R_rearm,
  );
}

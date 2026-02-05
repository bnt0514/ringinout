import 'dart:async';
import 'dart:math' as math;
import 'package:ringinout/services/hive_helper.dart';
import 'package:flutter/services.dart';

class LocationSimulationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.ringinout/smart_location',
  );

  static Timer? _timer;
  static bool _isRunning = false;
  static int _stepIndex = 0;
  static int _tickInStep = 0;
  static List<_ScenarioStep> _steps = [];
  static double? _currentLat;
  static double? _currentLng;

  static bool get isRunning => _isRunning;

  static Future<void> startScenarioCompanyToSiheung() async {
    await _startSimulation(_buildScenarioCompanyToSiheung());
  }

  static Future<void> startScenarioDriveToSiheungParking() async {
    await _startSimulation(_buildScenarioDriveToSiheungParking());
  }

  static Future<void> startScenarioExitSiheung() async {
    await _startSimulation(_buildScenarioExitSiheung());
  }

  static Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _steps = [];
    _stepIndex = 0;
    _tickInStep = 0;
    await _channel.invokeMethod('stopSimulation');
  }

  static Future<void> _startSimulation(_ScenarioDefinition definition) async {
    if (_isRunning) {
      await stop();
    }

    _currentLat = definition.startLat;
    _currentLng = definition.startLng;
    _steps = definition.steps;
    _stepIndex = 0;
    _tickInStep = 0;

    await _channel.invokeMethod('startSimulation');

    _isRunning = true;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_stepIndex >= _steps.length) {
        await stop();
        return;
      }

      final step = _steps[_stepIndex];
      final totalTicks = step.duration.inSeconds;

      if (totalTicks <= 0) {
        _stepIndex++;
        _tickInStep = 0;
        return;
      }

      final progress = _tickInStep / totalTicks;

      if (step.isMoving && step.endLat != null && step.endLng != null) {
        final lat = _lerp(_currentLat!, step.endLat!, progress);
        final lng = _lerp(_currentLng!, step.endLng!, progress);
        await _sendSimulatedLocation(
          lat,
          lng,
          accuracy: step.accuracyM,
          isMoving: true,
        );
      } else {
        await _sendSimulatedLocation(
          _currentLat!,
          _currentLng!,
          accuracy: step.accuracyM,
          isMoving: false,
        );
      }

      _tickInStep++;

      if (_tickInStep >= totalTicks) {
        if (step.isMoving && step.endLat != null && step.endLng != null) {
          _currentLat = step.endLat;
          _currentLng = step.endLng;
        }
        _stepIndex++;
        _tickInStep = 0;
      }
    });
  }

  static Future<void> _sendSimulatedLocation(
    double lat,
    double lng, {
    required double accuracy,
    required bool isMoving,
  }) async {
    await _channel.invokeMethod('simulateLocation', {
      'latitude': lat,
      'longitude': lng,
      'accuracy': accuracy,
    });
    await _channel.invokeMethod('simulateActivity', {'isMoving': isMoving});
  }

  static _ScenarioDefinition _buildScenarioCompanyToSiheung() {
    final company = _findPlaceByName('회사');
    final siheung = _findPlaceByName('시흥집');

    final start = _fallbackStart(company);
    final end = _fallbackEnd(start, siheung, 2000, 90);

    final steps = <_ScenarioStep>[
      _ScenarioStep.stay(const Duration(seconds: 60)),
      _ScenarioStep.moveByDistance(
        fromLat: start.lat,
        fromLng: start.lng,
        distanceMeters: 80,
        bearingDegrees: 180,
        speedMps: 1.2,
        accuracyM: 15,
      ),
      _ScenarioStep.stay(const Duration(seconds: 20)),
      _ScenarioStep.moveTo(
        fromLat: start.lat,
        fromLng: start.lng,
        toLat: end.lat,
        toLng: end.lng,
        duration: const Duration(seconds: 170),
        accuracyM: 30,
      ),
    ];

    return _ScenarioDefinition(
      startLat: start.lat,
      startLng: start.lng,
      steps: steps,
    );
  }

  static _ScenarioDefinition _buildScenarioDriveToSiheungParking() {
    final company = _findPlaceByName('회사');
    final siheung = _findPlaceByName('시흥집');

    final start = _fallbackStart(company);
    final home = _fallbackEnd(start, siheung, 2000, 90);
    final parking = _offset(home.lat, home.lng, 40, 270); // 40m 밖

    final steps = <_ScenarioStep>[
      _ScenarioStep.moveTo(
        fromLat: start.lat,
        fromLng: start.lng,
        toLat: parking.lat,
        toLng: parking.lng,
        duration: const Duration(minutes: 10),
        accuracyM: 30,
      ),
      _ScenarioStep.stay(const Duration(seconds: 20)),
      _ScenarioStep.moveTo(
        fromLat: parking.lat,
        fromLng: parking.lng,
        toLat: home.lat,
        toLng: home.lng,
        duration: const Duration(seconds: 50),
        accuracyM: 15,
      ),
      _ScenarioStep.stay(const Duration(seconds: 60)),
    ];

    return _ScenarioDefinition(
      startLat: start.lat,
      startLng: start.lng,
      steps: steps,
    );
  }

  static _ScenarioDefinition _buildScenarioExitSiheung() {
    final siheung = _findPlaceByName('시흥집');
    final start = _fallbackStart(siheung);
    final outside = _offset(start.lat, start.lng, 60, 0);
    final driveOut = _offset(outside.lat, outside.lng, 300, 45);

    final steps = <_ScenarioStep>[
      _ScenarioStep.stay(const Duration(seconds: 60)),
      _ScenarioStep.moveByDistance(
        fromLat: start.lat,
        fromLng: start.lng,
        distanceMeters: 20,
        bearingDegrees: 90,
        speedMps: 1.2,
        accuracyM: 15,
      ),
      _ScenarioStep.stay(const Duration(seconds: 10)),
      _ScenarioStep.moveTo(
        fromLat: start.lat,
        fromLng: start.lng,
        toLat: outside.lat,
        toLng: outside.lng,
        duration: const Duration(seconds: 40),
        accuracyM: 15,
      ),
      _ScenarioStep.stay(const Duration(seconds: 15)),
      _ScenarioStep.moveTo(
        fromLat: outside.lat,
        fromLng: outside.lng,
        toLat: driveOut.lat,
        toLng: driveOut.lng,
        duration: const Duration(seconds: 30),
        accuracyM: 30,
      ),
    ];

    return _ScenarioDefinition(
      startLat: start.lat,
      startLng: start.lng,
      steps: steps,
    );
  }

  static _LatLng _fallbackStart(Map<String, dynamic>? place) {
    if (place != null) {
      final lat = (place['latitude'] ?? place['lat']) as double?;
      final lng = (place['longitude'] ?? place['lng']) as double?;
      if (lat != null && lng != null) {
        return _LatLng(lat, lng);
      }
    }
    return _LatLng(37.4403683, 126.7740191);
  }

  static _LatLng _fallbackEnd(
    _LatLng start,
    Map<String, dynamic>? place,
    double fallbackDistanceMeters,
    double fallbackBearing,
  ) {
    if (place != null) {
      final lat = (place['latitude'] ?? place['lat']) as double?;
      final lng = (place['longitude'] ?? place['lng']) as double?;
      if (lat != null && lng != null) {
        return _LatLng(lat, lng);
      }
    }
    return _offset(
      start.lat,
      start.lng,
      fallbackDistanceMeters,
      fallbackBearing,
    );
  }

  static Map<String, dynamic>? _findPlaceByName(String name) {
    final places = HiveHelper.getSavedLocations();
    try {
      return places.firstWhere(
        (p) => (p['name'] as String?)?.contains(name) == true,
      );
    } catch (_) {
      return null;
    }
  }

  static _LatLng _offset(
    double lat,
    double lng,
    double meters,
    double bearingDeg,
  ) {
    final rad = bearingDeg * math.pi / 180.0;
    final deltaNorth = meters * math.cos(rad);
    final deltaEast = meters * math.sin(rad);

    final latOffset = deltaNorth / 111320.0;
    final lngOffset = deltaEast / (111320.0 * math.cos(lat * math.pi / 180.0));

    return _LatLng(lat + latOffset, lng + lngOffset);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

class _ScenarioDefinition {
  final double startLat;
  final double startLng;
  final List<_ScenarioStep> steps;

  _ScenarioDefinition({
    required this.startLat,
    required this.startLng,
    required this.steps,
  });
}

class _ScenarioStep {
  final Duration duration;
  final bool isMoving;
  final double? endLat;
  final double? endLng;
  final double accuracyM;

  _ScenarioStep._({
    required this.duration,
    required this.isMoving,
    this.endLat,
    this.endLng,
    required this.accuracyM,
  });

  factory _ScenarioStep.stay(Duration duration) {
    return _ScenarioStep._(duration: duration, isMoving: false, accuracyM: 20);
  }

  factory _ScenarioStep.moveTo({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required Duration duration,
    required double accuracyM,
  }) {
    return _ScenarioStep._(
      duration: duration,
      isMoving: true,
      endLat: toLat,
      endLng: toLng,
      accuracyM: accuracyM,
    );
  }

  factory _ScenarioStep.moveByDistance({
    required double fromLat,
    required double fromLng,
    required double distanceMeters,
    required double bearingDegrees,
    required double speedMps,
    required double accuracyM,
  }) {
    final durationSeconds = (distanceMeters / speedMps).round().clamp(1, 3600);
    final end = LocationSimulationService._offset(
      fromLat,
      fromLng,
      distanceMeters,
      bearingDegrees,
    );
    return _ScenarioStep._(
      duration: Duration(seconds: durationSeconds),
      isMoving: true,
      endLat: end.lat,
      endLng: end.lng,
      accuracyM: accuracyM,
    );
  }
}

class _LatLng {
  final double lat;
  final double lng;

  const _LatLng(this.lat, this.lng);
}

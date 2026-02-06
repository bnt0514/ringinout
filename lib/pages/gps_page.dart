import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/app_log_buffer.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  Position? _currentPosition;
  DateTime? _lastUpdated;
  String? _error;
  bool _isUpdating = false;
  StreamSubscription<Position>? _positionSub;

  // 네이티브 SmartLocationService 상태
  String _nativeState = 'UNKNOWN';
  int _alarmCount = 0;
  String? _targetPlace;
  Map<String, bool> _insideStatus = {};

  @override
  void initState() {
    super.initState();
    _startListeningToLocation();
    _refreshLocation();
    _refreshNativeStatus();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  /// 네이티브 상태 새로고침
  Future<void> _refreshNativeStatus() async {
    try {
      final state = await SmartLocationService.getCurrentState();
      final count = await SmartLocationService.getAlarmCount();
      final target = await SmartLocationService.getTargetPlace();
      final inside = await SmartLocationService.getInsideStatus();

      setState(() {
        _nativeState = state;
        _alarmCount = count;
        _targetPlace = target;
        _insideStatus = inside;
      });
    } catch (e) {
      print('❌ 네이티브 상태 조회 실패: $e');
    }
  }

  Future<void> _sendErrorReport() async {
    final now = DateTime.now().toIso8601String();
    final activeAlarms =
        HiveHelper.alarmBox.values
            .where((alarm) => alarm is Map && alarm['enabled'] == true)
            .map((alarm) => Map<String, dynamic>.from(alarm as Map))
            .toList();
    final places = HiveHelper.getSavedLocations();

    final payload = {
      'timestamp': now,
      'state': _nativeState,
      'alarmCount': _alarmCount,
      'targetPlace': _targetPlace,
      'insideStatus': _insideStatus,
      'currentPosition':
          _currentPosition == null
              ? null
              : {
                'lat': _currentPosition!.latitude,
                'lng': _currentPosition!.longitude,
                'accuracy': _currentPosition!.accuracy,
                'time': _currentPosition!.timestamp?.toIso8601String(),
              },
      'activeAlarms': activeAlarms,
      'savedPlacesCount': places.length,
      'recentLogs': AppLogBuffer.snapshot(window: const Duration(minutes: 30)),
    };

    await SmartLocationService.sendErrorReport(payload);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('에러 리포트가 전송되었습니다.')));
  }

  Future<void> _startListeningToLocation() async {
    final hasPermission = await _ensurePermission();
    if (!hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: 50,
    );

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      setState(() {
        _currentPosition = position;
        _lastUpdated = DateTime.now();
        _error = null;
      });
    });
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _error = '위치 권한이 필요합니다.';
      });
      return false;
    }

    return true;
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isUpdating = true;
      _error = null;
    });

    final hasPermission = await _ensurePermission();
    if (!hasPermission) {
      setState(() {
        _isUpdating = false;
      });
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      setState(() {
        _currentPosition = position;
        _lastUpdated = DateTime.now();
        _isUpdating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'GPS 업데이트 실패: $e';
        _isUpdating = false;
      });
    }
  }

  List<Map<String, dynamic>> _getActiveAlarmsWithDistance() {
    if (_currentPosition == null) return [];

    final activeAlarms =
        HiveHelper.alarmBox.values
            .where((alarm) => alarm['enabled'] == true)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    if (activeAlarms.isEmpty) return [];

    final places = HiveHelper.getSavedLocations();

    return activeAlarms.map((alarm) {
      final placeName =
          (alarm['place'] as String?) ??
          (alarm['locationName'] as String?) ??
          '';
      final place = places.firstWhere(
        (p) => p['name'] == placeName,
        orElse: () => <String, dynamic>{},
      );

      if (place.isEmpty) {
        return {'alarm': alarm, 'place': null, 'distance': null};
      }

      final lat = (place['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (place['lng'] as num?)?.toDouble() ?? 0.0;
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        lat,
        lng,
      );

      return {'alarm': alarm, 'place': place, 'distance': distance};
    }).toList();
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(2)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final alarmsWithDistance = _getActiveAlarmsWithDistance();

    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('GPS'),
                actions: [
                  IconButton(
                    onPressed: _isUpdating ? null : _refreshLocation,
                    icon: const Icon(Icons.my_location),
                    tooltip: 'GPS 업데이트',
                  ),
                ],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _refreshLocation,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLocationCard(),
            const SizedBox(height: 16),
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            _buildActiveAlarmCard(alarmsWithDistance),
            const SizedBox(height: 16),
            _buildGeofenceStateCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : _refreshLocation,
        icon: const Icon(Icons.gps_fixed),
        label: const Text('GPS 업데이트'),
      ),
    );
  }

  /// 서비스 상태 카드 (네이티브 SmartLocationService)
  Widget _buildServiceStatusCard() {
    final isRunning = SmartLocationService.isRunning;

    // 상태별 색상
    Color stateColor;
    String stateEmoji;
    switch (_nativeState) {
      case 'IDLE':
        stateColor = Colors.green;
        stateEmoji = '💤';
        break;
      case 'ARMED':
        stateColor = Colors.orange;
        stateEmoji = '⚡';
        break;
      case 'HOT':
        stateColor = Colors.red;
        stateEmoji = '🔥';
        break;
      default:
        stateColor = Colors.grey;
        stateEmoji = '❓';
    }

    return Card(
      elevation: 2,
      color: isRunning ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRunning ? Icons.check_circle : Icons.error,
                  color: isRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  '스마트 위치 서비스 (네이티브)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 모드 표시
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stateColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: stateColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(stateEmoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    _nativeState,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stateColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text('활성 알람: $_alarmCount개'),
            if (_targetPlace != null)
              Text(
                '타겟 장소: $_targetPlace',
                style: TextStyle(color: Colors.orange.shade700),
              ),
            const SizedBox(height: 8),
            // 모드 설명
            Text(
              _getModeDescription(_nativeState),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            // 새로고침 버튼
            TextButton.icon(
              onPressed: _refreshNativeStatus,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('상태 새로고침'),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _sendErrorReport,
                icon: const Icon(Icons.bug_report),
                label: const Text('에러 리포트'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeDescription(String state) {
    switch (state) {
      case 'IDLE':
        return '💤 IDLE: Activity Transition + 큰 지오펜스 (배터리 ~0%)';
      case 'ARMED':
        return '⚡ ARMED: 작은 지오펜스 + 저전력 위치 (배터리 ~1%)';
      case 'HOT':
        return '🔥 HOT: 고정밀 GPS 버스트 (30~60초)';
      default:
        return '상태 알 수 없음';
    }
  }

  /// 지오펜스 상태 카드 (네이티브 SmartLocationManager)
  Widget _buildGeofenceStateCard() {
    final places = HiveHelper.getSavedLocations();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '장소별 상태 (네이티브)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_insideStatus.isEmpty && places.isEmpty)
              const Text('저장된 장소가 없습니다.')
            else if (_insideStatus.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 네이티브 상태 정보 없음',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: _refreshNativeStatus,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('상태 새로고침'),
                  ),
                ],
              )
            else
              ...places.map((place) {
                final placeName = place['name'] as String? ?? '';
                final isInside = _insideStatus[placeName];

                // 거리 정보도 함께 표시
                double? distance;
                if (_currentPosition != null) {
                  final lat = (place['lat'] as num?)?.toDouble() ?? 0.0;
                  final lng = (place['lng'] as num?)?.toDouble() ?? 0.0;
                  distance = Geolocator.distanceBetween(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    lat,
                    lng,
                  );
                }

                final radius = (place['radius'] as num?)?.toDouble() ?? 100;
                final isActuallyInside = distance != null && distance <= radius;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          isInside == true
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            isInside == true
                                ? Colors.green.shade300
                                : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isInside == true
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color:
                                  isInside == true ? Colors.green : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                placeName.isNotEmpty ? placeName : '(이름 없음)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'insideStatus: ${isInside ?? "추적 안 됨"}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (distance != null)
                          Text(
                            '거리: ${_formatDistance(distance)} / 반경: ${radius.toInt()}m '
                            '${isActuallyInside ? "📍 내부" : "📌 외부"}',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isActuallyInside
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                            ),
                          ),
                        // 상태 불일치 경고
                        if (isInside != null && isActuallyInside != isInside)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '⚠️ 상태 불일치! GPS=${isActuallyInside ? "내부" : "외부"}, 네이티브=${isInside ? "내부" : "외부"}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '현재 위치',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent))
            else if (_currentPosition == null)
              const Text('위치 정보 없음')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('위도: ${_currentPosition!.latitude.toStringAsFixed(6)}'),
                  Text('경도: ${_currentPosition!.longitude.toStringAsFixed(6)}'),
                  if (_lastUpdated != null)
                    Text('업데이트: ${_formatTime(_lastUpdated!)}'),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAlarmCard(List<Map<String, dynamic>> data) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '활성화된 알람 거리',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.isEmpty)
              const Text('활성화된 알람이 없거나 위치 정보가 없습니다.')
            else
              ...data.map((item) {
                final alarm = item['alarm'] as Map<String, dynamic>;
                final place = item['place'] as Map<String, dynamic>?;
                final distance = item['distance'] as double?;

                final alarmName = alarm['name'] ?? '알람';
                final placeName = place?['name'] ?? alarm['place'] ?? '장소 미확인';
                final radius = (place?['radius'] as num?)?.toDouble();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$alarmName (${placeName})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (distance != null)
                        Text(
                          '거리: ${_formatDistance(distance)}'
                          '${radius != null ? ' / 반경: ${radius.toInt()}m' : ''}',
                        )
                      else
                        const Text('거리 정보를 계산할 수 없습니다.'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

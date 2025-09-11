// location_monitor_service.dart

// Flutter/Dart imports
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' hide LocationAccuracy, ActivityType;
import 'package:geofence_service/geofence_service.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// Project imports
import 'package:ringinout/config/constants.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/services/hive_helper.dart';

typedef GeofenceStatusChangeListener =
    Future<void> Function(
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus geofenceStatus,
      Location location,
    );

@pragma('vm:entry-point')
class LocationMonitorService {
  // Singleton pattern
  static final LocationMonitorService instance =
      LocationMonitorService._internal();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  factory LocationMonitorService() => instance;
  LocationMonitorService._internal();

  // 상수 및 채널 정의
  static const String _audioChannelName = 'com.example.ringinout/audio';
  static const String _navigationChannelName = 'ringinout_channel';

  // 채널 인스턴스
  final _audioChannel = const MethodChannel(_audioChannelName);
  final _navigationChannel = const MethodChannel(_navigationChannelName);

  // 상태 변수
  bool isNativeReady = false;
  bool _isRunning = false;
  DateTime? _lastGeofenceEvent;

  GeofenceStatusChangeListener? _geofenceStatusChangedListener;
  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 10000, // ms 단위, 10초
    accuracy: 50, // 미터 단위, 100m (int만 허용)
    loiteringDelayMs: 10000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: true,
    allowMockLocations: true,
    printDevLog: false,
    // androidSettings, iosSettings, notificationOptions 등은 없음!
  );

  // 알람 사운드 관련 메서드
  Future<void> _playAlarmSound(String soundPath) async {
    try {
      await _audioChannel.invokeMethod('playRingtoneLoud');
      print('🔔 알람 재생 시작');
    } catch (e) {
      print('🔕 알람 재생 실패: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _audioChannel.invokeMethod('stopRingtone');
      print('🔕 알람 정지');
    } catch (e) {
      print('❌ 알람 정지 실패: $e');
    }
  }

  // 위치 관련 메서드
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      print('⚠️ 위치 획득 실패: $e');
      return null;
    }
  }

  // 알람 조건 검사
  @pragma('vm:entry-point')
  bool checkAlarmCondition(Map<String, dynamic> alarm, String triggerType) {
    // 기본 활성화 체크
    if (alarm['enabled'] != true) return false;

    // 진입/이탈 트리거 체크
    if (triggerType == 'enter' && alarm['onEnter'] != true) return false;
    if (triggerType == 'exit' && alarm['onExit'] != true) return false;

    // 요일 체크
    if (!_checkDayCondition(alarm)) return false;

    // 시간 체크
    return _checkTimeCondition(alarm);
  }

  // 요일 조건 체크
  @pragma('vm:entry-point')
  bool _checkDayCondition(Map<String, dynamic> alarm) {
    final List<String>? selectedDays = (alarm['days'] as List?)?.cast<String>();
    if (selectedDays?.isEmpty ?? true) return true;

    final now = DateTime.now();
    final weekdayStr = ['일', '월', '화', '수', '목', '금', '토'][now.weekday % 7];
    return selectedDays!.contains(weekdayStr);
  }

  // 시간 조건 체크
  @pragma('vm:entry-point')
  bool _checkTimeCondition(Map<String, dynamic> alarm) {
    final now = DateTime.now();
    final targetHour = alarm['hour'] ?? 0;
    final targetMinute = alarm['minute'] ?? 0;

    return now.hour > targetHour ||
        (now.hour == targetHour && now.minute >= targetMinute);
  }

  // 지오펜스 모니터링 관련 메서드
  @pragma('vm:entry-point')
  void prepareMonitoringOnly(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) {
    _geofenceStatusChangedListener = (
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus status,
      Location location,
    ) async {
      await _handleGeofenceEvent(geofence, status, onTrigger);
    };

    _geofenceService.addGeofenceStatusChangeListener(
      _geofenceStatusChangedListener!,
    );
  }

  // 지오펜스 이벤트 처리
  @pragma('vm:entry-point')
  Future<void> _handleGeofenceEvent(
    Geofence geofence,
    GeofenceStatus status,
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    // ✅ 마지막 이벤트 시간 업데이트
    _lastGeofenceEvent = DateTime.now();
    print('📍 지오펜스 이벤트: ${geofence.id} / 상태: $status');

    try {
      final alarms =
          HiveHelper.alarmBox.values
              .where((alarm) => alarm['place'] == geofence.id)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      print('🔍 해당 장소 알람 개수: ${alarms.length}'); // ✅ 로그 추가

      for (int i = 0; i < alarms.length; i++) {
        final alarmData = alarms[i];
        final trigger = alarmData['trigger'] ?? 'entry';

        print('🔄 알람 $i 확인: ${alarmData['name']} (트리거: $trigger)'); // ✅ 로그 추가

        if (_shouldTriggerAlarm(trigger, status)) {
          print('🔔 알람 조건 만족: ${alarmData['name']} (트리거: $trigger)');

          try {
            await _triggerAlarm(alarmData, trigger, onTrigger);
            print(
              '✅ 알람 ${i + 1}/${alarms.length} 트리거 완료: ${alarmData['name']}',
            ); // ✅ 로그 추가
          } catch (e) {
            print('❌ 알람 트리거 실패: ${alarmData['name']} - $e'); // ✅ 에러 로그
          }
        } else {
          print(
            '⏭️ 알람 조건 불만족: ${alarmData['name']} (트리거: $trigger, 상태: $status)',
          );
        }
      }
    } catch (e) {
      print('❌ 지오펜스 이벤트 처리 실패: $e');
    }
  }

  // 알람 트리거 조건 체크
  @pragma('vm:entry-point')
  bool _shouldTriggerAlarm(String trigger, GeofenceStatus status) {
    return (trigger == 'entry' && status == GeofenceStatus.ENTER) ||
        (trigger == 'exit' && status == GeofenceStatus.EXIT);
  }

  // 알람 실행
  @pragma('vm:entry-point')
  Future<void> _triggerAlarm(
    Map<String, dynamic> alarmData,
    String trigger,
    void Function(String, Map<String, dynamic>) onTrigger,
  ) async {
    print('✅ 알람 트리거: ${alarmData['name']}');

    try {
      // 트리거 카운트 증가 (타입 안전하게 처리)
      print('🔢 트리거 카운트 업데이트 시도');

      // 기존 값을 안전하게 int로 변환
      final currentCount = alarmData['triggerCount'];
      int triggerCount = 0;

      if (currentCount is int) {
        triggerCount = currentCount;
      } else if (currentCount is String) {
        triggerCount = int.tryParse(currentCount) ?? 0;
      } else {
        triggerCount = 0;
      }

      alarmData['triggerCount'] = triggerCount + 1;
      await HiveHelper.updateLocationAlarm(alarmData['id'], alarmData);
      print('✅ 트리거 카운트 업데이트 완료: ${alarmData['triggerCount']}');
    } catch (e) {
      print('❌ 트리거 카운트 업데이트 실패: $e');
    }

    try {
      // 1. 알람 소리 재생
      final soundPath =
          alarmData['sound'] ?? 'assets/sounds/thoughtfulringtone.mp3';
      print('🔊 알람 소리 재생 시도: $soundPath'); // ✅ 로그 추가
      await _playAlarmSound(soundPath);
      print('✅ 알람 소리 재생 완료'); // ✅ 로그 추가
    } catch (e) {
      print('❌ 알람 소리 재생 실패: $e'); // ✅ 에러 로그
    }

    try {
      // 2. 화면 전환 (앱 상태에 따라)
      print('📱 화면 전환 시도'); // ✅ 로그 추가
      await _handleAlarmDisplay(alarmData);
      print('✅ 화면 전환 완료'); // ✅ 로그 추가
    } catch (e) {
      print('❌ 화면 전환 실패: $e'); // ✅ 에러 로그
    }

    try {
      // 3. 콜백 호출
      print('📞 onTrigger 콜백 호출'); // ✅ 로그 추가
      onTrigger(trigger, alarmData);
      print('✅ onTrigger 콜백 완료'); // ✅ 로그 추가
    } catch (e) {
      print('❌ onTrigger 콜백 실패: $e'); // ✅ 에러 로그
    }

    print('🎯 _triggerAlarm 메서드 완료: ${alarmData['name']}'); // ✅ 최종 로그
  }

  // 화면 전환 처리 (새로 추가)
  @pragma('vm:entry-point')
  Future<void> _handleAlarmDisplay(Map<String, dynamic> alarmData) async {
    try {
      // Navigator가 있으면 포그라운드, 없으면 백그라운드로 판단
      if (navigatorKey.currentState != null) {
        // 포그라운드: Flutter 화면
        print('📱 포그라운드 - Flutter 알람 화면 표시');
        _showFullScreenAlarmFlutter(alarmData);
      } else {
        // 백그라운드: Native 전체화면 알람
        print('📱 백그라운드 - Native 전체화면 알람 시도');
        await _showNativeFullScreenAlarm(alarmData);
      }
    } catch (e) {
      print('❌ 화면 전환 실패: $e');
      // 실패 시 Native로 대체
      await _showNativeFullScreenAlarm(alarmData);
    }
  }

  // Native 전체화면 알람 (새로 추가)
  @pragma('vm:entry-point')
  Future<void> _showNativeFullScreenAlarm(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      await _navigationChannel.invokeMethod('showFullScreenAlarm', {
        'title': alarmData['name'] ?? 'Ringinout 알람',
        'sound': alarmData['sound'] ?? 'assets/sounds/1.mp3',
        'alarmData': alarmData,
      });
      print('✅ Native 전체화면 알람 실행 성공');
    } catch (e) {
      print('❌ Native 알람 실행 실패: $e');
      // Native 실패 시 Flutter로 대체
      _showFullScreenAlarmFlutter(alarmData);
    }
  }

  // 기존 Flutter 화면 표시 (로그 추가)
  @pragma('vm:entry-point')
  void _showFullScreenAlarmFlutter(Map<String, dynamic> alarmData) {
    print('📱 Flutter 전체화면 알람 표시 시도: ${alarmData['name']}'); // ✅ 로그 추가
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder:
            (_) => FullScreenAlarmPage(
              alarmTitle: alarmData['name'] ?? Defaults.alarmTitle,
              soundPath: alarmData['sound'] ?? AssetPaths.defaultAlarmSound,
              alarmData: alarmData,
              onDismiss: _stopAlarmSound,
            ),
      ),
    );
  }

  // 활성 알람 가져오기
  @pragma('vm:entry-point')
  Future<List<Map<String, dynamic>>> _getActiveAlarms() async {
    try {
      // ✅ 1단계: HiveHelper 초기화 상태 먼저 확인
      if (!HiveHelper.isInitialized) {
        print('📦 HiveHelper가 초기화되지 않음, 초기화 시도');
        await HiveHelper.init();
        await Future.delayed(const Duration(milliseconds: 500)); // 안전성을 위한 대기
      }

      // ✅ 2단계: HiveHelper가 초기화된 경우 HiveHelper 사용
      if (HiveHelper.isInitialized) {
        try {
          final alarms = HiveHelper.getLocationAlarms();
          final activeAlarms =
              alarms.where((alarm) => alarm['enabled'] == true).toList();

          print(
            '📋 전체 알람 개수: ${alarms.length}, 활성화된 알람 개수: ${activeAlarms.length}',
          );

          // 각 알람 정보 출력
          for (var alarm in activeAlarms) {
            print('🔔 활성 알람: ${alarm['name']} - ${alarm['trigger']}');
          }

          return activeAlarms;
        } catch (e) {
          print('⚠️ HiveHelper 접근 실패, 직접 Hive 접근 시도: $e');
        }
      }

      // ✅ 3단계: HiveHelper 실패 시에만 직접 Hive 접근
      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        print('📦 알람 박스가 닫혀있음, 재초기화 시도');

        // ✅ 경로 확인 및 설정
        try {
          final directory = await getApplicationDocumentsDirectory();
          final uniquePath = '${directory.path}/ringinout_unique_v3';

          // 디렉토리 존재 확인
          final hiveDir = Directory(uniquePath);
          if (!await hiveDir.exists()) {
            await hiveDir.create(recursive: true);
            print('📁 Hive 디렉토리 생성: $uniquePath');
          }

          // Hive 재초기화 (안전한 방식)
          try {
            Hive.init(uniquePath);
            print('📦 Hive 경로 재설정: $uniquePath');
          } catch (e) {
            print('⚠️ Hive 이미 초기화됨, 스킵: $e');
          }

          await Hive.openBox('locationAlarms_v2');
          print('✅ 알람 박스 직접 초기화 완료');
        } catch (e) {
          print('❌ Hive 직접 초기화 실패: $e');
          await Future.delayed(const Duration(seconds: 1)); // 안전성을 위한 대기
        }
      }

      // ✅ 4단계: 박스가 열린 경우 직접 접근
      if (Hive.isBoxOpen('locationAlarms_v2')) {
        final box = Hive.box('locationAlarms_v2');
        final alarms = box.values.toList();

        List<Map<String, dynamic>> activeAlarms = [];
        for (var alarm in alarms) {
          if (alarm is Map && alarm['enabled'] == true) {
            // Map<dynamic, dynamic>을 Map<String, dynamic>으로 안전하게 변환
            final convertedAlarm = Map<String, dynamic>.from(alarm);
            activeAlarms.add(convertedAlarm);
          }
        }

        print(
          '📋 직접 접근 - 전체 알람 개수: ${alarms.length}, 활성화된 알람 개수: ${activeAlarms.length}',
        );

        // 각 알람 정보 출력
        for (var alarm in activeAlarms) {
          print('🔔 활성 알람: ${alarm['name']} - ${alarm['trigger']}');
        }

        return activeAlarms;
      } else {
        print('⚠️ 알람 박스 초기화 실패');
        return [];
      }
    } catch (e) {
      print('⚠️ 알람 목록 가져오기 실패: $e');

      // ✅ 5단계: 실패 시 최후의 재시도 (HiveHelper 우선)
      try {
        print('🔄 최후의 재시도 - HiveHelper 사용');

        // HiveHelper 재초기화 시도
        if (!HiveHelper.isInitialized) {
          await HiveHelper.init();
          await Future.delayed(const Duration(seconds: 1));
        }

        if (HiveHelper.isInitialized) {
          final alarms = HiveHelper.getLocationAlarms();
          final activeAlarms =
              alarms.where((alarm) => alarm['enabled'] == true).toList();
          print('✅ HiveHelper 재시도 성공: ${activeAlarms.length}개 알람');
          return activeAlarms;
        } else {
          print('❌ HiveHelper 재시도도 실패');
          return [];
        }
      } catch (retryError) {
        print('❌ 최후의 재시도도 실패: $retryError');
        return [];
      }
    }
  }

  // 서비스 시작 (알람 기반으로 최적화)
  Future<void> startServiceIfSafe() async {
    try {
      // 1. 활성 알람 확인
      final activeAlarms = await _getActiveAlarms();

      if (activeAlarms.isEmpty) {
        print('📭 활성화된 알람이 없어 지오펜스 서비스를 시작하지 않음');
        await _stopGeofenceService(); // 기존 서비스 중단
        return;
      }

      print('🔔 활성 알람 ${activeAlarms.length}개 발견 - 지오펜스 서비스 시작');

      // 2. 알람이 있는 장소만 추출
      final alarmedPlaces = _extractAlarmedPlaces(activeAlarms);
      print('📍 지오펜스 필요한 장소: ${alarmedPlaces.map((p) => p['name']).toList()}');

      // 3. 해당 장소들만 지오펜스 생성
      final geofences = await _createGeofencesForPlaces(alarmedPlaces);

      if (geofences.isEmpty) {
        print('⚠️ 생성할 지오펜스가 없음');
        return;
      }

      // 4. 지오펜스 서비스 시작
      await _startGeofenceService(geofences);
      print('🚀 지오펜스 감지 시작 완료 - ${geofences.length}개 장소 모니터링');
    } catch (e) {
      print('❌ 지오펜스 서비스 시작 실패: $e');
    }
  }

  // 백그라운드 모니터링 시작
  @pragma('vm:entry-point')
  Future<void> startBackgroundMonitoring(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    try {
      print('🌙 백그라운드 지오펜스 모니터링 시작');

      _isRunning = true; // ✅ 상태 업데이트

      // 기존 startServiceIfSafe와 유사하지만 백그라운드용 콜백 사용
      final activeAlarms = await _getActiveAlarms();

      if (activeAlarms.isEmpty) {
        print('📭 백그라운드: 활성화된 알람이 없음');
        return;
      }

      print('🔔 백그라운드 활성 알람 ${activeAlarms.length}개 발견');

      final alarmedPlaces = _extractAlarmedPlaces(activeAlarms);
      print(
        '📍 백그라운드 지오펜스 필요한 장소: ${alarmedPlaces.map((p) => p['name']).toList()}',
      );

      final geofences = await _createGeofencesForPlaces(alarmedPlaces);

      if (geofences.isEmpty) {
        print('⚠️ 백그라운드: 생성할 지오펜스가 없음');
        return;
      }

      // 백그라운드용 지오펜스 시작 (기존 메서드 재활용)
      prepareMonitoringOnly(onTrigger); // 기존 메서드 사용

      // 지오펜스 등록
      for (final geofence in geofences) {
        try {
          _geofenceService.addGeofence(geofence);
          print('✅ 백그라운드 지오펜스 등록: ${geofence.id}');
        } catch (e) {
          print('⚠️ 백그라운드 지오펜스 등록 실패: ${geofence.id} - $e');
          // ACTIVITY_NOT_ATTACHED 오류는 백그라운드에서 정상
          if (!e.toString().contains('ACTIVITY_NOT_ATTACHED')) {
            print('❌ 심각한 오류: $e');
          }
        }
      }

      print('🚀 백그라운드 지오펜스 서비스 시작 완료');
    } catch (e) {
      print('❌ 백그라운드 지오펜스 서비스 시작 실패: $e');
    }
  }

  // 알람이 있는 장소만 추출
  @pragma('vm:entry-point')
  List<Map<String, dynamic>> _extractAlarmedPlaces(
    List<Map<String, dynamic>> alarms,
  ) {
    final Set<String> alarmPlaceNames =
        alarms
            .where(
              (alarm) => alarm['enabled'] == true && alarm['place'] != null,
            )
            .map((alarm) => alarm['place'] as String)
            .toSet();

    print('🎯 알람이 설정된 장소들: $alarmPlaceNames');

    // 해당 장소 정보만 가져오기
    final allPlaces = HiveHelper.getSavedLocations();
    final alarmedPlaces =
        allPlaces
            .where((place) => alarmPlaceNames.contains(place['name']))
            .toList();

    print('📊 알람 장소 통계:');
    print('  - 전체 등록된 장소: ${allPlaces.length}개');
    print('  - 알람이 있는 장소: ${alarmedPlaces.length}개');
    print('  - GPS 모니터링 절약: ${allPlaces.length - alarmedPlaces.length}개 장소');

    return alarmedPlaces;
  }

  // 특정 장소들만 지오펜스 생성
  @pragma('vm:entry-point')
  Future<List<Geofence>> _createGeofencesForPlaces(
    List<Map<String, dynamic>> places,
  ) async {
    final geofences = <Geofence>[];

    for (var place in places) {
      try {
        final lat = (place['lat'] ?? 0.0).toDouble();
        final lng = (place['lng'] ?? 0.0).toDouble();
        final radius = (place['radius'] ?? 100).toDouble();
        final name = place['name'] ?? 'Unknown';

        final geofence = Geofence(
          id: name,
          latitude: lat,
          longitude: lng,
          radius: [GeofenceRadius(id: 'radius_$name', length: radius)],
        );

        geofences.add(geofence);
        print('✅ 지오펜스 생성: $name (${lat}, ${lng}, ${radius}m)');
      } catch (e) {
        print('❌ 지오펜스 생성 실패: ${place['name']} - $e');
      }
    }

    return geofences;
  }

  // 지오펜스 서비스 정리
  @pragma('vm:entry-point')
  Future<void> _stopGeofenceService() async {
    try {
      await _geofenceService.stop();
      print('🛑 지오펜스 서비스 중단 완료');
    } catch (e) {
      print('⚠️ 지오펜스 서비스 중단 실패: $e');
    }
  }

  // 지오펜스 서비스 시작
  @pragma('vm:entry-point')
  Future<void> _startGeofenceService(List<Geofence> geofences) async {
    try {
      await _geofenceService.start(geofences).catchError((e) {
        // ✅ fence. 제거
        print('❌ 지오펜스 시작 실패: $e');
        // 백그라운드에서는 Activity 없어서 실패할 수 있음 - 무시
        if (e.toString().contains('ACTIVITY_NOT_ATTACHED')) {
          print('ℹ️ 백그라운드 실행으로 인한 실패 - 정상적인 상황');
          return;
        }
        throw e;
      });
    } catch (e) {
      print('❌ 지오펜스 서비스 시작 최종 실패: $e');
      rethrow;
    }
  }

  // GeofenceService 콜백들
  @pragma('vm:entry-point')
  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    print('📍 지오펜스 상태 변경: ${geofence.id} - $geofenceStatus');

    // 기존 핸들러 연결
    await _handleGeofenceEvent(geofence, geofenceStatus, (type, alarm) {
      print('🔔 알람 트리거 완료: ${alarm['name']} ($type)'); // ✅ 로그 추가
    });
  }

  // 위치 변경 콜백 최적화
  // lib/services/location_monitor_service.dart
  void _onLocationChanged(Location location) {
    if (kDebugMode) {
      final lat = location.latitude.toStringAsFixed(4);
      final lng = location.longitude.toStringAsFixed(4);
      print('📍 $lat, $lng');
    }

    // ✅ 지오펜스 체크 추가 - 이게 빠져있었음!
    _checkGeofenceEvents(location);
  }

  // ✅ 지오펜스 체크 함수 추가
  Future<void> _checkGeofenceEvents(Location location) async {
    try {
      // GeofenceService가 자동으로 처리하므로
      // 여기서는 추가 로직이 필요없을 수도 있지만,
      // 수동 체크가 필요한 경우를 위해 추가

      // 현재 등록된 지오펜스들과 비교
      final activeAlarms = await _getActiveAlarms();
      final alarmedPlaces = _extractAlarmedPlaces(activeAlarms);

      for (var place in alarmedPlaces) {
        await _checkSinglePlaceGeofence(location, place);
      }
    } catch (e) {
      print('❌ 수동 지오펜스 체크 실패: $e');
    }
  }

  // ✅ 개별 장소 지오펜스 체크
  Future<void> _checkSinglePlaceGeofence(
    Location location,
    Map<String, dynamic> place,
  ) async {
    try {
      final lat = (place['lat'] ?? 0.0).toDouble();
      final lng = (place['lng'] ?? 0.0).toDouble();
      final radius = (place['radius'] ?? 100).toDouble();
      final placeName = place['name'] ?? 'Unknown';

      // 거리 계산
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        lat,
        lng,
      );

      print('📏 $placeName 거리: ${distance.toInt()}m (반경: ${radius.toInt()}m)');

      // 지오펜스 상태 확인 및 이벤트 트리거는 GeofenceService가 자동 처리
      // 이 함수는 디버깅 목적
    } catch (e) {
      print('❌ 개별 지오펜스 체크 실패: ${place['name']} - $e');
    }
  }

  void _onLocationServicesStatusChanged(bool status) {
    // 매개변수 타입 수정
    print('⚠️ 위치 서비스 상태 변경: $status');
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('🚶 활동 변경: ${prevActivity.type} -> ${currActivity.type}');
  }

  void _onError(error) {
    // 메서드명 수정
    print('❌ GeofenceService 오류: $error');
  }

  // 서비스 정지
  Future<void> stopMonitoring() async {
    try {
      if (_geofenceStatusChangedListener != null) {
        _geofenceService.removeGeofenceStatusChangeListener(
          _geofenceStatusChangedListener!,
        );
      }
      await _geofenceService.stop();
      _isRunning = false;
      _lastGeofenceEvent = null; // ✅ 이벤트 시간 초기화
      await _saveServiceState(false);
      print('🛑 지오펜스 감지 정지');
    } catch (e) {
      print('⚠️ 서비스 정지 실패: $e');
    }
  }

  Future<bool> _checkPermissionsSafely() async {
    try {
      final locationStatus = await Permission.locationAlways.status;
      return locationStatus.isGranted;
    } catch (e) {
      print('⚠️ 권한 확인 실패 (백그라운드): $e');
      return false;
    }
  }

  // 서비스 상태 저장/복구
  Future<void> _saveServiceState(bool running) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('geofence_running', running);
    } catch (e) {
      print('⚠️ 서비스 상태 저장 실패: $e');
    }
  }

  @pragma('vm:entry-point')
  Future<void> restoreServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasRunning = prefs.getBool('geofence_running') ?? false;
      if (wasRunning && !_isRunning) {
        await startServiceIfSafe();
      }
    } catch (e) {
      print('⚠️ 서비스 상태 복구 실패: $e');
    }
  }

  // ✅ 서비스 실행 상태 getter 수정
  @pragma('vm:entry-point')
  bool get isRunning {
    // 마지막 지오펜스 이벤트가 5분 이내면 활성 상태로 판단
    if (_lastGeofenceEvent != null) {
      final timeSinceLastEvent = DateTime.now().difference(_lastGeofenceEvent!);
      return _isRunning && timeSinceLastEvent.inMinutes < 5;
    }
    return _isRunning;
  }
}

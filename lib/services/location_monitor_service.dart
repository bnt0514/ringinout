// location_monitor_service.dart

// Flutter/Dart imports
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ✅ LocationAccuracy 타입 충돌 해결: geolocator만 사용
import 'package:geolocator/geolocator.dart'; // ✅ 이게 우선
import 'package:geofence_service/geofence_service.dart'
    hide LocationAccuracy; // ✅ LocationAccuracy만 숨김
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:ringinout/services/system_ringtone.dart';

// Project imports
import 'package:ringinout/config/constants.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_monitor.dart';

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
  // 최근 장소별 inside/outside 상태 기록
  final Map<String, bool> _lastInside = {};
  final Map<String, bool> _alreadyInside = {};

  // 상태 변수
  bool isNativeReady = false;
  bool _isRunning = false;
  DateTime? _lastGeofenceEvent;

  // ✅ 외부에서 상태 조회 가능한 getter
  /// 장소별 inside/outside 상태 (읽기 전용 복사본)
  Map<String, bool> get lastInsideStatus => Map.unmodifiable(_lastInside);

  /// 초기 진입 무시용 플래그 (읽기 전용 복사본)
  Map<String, bool> get alreadyInsideStatus => Map.unmodifiable(_alreadyInside);

  /// 서비스 실행 중 여부
  bool get isRunning => _isRunning;

  /// 마지막 지오펜스 이벤트 시각
  DateTime? get lastGeofenceEventTime => _lastGeofenceEvent;

  /// 현재 모니터링 설정
  Map<String, dynamic> get currentMonitoringProfile => {
    'intervalMs': _currentIntervalMs,
    'accuracyM': _currentAccuracyM,
    'loiteringDelayMs': _currentLoiteringDelayMs,
    'statusChangeDelayMs': _currentStatusChangeDelayMs,
  };

  GeofenceStatusChangeListener? _geofenceStatusChangedListener;
  // ✅ 배터리 최적화: 기본 간격을 2분 → 30분으로 변경
  int _currentIntervalMs = 1800000; // 기본 30분 (배터리 절약)
  int _currentAccuracyM = 100; // 정확도도 낮춤
  int _currentLoiteringDelayMs = 60000;
  int _currentStatusChangeDelayMs = 60000;

  // ✅ 배터리 최적화: 초기 interval 30분
  final GeofenceService _geofenceService = GeofenceService.instance.setup(
    interval: 1800000, // 30분 (기존 2분)
    accuracy: 100, // 정확도 낮춤
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 60000,
    useActivityRecognition: true,
    allowMockLocations: true,
    printDevLog: false,
    // androidSettings, iosSettings, notificationOptions 등은 없음!
  );

  Future<void> updateMonitoringProfile({
    required int intervalMs,
    required int accuracyM,
    required int loiteringDelayMs,
    required int statusChangeDelayMs,
  }) async {
    if (_currentIntervalMs == intervalMs &&
        _currentAccuracyM == accuracyM &&
        _currentLoiteringDelayMs == loiteringDelayMs &&
        _currentStatusChangeDelayMs == statusChangeDelayMs) {
      return;
    }

    _currentIntervalMs = intervalMs;
    _currentAccuracyM = accuracyM;
    _currentLoiteringDelayMs = loiteringDelayMs;
    _currentStatusChangeDelayMs = statusChangeDelayMs;

    GeofenceService.instance.setup(
      interval: intervalMs,
      accuracy: accuracyM,
      loiteringDelayMs: loiteringDelayMs,
      statusChangeDelayMs: statusChangeDelayMs,
      useActivityRecognition: true,
      allowMockLocations: true,
      printDevLog: false,
    );

    if (_isRunning) {
      await startServiceIfSafe();
    }
  }

  // 알람 사운드 관련 메서드
  Future<void> _playAlarmSound() async {
    try {
      // ✅ 기존에 작동하는 SystemRingtone 사용
      await SystemRingtone.play();
      print('🔔 시스템 벨소리 재생 시작');
    } catch (e) {
      print('❌ 시스템 벨소리 재생 실패: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await SystemRingtone.stop();
    } catch (e) {
      print('❌ SystemRingtone 정지 실패: $e');
    }
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

  @pragma('vm:entry-point')
  void _ensureStatusChangeListenerAttached(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) {
    if (_geofenceStatusChangedListener == null) {
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
      print('✅ GeofenceStatusChangeListener attached');
    }
  }

  // 지오펜스 이벤트 처리
  @pragma('vm:entry-point')
  Future<void> _handleGeofenceEvent(
    Geofence geofence,
    GeofenceStatus status,
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    _lastGeofenceEvent = DateTime.now();
    print('📍 지오펜스 이벤트: ${geofence.id} / 상태: $status');

    // ✅ 초기 ENTER 무시 (하지만 상태는 업데이트!)
    bool isInitialEnter = false;
    if (status == GeofenceStatus.ENTER &&
        (_alreadyInside[geofence.id] ?? false)) {
      print('⏭️ 초기 ENTER 무시: 이미 ${geofence.id} 내부에 있음');
      _alreadyInside[geofence.id] = false;
      isInitialEnter = true;
      // ✅ 상태 업데이트는 계속 진행 (return 안 함!)
    }

    try {
      final alarms =
          HiveHelper.alarmBox.values
              .where((alarm) {
                final placeName = alarm['place'] ?? alarm['locationName'];
                return placeName == geofence.id;
              })
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

      print('🔍 해당 장소 알람 개수: ${alarms.length}');

      for (int i = 0; i < alarms.length; i++) {
        final alarmData = alarms[i];
        final trigger = alarmData['trigger'] ?? 'entry';

        print('🔄 알람 $i 확인: ${alarmData['name']} (트리거: $trigger)');

        final placeId = geofence.id;

        // ✅ 초기 ENTER는 알람 트리거 안 함 + 비활성화 체크 추가
        if (!isInitialEnter) {
          final shouldTrigger = await _shouldTriggerAlarmAsync(
            trigger,
            status,
            placeId,
            alarmData,
          );
          if (shouldTrigger) {
            print('✅ 알람 트리거: ${alarmData['name']} (트리거: $trigger)');
            await _triggerAlarm(alarmData, trigger, onTrigger);
          } else {
            print('⏭️ 알람 조건 불만족 또는 비활성화: ${alarmData['name']}');
          }
        } else {
          print('⏭️ 초기 ENTER 알람 스킵: ${alarmData['name']}');
        }
      }

      // ✅ 알람 처리 후 상태 업데이트 (초기 ENTER도 포함)
      if (status == GeofenceStatus.ENTER) {
        _lastInside[geofence.id] = true;
        print('📝 상태 업데이트: ${geofence.id} = inside (true)');
      } else if (status == GeofenceStatus.EXIT) {
        _lastInside[geofence.id] = false;
        _alreadyInside[geofence.id] = false;
        print('📝 상태 업데이트: ${geofence.id} = outside (false)');
      }
    } catch (e) {
      print('❌ 지오펜스 이벤트 처리 실패: $e');
    }
  }

  // 243줄 _shouldTriggerAlarm 수정 (상태 업데이트 제거)
  @pragma('vm:entry-point')
  Future<bool> _shouldTriggerAlarmAsync(
    String trigger,
    GeofenceStatus status,
    String placeId,
    Map<String, dynamic> alarmData,
  ) async {
    final wasInside = _lastInside[placeId] ?? false;
    final alarmId = alarmData['id'];

    // ✅ Hive에서 최신 알람 상태 직접 확인 (캐시 문제 방지)
    if (alarmId is String) {
      try {
        final box = HiveHelper.alarmBox;
        final latestAlarm = box.get(alarmId);

        // 알람이 삭제됨
        if (latestAlarm == null) {
          print('⛔ 알람이 삭제됨 - 트리거 안함: ${alarmData['name']}');
          return false;
        }

        // 알람이 비활성화됨
        if (latestAlarm['enabled'] != true) {
          print('⛔ 알람이 비활성화됨 (Hive 확인): ${alarmData['name']}');
          return false;
        }

        print('✅ 알람 최신 상태 확인: enabled=true');
      } catch (e) {
        print('⚠️ 최신 알람 상태 확인 실패: $e');
        // 실패 시 기존 데이터로 진행
        if (alarmData['enabled'] != true) {
          print('⏭️ 알람이 꺼져 있음 (캐시): ${alarmData['name']}');
          return false;
        }
      }
    } else {
      // alarmId가 없으면 기존 방식
      if (alarmData['enabled'] != true) {
        print('⏭️ 알람이 꺼져 있음: ${alarmData['name']}');
        return false;
      }
    }

    // ✅ SharedPreferences 비활성화 체크 (추가 안전장치)
    if (alarmId != null) {
      final prefs = await SharedPreferences.getInstance();
      final isDisabled = prefs.getBool('alarm_disabled_$alarmId') ?? false;
      if (isDisabled) {
        print('⏭️ 알람이 비활성화됨 (SharedPrefs): ${alarmData['name']}');
        return false;
      }
    }

    print('🔍 _shouldTriggerAlarm:');
    print('   - placeId: $placeId');
    print('   - trigger: $trigger');
    print('   - status: $status');
    print('   - wasInside: $wasInside');

    bool shouldTrigger = false;

    if (status == GeofenceStatus.EXIT) {
      if (wasInside && trigger == 'exit') {
        shouldTrigger = true;
        print('✅ EXIT 알람 조건 만족');
      }
      // ❌ 여기서 상태 업데이트 안 함! (_handleGeofenceEvent에서 처리)
    } else if (status == GeofenceStatus.ENTER) {
      if (!wasInside && trigger == 'entry') {
        shouldTrigger = true;
        print('✅ ENTER 알람 조건 만족');
      }
      // ❌ 여기서 상태 업데이트 안 함!
    }

    return shouldTrigger;
  }

  // ✅ 동기 버전 유지 (하위 호환성)
  @pragma('vm:entry-point')
  bool _shouldTriggerAlarm(
    String trigger,
    GeofenceStatus status,
    String placeId,
  ) {
    final wasInside = _lastInside[placeId] ?? false;

    bool shouldTrigger = false;

    if (status == GeofenceStatus.EXIT) {
      if (wasInside && trigger == 'exit') {
        shouldTrigger = true;
      }
    } else if (status == GeofenceStatus.ENTER) {
      if (!wasInside && trigger == 'entry') {
        shouldTrigger = true;
      }
    }

    return shouldTrigger;
  }

  // 303줄 _triggerAlarm 수정 (triggerCount 타입 안전 처리)
  @pragma('vm:entry-point')
  Future<void> _triggerAlarm(
    Map<String, dynamic> alarmData,
    String trigger,
    void Function(String, Map<String, dynamic>) onTrigger, {
    bool isSnoozeAlarm = false, // ✅ 스누즈 알람인지 여부
  }) async {
    final alarmId = alarmData['id'];

    // ✅ 알람 트리거 전에 Hive에서 최신 상태 확인 (캐시 문제 방지)
    if (alarmId is String) {
      try {
        final box = HiveHelper.alarmBox;
        final latestAlarm = box.get(alarmId);

        if (latestAlarm == null) {
          print('⛔ 알람이 삭제됨 - 트리거 중단: ${alarmData['name']}');
          return;
        }

        // ✅ 스누즈 알람인 경우: snoozePending 상태면 허용
        if (isSnoozeAlarm) {
          if (latestAlarm['snoozePending'] == true) {
            print('✅ 스누즈 알람 트리거 허용 (snoozePending=true)');
            // snoozePending 해제 (스누즈 완료)
            final updatedAlarm = Map<String, dynamic>.from(latestAlarm);
            updatedAlarm['snoozePending'] = false;
            await box.put(alarmId, updatedAlarm);
            alarmData = updatedAlarm;
          } else if (latestAlarm['enabled'] != true) {
            print('⛔ 스누즈 알람이지만 비활성화됨 - 트리거 중단');
            return;
          } else {
            alarmData = Map<String, dynamic>.from(latestAlarm);
          }
        } else {
          // ✅ 일반 알람인 경우: enabled 체크
          if (latestAlarm['enabled'] != true) {
            print('⛔ 알람이 비활성화됨 - 트리거 중단: ${alarmData['name']}');
            return;
          }
          alarmData = Map<String, dynamic>.from(latestAlarm);
        }

        print(
          '✅ 최신 알람 상태 확인 완료: enabled=${latestAlarm['enabled']}, snoozePending=${latestAlarm['snoozePending']}',
        );
      } catch (e) {
        print('⚠️ 최신 알람 상태 확인 실패: $e - 기존 데이터로 진행');
      }
    }

    print('✅ 알람 트리거: ${alarmData['name']}');

    try {
      // 1. 트리거 카운트 증가 (안전한 타입 처리)
      print('🔢 트리거 카운트 업데이트 시도');

      dynamic currentCount = alarmData['triggerCount'];
      int triggerCount = 0;

      // ✅ 타입 안전 변환
      if (currentCount == null) {
        triggerCount = 0;
      } else if (currentCount is int) {
        triggerCount = currentCount;
      } else if (currentCount is double) {
        triggerCount = currentCount.toInt();
      } else if (currentCount is String) {
        triggerCount = int.tryParse(currentCount) ?? 0;
      } else {
        print('⚠️ 알 수 없는 타입: ${currentCount.runtimeType}');
        triggerCount = 0;
      }

      // ✅ 새로운 Map 생성하여 업데이트 (int 타입 보장!)
      final updatedAlarmData = Map<String, dynamic>.from(alarmData);
      updatedAlarmData['triggerCount'] = triggerCount + 1; // ✅ int로 저장!

      final alarmId = alarmData['id'];
      if (alarmId is String) {
        await HiveHelper.updateLocationAlarmById(alarmId, updatedAlarmData);
      }
      alarmData['triggerCount'] = triggerCount + 1; // ✅ 현재 Map도 업데이트

      print('✅ 트리거 카운트 업데이트 완료: ${triggerCount + 1}');
    } catch (e) {
      print('❌ 트리거 카운트 업데이트 실패: $e');
      // 실패해도 알람은 계속 진행
    }

    try {
      // 2. 일반 알람은 즉시 비활성화 (요구사항)
      if (!isSnoozeAlarm && alarmId is String) {
        final updatedAlarm = Map<String, dynamic>.from(alarmData);
        updatedAlarm['enabled'] = false;
        await HiveHelper.updateLocationAlarmById(alarmId, updatedAlarm);
        alarmData = updatedAlarm;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('alarm_disabled_$alarmId', true);
        print('✅ 알람 비활성화 완료: ${alarmData['name']}');
      }
    } catch (e) {
      print('❌ 알람 비활성화 실패: $e');
    }

    try {
      // 3. 시스템 벨소리 재생
      print('🔊 시스템 벨소리 재생 시작');
      await SystemRingtone.play();
      print('✅ 시스템 벨소리 재생 완료');
    } catch (e) {
      print('❌ 시스템 벨소리 재생 실패: $e');
    }

    try {
      // 4. 진동 실행
      print('📳 진동 시작');
      await _triggerVibration();
      print('✅ 진동 완료');
    } catch (e) {
      print('❌ 진동 실행 실패: $e');
    }

    // ✅ 4. Native 전체화면 알람 표시 (우선)
    // 전체화면이 가능하면 전체화면, 아니면 Heads-up 알림이 표시됨
    try {
      print('📱 Native 전체화면 알람 표시 시작');
      await _handleAlarmDisplay(alarmData);
      print('✅ Native 전체화면 알람 표시 완료');
    } catch (e) {
      print('❌ Native 전체화면 알람 표시 실패: $e');

      // ✅ 전체화면 실패 시에만 푸쉬 알림 표시 (중복 방지!)
      try {
        print('📢 전체화면 실패 → 영구 푸쉬 알림으로 대체');
        await _showPersistentAlarmNotification(alarmData);
        print('✅ 영구 푸쉬 알림 표시 완료');
      } catch (e2) {
        print('❌ 푸쉬 알림도 실패: $e2');
      }
    }

    try {
      // 6. 콜백 호출
      print('📞 onTrigger 콜백 호출');
      onTrigger(trigger, alarmData);
      print('✅ onTrigger 콜백 완료');
    } catch (e) {
      print('❌ onTrigger 콜백 실패: $e');
    }

    print('🎯 _triggerAlarm 메서드 완료: ${alarmData['name']}');
  }
  // 영구 푸쉬 알림 표시 함수 추가
  // _showPersistentAlarmNotification 메서드 수정

  @pragma('vm:entry-point')
  Future<void> _showPersistentAlarmNotification(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      // ✅ static 메서드이므로 클래스명으로 직접 호출

      // 알람 타입에 따른 메시지 생성
      final isEntry = (alarmData['trigger'] ?? 'entry') == 'entry';
      final placeName = alarmData['place'] ?? '지정 장소';
      final alarmName = alarmData['name'] ?? '위치 알람';

      final title = '🚨 $alarmName';
      final body = isEntry ? '$placeName에 도착했습니다!' : '$placeName에서 벗어났습니다!';

      // ✅ instance 생성 없이 static 메서드 직접 호출
      await AlarmNotificationHelper.showPersistentAlarmNotification(
        title: title,
        body: body,
        alarmData: alarmData,
      );

      print('✅ 영구 푸쉬 알림 생성: $title - $body');
    } catch (e) {
      print('❌ 푸쉬 알림 생성 실패: $e');
      rethrow;
    }
  }

  // 진동 함수 추가
  @pragma('vm:entry-point')
  Future<void> _triggerVibration() async {
    try {
      // HapticFeedback 사용
      await HapticFeedback.heavyImpact();

      // 추가적인 진동이 필요하면 아래 활성화
      // await SystemChannels.platform.invokeMethod('HapticFeedback.vibrate');

      print('✅ 진동 실행 완료');
    } catch (e) {
      print('❌ 진동 실행 실패: $e');
    }
  }

  // 화면 전환 처리 (새로 추가)
  @pragma('vm:entry-point')
  Future<void> _handleAlarmDisplay(Map<String, dynamic> alarmData) async {
    try {
      // ✅ 백그라운드에서도 작동하는 Native 전체화면 표시
      print('📱 Native 전체화면 알람 표시 시작');
      await _showNativeFullScreenAlarm(alarmData);
      print('✅ Native 전체화면 알람 표시 완료');
    } catch (e) {
      print('❌ Native 전체화면 표시 실패: $e');
      // Native 실패 시 Flutter 전체화면으로 폴백 (포그라운드일 때만 작동)
      try {
        _showFullScreenAlarmFlutter(alarmData);
      } catch (e2) {
        print('❌ Flutter 전체화면도 실패: $e2');
      }
    }
  }

  // Native 전체화면 알람 (새로 추가)
  @pragma('vm:entry-point')
  Future<void> _showNativeFullScreenAlarm(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      await AlarmNotificationHelper.showNativeAlarm(
        title: alarmData['name'] ?? 'Ringinout',
        message:
            (alarmData['trigger'] == 'exit')
                ? '지정 장소에서 벗어났습니다'
                : '지정 장소에 도착했습니다',
        sound: alarmData['sound'] ?? 'assets/sounds/thoughtfulringtone.mp3',
        vibrate: (alarmData['vibrate'] ?? true) == true,
        alarmData: alarmData, // ✅ alarmData 전달
      );

      // 소리 보장
      await _playAlarmSound();
      print('✅ Helper 기반 전체화면 알람 실행 성공');
    } catch (e) {
      print('❌ Helper 기반 Native 알람 실패: $e');
      // 실패 시 Flutter 풀스크린으로 백업
      _showFullScreenAlarmFlutter(alarmData);
    }
  }

  // 기존 Flutter 화면 표시 (로그 추가)
  @pragma('vm:entry-point')
  void _showFullScreenAlarmFlutter(Map<String, dynamic> alarmData) {
    print('📱 Flutter 전체화면 알람 표시 시도: ${alarmData['name']}');
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
      // ✅ 1. 권한 체크 추가
      final hasPermission = await _checkPermissionsSafely();
      if (!hasPermission) {
        print('⚠️ 위치 권한 없음 - 지오펜스 서비스 시작 불가');
        return;
      }

      // 2. 활성 알람 확인
      final activeAlarms = await _getActiveAlarms();

      if (activeAlarms.isEmpty) {
        print('📭 활성화된 알람이 없어 지오펜스 서비스를 시작하지 않음');
        await _stopGeofenceService(); // 기존 서비스 중단
        return;
      }

      print('🔔 활성 알람 ${activeAlarms.length}개 발견 - 지오펜스 서비스 시작');

      // 3. 알람이 있는 장소만 추출
      final alarmedPlaces = _extractAlarmedPlaces(activeAlarms);
      print('📍 지오펜스 필요한 장소: ${alarmedPlaces.map((p) => p['name']).toList()}');

      // 4. 해당 장소들만 지오펜스 생성
      final geofences = await _createGeofencesForPlaces(alarmedPlaces);

      if (geofences.isEmpty) {
        print('⚠️ 생성할 지오펜스가 없음');
        return;
      }

      // 5. 지오펜스 서비스 시작
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

      // ✅ 스누즈 알람 체크 시작
      _startSnoozeChecker(onTrigger);

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

      // ✅ 콜백 등록
      prepareMonitoringOnly(onTrigger);
      _ensureStatusChangeListenerAttached(onTrigger);

      // ✅ _startGeofenceService 호출 (초기 위치 확인 포함)
      await _startGeofenceService(geofences);

      print('🚀 백그라운드 지오펜스 서비스 시작 완료');
    } catch (e) {
      print('❌ 백그라운드 지오펜스 서비스 시작 실패: $e');
    }
  }

  // ✅ Watchdog heartbeat 타이머 (스누즈 체크는 AlarmManager가 담당)
  Timer? _watchdogTimer;
  static const _watchdogChannel = MethodChannel(
    'com.example.ringinout/watchdog',
  );

  void _startSnoozeChecker(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) {
    // 기존 타이머 정리
    _watchdogTimer?.cancel();

    // ✅ 스누즈 체크 타이머 제거됨 (AlarmManager가 담당)
    // _snoozeCheckTimer는 더 이상 사용하지 않음

    // ✅ 배터리 최적화: 1분 → 15분으로 변경 (wake-up 횟수 대폭 감소)
    _watchdogTimer = Timer.periodic(Duration(minutes: 15), (timer) async {
      await _sendWatchdogHeartbeat();
    });

    // 즉시 첫 heartbeat 전송
    _sendWatchdogHeartbeat();

    print('⏰ Watchdog heartbeat 시작됨 (15분 간격)');
  }

  // ✅ Watchdog heartbeat 전송 (static으로 외부에서도 호출 가능)
  static Future<void> sendWatchdogHeartbeat() async {
    try {
      final activeAlarms = await _getActiveAlarmsStatic();
      final activeCount =
          activeAlarms.where((a) => a['enabled'] == true).length;

      await _watchdogChannel.invokeMethod('sendHeartbeat', {
        'activeAlarmsCount': activeCount,
      });

      print('💓 Watchdog heartbeat 전송 (활성 알람: $activeCount)');
    } on MissingPluginException {
      if (kDebugMode) {
        print('ℹ️ Watchdog heartbeat 스킵: 채널 미등록 상태');
      }
    } catch (e) {
      print('⚠️ Watchdog heartbeat 실패: $e');
    }
  }

  // ✅ Static 버전의 활성 알람 가져오기
  static Future<List<Map<String, dynamic>>> _getActiveAlarmsStatic() async {
    try {
      // ✅ HiveHelper.alarmBox 사용 (locationAlarms_v2와 일관성 유지)
      final box = HiveHelper.alarmBox;
      final List<Map<String, dynamic>> alarms = [];
      for (var key in box.keys) {
        final value = box.get(key);
        if (value is Map) {
          alarms.add(Map<String, dynamic>.from(value));
        }
      }
      return alarms;
    } catch (e) {
      print('❌ 활성 알람 로드 실패: $e');
      return [];
    }
  }

  // ✅ 인스턴스 메서드 (내부용)
  Future<void> _sendWatchdogHeartbeat() async {
    await sendWatchdogHeartbeat();
  }

  // ✅ 모든 스누즈 스케줄 삭제 (디버그용)
  static Future<void> clearAllSnoozeSchedules() async {
    try {
      final box = await Hive.openBox('snoozeSchedules');
      await box.clear();
      print('🗑️ 모든 스누즈 스케줄 삭제 완료');
    } catch (e) {
      print('❌ 스누즈 스케줄 삭제 실패: $e');
    }
  }

  // ✅ 스누즈 알람 체크
  Future<void> _checkSnoozeAlarms(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    try {
      var box = await Hive.openBox('snoozeSchedules');
      final now = DateTime.now().millisecondsSinceEpoch;

      // 🐛 디버그: 현재 스누즈 스케줄 개수 확인
      if (box.keys.isNotEmpty) {
        print(
          '🔍 스누즈 스케줄 체크 중: ${box.keys.length}개 / 현재 시각: ${DateTime.fromMillisecondsSinceEpoch(now)}',
        );
      }

      final keysToRemove = <String>[];

      for (var key in box.keys) {
        final schedule = box.get(key);
        if (schedule == null) continue;

        final scheduledTime = schedule['scheduledTime'] as int?;
        if (scheduledTime == null) continue;

        // 🐛 디버그: 예정 시간 출력
        final scheduledDateTime = DateTime.fromMillisecondsSinceEpoch(
          scheduledTime,
        );
        final remainingSeconds = ((scheduledTime - now) / 1000).round();
        print(
          '📅 스케줄: ${schedule['alarmTitle']} - 예정: $scheduledDateTime (${remainingSeconds}초 후)',
        );

        // 예정 시간이 되었는지 체크
        if (now >= scheduledTime) {
          // ✅ 먼저 스케줄 삭제 (중복 트리거 방지!)
          keysToRemove.add(key.toString());
          await box.delete(key);
          print('🗑️ 스누즈 스케줄 즉시 삭제: $key');

          print('⏰ 스누즈 알람 트리거: ${schedule['alarmTitle']}');

          // ✅ 타입 안전 변환
          final dynamic alarmDataRaw = schedule['alarmData'];
          Map<String, dynamic>? alarmData;

          if (alarmDataRaw is Map<String, dynamic>) {
            alarmData = alarmDataRaw;
          } else if (alarmDataRaw is Map) {
            alarmData = Map<String, dynamic>.from(alarmDataRaw);
          }

          if (alarmData != null) {
            // ✅ 스누즈 알람 트리거 (isSnoozeAlarm: true)
            await _triggerAlarm(
              alarmData,
              alarmData['trigger'] ?? 'entry',
              onTrigger,
              isSnoozeAlarm: true,
            );
          }

          // ✅ 스케줄은 위에서 이미 삭제됨 - 중복 추가하지 않음
        }
      }

      // ✅ 만료된 스케줄 삭제 (위에서 즉시 삭제되므로 이 부분은 빈 리스트)
      // 이미 삭제되었으므로 다시 삭제하지 않음
    } catch (e) {
      print('❌ 스누즈 알람 체크 실패: $e');
    }
  }

  // 알람이 있는 장소만 추출
  @pragma('vm:entry-point')
  List<Map<String, dynamic>> _extractAlarmedPlaces(
    List<Map<String, dynamic>> alarms,
  ) {
    final Set<String> alarmPlaceNames =
        alarms
            .where((alarm) {
              final placeName = alarm['place'] ?? alarm['locationName'];
              return alarm['enabled'] == true && placeName != null;
            })
            .map((alarm) => (alarm['place'] ?? alarm['locationName']) as String)
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
      if (_isRunning) {
        print('ℹ️ 지오펜스 서비스 이미 실행 중 - start 건너뜀');
        return;
      }

      // 1) 상태변화 리스너 보장
      _ensureStatusChangeListenerAttached((type, alarm) {
        print('🔔 geofence status change -> $type : ${alarm['name'] ?? ''}');
      });

      // ✅ 추가: 위치 변경 리스너 등록
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addLocationServicesStatusChangeListener(
        _onLocationServicesStatusChanged,
      );
      _geofenceService.addActivityChangeListener(_onActivityChanged);
      _geofenceService.addStreamErrorListener(_onError);

      // ✅ 2) 초기 위치 확인 및 상태 설정 (트리거 없이)
      try {
        print('📍 초기 위치 기반 상태 설정 시작');

        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
          ),
        );
        final currLat = pos.latitude;
        final currLng = pos.longitude;

        print('📍 현재 위치: $currLat, $currLng');

        final activeAlarms = await _getActiveAlarms();
        final places = _extractAlarmedPlaces(activeAlarms);

        for (final p in places) {
          final name = (p['name'] ?? 'Unknown') as String;
          final lat = (p['lat'] ?? 0.0).toDouble();
          final lng = (p['lng'] ?? 0.0).toDouble();
          final radius = (p['radius'] ?? 100).toDouble();

          final distance = Geolocator.distanceBetween(
            currLat,
            currLng,
            lat,
            lng,
          );
          final insideNow = distance <= radius;

          // ✅ 초기 상태 기록 (트리거는 하지 않음)
          _lastInside[name] = insideNow;
          _alreadyInside[name] = insideNow; // ✅ 초기 진입 무시용 플래그

          if (insideNow) {
            print(
              '🏠 "$name" - 이미 지오펜스 내부 (거리: ${distance.toInt()}m) - 알람 트리거 안함',
            );
          } else {
            print('🚶 "$name" - 지오펜스 외부 (거리: ${distance.toInt()}m) - 진입 시 알람');
          }
        }

        print('✅ 초기 상태 설정 완료');
        print('  - _lastInside: $_lastInside');
        print('  - _alreadyInside: $_alreadyInside');
      } catch (e) {
        print('⚠️ 초기 위치 상태 설정 실패: $e');
        // 실패해도 서비스는 계속 진행
      }

      // 3) 지오펜스 시작
      await _geofenceService.start(geofences).catchError((e) {
        print('❌ 지오펜스 시작 실패: $e');
        if (e.toString().contains('ACTIVITY_NOT_ATTACHED')) {
          print('ℹ️ 백그라운드 실행으로 인한 실패 - 정상적인 상황');
          return;
        }
        throw e;
      });

      _isRunning = true;
      await _saveServiceState(true);

      print('🚀 지오펜스 감지 시작 완료 - ${geofences.length}개 장소 모니터링');
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
  void _onLocationChanged(Location location) {
    if (kDebugMode) {
      final lat = location.latitude.toStringAsFixed(4);
      final lng = location.longitude.toStringAsFixed(4);
      print('📍 $lat, $lng');
    }

    // ✅ SmartLocationMonitor에 위치 전달 (중복 GPS 호출 제거)
    SmartLocationMonitor.onLocationUpdate(
      location.latitude,
      location.longitude,
      location.speed,
    );

    // ✅ 지오펜스 체크 (디버그 로그만)
    _checkGeofenceEvents(location);
  }

  // ✅ _checkGeofenceEvents 메서드 수정 (GeofenceService가 자동 처리하므로 단순화)
  Future<void> _checkGeofenceEvents(Location location) async {
    // GeofenceService가 자동으로 지오펜스 이벤트를 처리하므로
    // 이 함수는 디버깅 로그만 출력

    if (kDebugMode) {
      try {
        final activeAlarms = await _getActiveAlarms();
        final alarmedPlaces = _extractAlarmedPlaces(activeAlarms);

        for (var place in alarmedPlaces) {
          final lat = (place['lat'] ?? 0.0).toDouble();
          final lng = (place['lng'] ?? 0.0).toDouble();
          final radius = (place['radius'] ?? 100).toDouble();
          final placeName = place['name'] ?? 'Unknown';

          final distance = Geolocator.distanceBetween(
            location.latitude,
            location.longitude,
            lat,
            lng,
          );

          // 디버그 로그만 출력
          if (distance <= radius * 1.5) {
            // 반경의 1.5배 이내일 때만 로그
            print(
              '📏 $placeName: ${distance.toInt()}m (반경: ${radius.toInt()}m)',
            );
          }
        }
      } catch (e) {
        print('❌ 지오펜스 체크 실패: $e');
      }
    }
  }

  void _onLocationServicesStatusChanged(bool status) {
    // 매개변수 타입 수정
    print('⚠️ 위치 서비스 상태 변경: $status');
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('🚶 활동 변경: ${prevActivity.type} -> ${currActivity.type}');

    // ✅ SmartLocationMonitor에 활동 변경 알림
    SmartLocationMonitor.onActivityChanged(
      prevActivity.type,
      currActivity.type,
    );
  }

  void _onError(error) {
    // 메서드명 수정
    print('❌ GeofenceService 오류: $error');
  }

  // 서비스 정지
  Future<void> stopMonitoring() async {
    try {
      // ✅ Watchdog 타이머 정지
      _watchdogTimer?.cancel();
      _watchdogTimer = null;

      // ✅ 리스너 제거
      if (_geofenceStatusChangedListener != null) {
        _geofenceService.removeGeofenceStatusChangeListener(
          _geofenceStatusChangedListener!,
        );
      }

      // ✅ 추가: 다른 리스너들도 제거
      _geofenceService.removeLocationChangeListener(_onLocationChanged);
      _geofenceService.removeLocationServicesStatusChangeListener(
        _onLocationServicesStatusChanged,
      );
      _geofenceService.removeActivityChangeListener(_onActivityChanged);
      _geofenceService.removeStreamErrorListener(_onError);

      await _geofenceService.stop();
      _isRunning = false;
      _lastGeofenceEvent = null;
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

  // ✅ 특정 장소의 상태 초기화 (알람 재활성화 시 사용)
  @pragma('vm:entry-point')
  Future<void> resetPlaceState(String placeName) async {
    try {
      print('🔄 장소 상태 초기화 시작: $placeName');

      // 현재 위치 확인
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      // 해당 장소 정보 가져오기
      final places = HiveHelper.getSavedLocations();
      final place = places.firstWhere(
        (p) => p['name'] == placeName,
        orElse: () => {},
      );

      if (place.isEmpty) {
        print('⚠️ 장소를 찾을 수 없음: $placeName');
        return;
      }

      final lat = (place['lat'] ?? 0.0).toDouble();
      final lng = (place['lng'] ?? 0.0).toDouble();
      final radius = (place['radius'] ?? 100).toDouble();

      // 현재 위치와 장소 거리 계산
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );

      final isInside = distance <= radius;

      // ✅ 상태 초기화
      _lastInside[placeName] = isInside;
      _alreadyInside[placeName] = isInside;

      if (isInside) {
        print('🏠 "$placeName" - 지오펜스 내부 (거리: ${distance.toInt()}m)');
        print('   → _alreadyInside[$placeName] = true (초기 진입 알람 스킵)');
      } else {
        print('🚶 "$placeName" - 지오펜스 외부 (거리: ${distance.toInt()}m)');
        print('   → _alreadyInside[$placeName] = false (진입 시 알람)');
      }

      print('✅ 장소 상태 초기화 완료: $placeName');
    } catch (e) {
      print('❌ 장소 상태 초기화 실패: $e');
    }
  }
}

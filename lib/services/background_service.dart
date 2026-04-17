// lib/services/background_services.dart

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive/hive.dart';

// Project imports
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/hive_helper.dart';

class BackgroundServiceManager {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _isConfigured = false;

  /// Initialize and configure background service
  static Future<void> initialize() async {
    if (_isConfigured) return;
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: false, // ✅ 수동 시작으로 변경 (채널 생성 후 시작)
        autoStartOnBoot: true,
        foregroundServiceNotificationId: ServiceConstants.notificationId,
        notificationChannelId: ServiceConstants.channelId,
        initialNotificationTitle: ServiceConstants.notificationTitle,
        initialNotificationContent: ServiceConstants.notificationContent,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
    _isConfigured = true;
  }

  /// Start background service
  static Future<void> startService() async {
    await _service.startService();
  }

  /// Stop background service
  static Future<void> stopService() async {
    _service.invoke('stopService');
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    return _service.isRunning();
  }
}

class ServiceConstants {
  static const String channelId = 'ringinout_background_quiet';
  static const String channelName = 'Ringinout 백그라운드 서비스';
  static const String channelDescription = '위치 기반 알람 서비스';
  static const int notificationId = 888;

  // ✅ 삭제 불가능한 알림 설정
  static const String notificationTitle = 'Ringinout';
  static const String notificationContent = '위치 알람 활성화됨';

  // ✅ 알림 삭제 불가 설정
  static const bool showOngoing = true; // ✅ 삭제 불가능
  static const bool autoCancel = false; // ✅ 자동 삭제 안함
}

/// Background service handler for both platforms
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 백그라운드 서비스용 알림 채널 먼저 생성 (필수!)
  await createNotificationChannel();
  await initializeNotifications();

  // Set up Android foreground service
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    // ✅ 최초 시작 시 포그라운드 알림
    service.setForegroundNotificationInfo(
      title: ServiceConstants.notificationTitle,
      content: ServiceConstants.notificationContent,
    );
  }

  // ✅ 백그라운드 Hive 초기화 (경로 통일)
  await _initializeBackgroundHive();

  // ✅ 활성 알람(오늘 기준) 없으면 백그라운드 서비스 종료
  final activeAlarms = HiveHelper.getActiveAlarmsForMonitoring();
  if (activeAlarms.isEmpty) {
    print('📭 백그라운드 활성 알람 없음 - 서비스 종료');
    if (service is AndroidServiceInstance) {
      await service.stopSelf();
    } else {
      await service.stopSelf();
    }
    return;
  }

  // ✅ 위치 모니터링 시작 (알림과 독립적)
  final locationMonitor = LocationMonitorService();
  await locationMonitor.startBackgroundMonitoring((type, alarm) async {
    // 백그라운드 알람 트리거 로그만 (전체화면+벨소리는 _triggerAlarm에서 이미 처리)
    print('🚨 백그라운드 알람: ${alarm['name']} ($type)');
  });

  // Handle service stop request
  service.on('stopService').listen((event) async {
    await locationMonitor.stopMonitoring();
    await service.stopSelf();
  });

  print('✅ 백그라운드 서비스 시작 완료 - 조용한 모드');
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  return true;
}

/// ✅ 백그라운드 Hive 초기화 (메인과 경로 통일)
Future<void> _initializeBackgroundHive() async {
  try {
    print('🚀 백그라운드 Hive 초기화 시작');

    // ✅ 메인 앱과 동일한 초기화 경로 사용
    await HiveHelper.initBackground();
    print('📦 백그라운드 Hive 초기화 완료');

    // ✅ 데이터 확인 로그
    await _logBackgroundData();
  } catch (e) {
    print('❌ 백그라운드 Hive 초기화 실패: $e');
    rethrow;
  }
}

/// ✅ 백그라운드 데이터 확인 및 로그 (박스명 통일)
Future<void> _logBackgroundData() async {
  try {
    // 저장된 위치 확인 (Map 형태로)
    final locationsBox = Hive.box('savedLocations_v2'); // ✅ 버전 추가
    final locations = locationsBox.values.toList();
    print('📍 백그라운드 저장된 위치: ${locations.length}개');

    // 알람 확인 (Map 형태로)
    final alarmsBox = Hive.box('locationAlarms_v2'); // ✅ 버전 추가
    final alarms = alarmsBox.values.toList();

    int activeCount = 0;
    for (int i = 0; i < alarms.length; i++) {
      final alarm = alarms[i];
      if (alarm is Map) {
        final isEnabled = alarm['enabled'] == true;
        if (isEnabled) activeCount++;

        print(
          '   - 알람 $i: ${alarm['name']} (${isEnabled ? '활성' : '비활성'}) - place: ${alarm['place']}, trigger: ${alarm['trigger']}',
        );
      } else {
        print('   - 알람 $i: 알 수 없는 형태 (${alarm.runtimeType})');
      }
    }

    print('🔔 백그라운드 전체 알람: ${alarms.length}개');
    print('🔔 백그라운드 활성 알람: $activeCount개');

    // ✅ 메인 앱과 비교용 로그
    if (alarms.isEmpty) {
      print('⚠️  백그라운드에서 알람이 비어있음 - 메인 앱과 데이터 불일치 가능성');
    }
  } catch (e) {
    print('❌ 백그라운드 데이터 확인 실패: $e');
  }
}

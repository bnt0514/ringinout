import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';

// Project imports
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/background_service.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/smart_location_service.dart';

@pragma('vm:entry-point')
class AppInitializer {
  @pragma('vm:entry-point')
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 1. 권한 요청
    await _requestPermissions();

    // 2. 서비스 초기화
    await _initializeServices();

    // 3. 설정 로드
    await _loadSettings();

    // 4. 🎯 SmartLocationService 시작 (네이티브 3단계 모니터링)
    await _startSmartLocationService();
  }

  // 🎯 SmartLocationService 초기화 및 시작
  @pragma('vm:entry-point')
  static Future<void> _startSmartLocationService() async {
    try {
      // SmartLocationService 초기화
      await SmartLocationService.initialize(
        onAlarmTriggered: (placeId, placeName, triggerType) {
          print('🚨 알람 트리거 콜백: $placeName ($triggerType)');
        },
      );

      // 활성 알람 개수 확인
      final activeAlarms = await _getActiveAlarmsCount();

      if (activeAlarms > 0) {
        print('🔔 활성 알람 ${activeAlarms}개 발견 - SmartLocationService 시작');
        await SmartLocationService.startMonitoring();
      } else {
        print('📭 활성 알람이 없어 SmartLocationService 시작하지 않음');
      }
    } catch (e) {
      print('❌ SmartLocationService 시작 실패: $e');
      // 폴백: 기존 백그라운드 서비스 사용
      await _startBackgroundServiceIfNeeded();
    }
  }

  // ✅ 폴백: 기존 백그라운드 서비스 (SmartLocationService 실패 시)
  @pragma('vm:entry-point')
  static Future<void> _startBackgroundServiceIfNeeded() async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();

      if (activeAlarms > 0) {
        print('🔔 폴백: 기존 백그라운드 서비스 시작');
        await BackgroundServiceManager.startService();
      } else {
        await BackgroundServiceManager.stopService();
      }
    } catch (e) {
      print('❌ 백그라운드 서비스 시작 조건 확인 실패: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Permission.activityRecognition.request();
    await Permission.notification.request();
    await Permission.systemAlertWindow.request();
  }

  static Future<void> _initializeServices() async {
    await HiveHelper.init();
    await createNotificationChannel();
    await initializeNotifications();
    await BackgroundServiceManager.initialize();
  }

  static Future<void> _loadSettings() async {
    final locationMonitor = LocationMonitorService();
    await locationMonitor.restoreServiceState();
  }

  // ✅ 활성 알람 개수 확인
  @pragma('vm:entry-point')
  static Future<int> _getActiveAlarmsCount() async {
    try {
      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        await Hive.openBox('locationAlarms_v2');
      }

      final box = Hive.box('locationAlarms_v2');
      final activeAlarms =
          box.values.where((alarm) => alarm['enabled'] == true).length;

      return activeAlarms;
    } catch (e) {
      print('❌ 활성 알람 개수 확인 실패: $e');
      return 0;
    }
  }
}

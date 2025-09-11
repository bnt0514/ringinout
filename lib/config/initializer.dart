import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Project imports
import 'package:ringinout/config/constants.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/smart_location_monitor.dart';

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

    // 4. 활성 알람 확인 후 백그라운드 서비스 시작
    await _startBackgroundServiceIfNeeded();
  }

  // ✅ 새로운 메서드: 활성 알람이 있을 때만 백그라운드 서비스 시작
  @pragma('vm:entry-point')
  static Future<void> _startBackgroundServiceIfNeeded() async {
    try {
      // 활성 알람 개수 확인
      final activeAlarms = await _getActiveAlarmsCount();

      if (activeAlarms > 0) {
        print('🔔 활성 알람 ${activeAlarms}개 발견 - 백그라운드 서비스 시작');
        await configureBackgroundService();
      } else {
        print('📭 활성 알람이 없어 백그라운드 서비스 시작하지 않음');
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
    await Permission.accessNotificationPolicy.request();
  }

  static Future<void> _initializeServices() async {
    await HiveHelper.init();
    await createNotificationChannel();
    await initializeNotifications();
  }

  static Future<void> _loadSettings() async {
    // 앱 설정 로드
    final locationMonitor = LocationMonitorService();
    await locationMonitor.restoreServiceState();
  }

  // ✅ 백그라운드 서비스 설정
  @pragma('vm:entry-point')
  static Future<void> configureBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,

        notificationChannelId: 'ringinout_channel', // 기존 채널 사용
        initialNotificationTitle: '위치 알람 모니터링',
        initialNotificationContent: '위치 기반 알람을 감시하고 있습니다',

        foregroundServiceNotificationId: 999,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    await service.startService();
    print('🚀 백그라운드 서비스 시작 요청 완료');
  }

  // ✅ onStart 메서드
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    print('🚀 백그라운드 서비스 시작');
    WidgetsFlutterBinding.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: '위치 알람 모니터링',
        content: '백그라운드에서 위치를 감시하고 있습니다',
      );
    }

    await _initializeBackgroundServices();

    Timer.periodic(const Duration(hours: 12), (timer) async {
      try {
        await _maintainBackgroundService(service);
      } catch (e) {
        print('⚠️ 백그라운드 서비스 유지 작업 실패: $e');
      }
    });
  }

  // ✅ iOS 백그라운드
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    print('🍎 iOS 백그라운드 서비스');
    return true;
  }

  // ✅ 백그라운드 서비스 초기화 (경로 및 박스명 통일)
@pragma('vm:entry-point')
static Future<void> _initializeBackgroundServices() async {
  try {
    // ✅ 메인 앱과 완전히 동일한 경로 사용
    final appDocDir = await getApplicationDocumentsDirectory();
    final hivePath = '${appDocDir.path}/ringinout_unique_v3';  // ✅ 경로 통일

    // 디렉토리가 없으면 생성
    final hiveDir = Directory(hivePath);
    if (!await hiveDir.exists()) {
      await hiveDir.create(recursive: true);
    }

    // 고유 경로로 Hive 초기화
    Hive.init(hivePath);

    // ✅ 메인 앱과 동일한 박스명 사용 (버전 포함)
    if (!Hive.isBoxOpen('savedLocations_v2')) {
      await Hive.openBox('savedLocations_v2');
    }
    if (!Hive.isBoxOpen('locationAlarms_v2')) {
      await Hive.openBox('locationAlarms_v2');
    }
    if (!Hive.isBoxOpen('settings_v2')) {
      await Hive.openBox('settings_v2');
    }

    print('📦 백그라운드 Hive 초기화 완료: $hivePath');
  } catch (e) {
    print('❌ 백그라운드 서비스 초기화 실패: $e');
  }
}

  // ✅ 서비스 유지 메서드
  @pragma('vm:entry-point')
  static Future<void> _maintainBackgroundService(
    ServiceInstance service,
  ) async {
    try {
      final activeAlarms = await _getActiveAlarmsCount();

      // ✅ 활성 알람이 없으면 서비스 중단
      if (activeAlarms == 0) {
        print('📭 활성 알람이 없어 백그라운드 서비스 중단');
        service.stopSelf();
        return;
      }

      // 안전한 알림 업데이트
      try {
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: "위치 알람 모니터링",
            content: "활성 알람 ${activeAlarms}개 감시중",
          );
        }
      } catch (notificationError) {
        print('⚠️ 알림 업데이트 실패: $notificationError');
      }

      await _checkGeofenceStatus();
      print('🔄 백그라운드 서비스 유지: ${activeAlarms}개 알람');
    } catch (e) {
      print('❌ 서비스 유지 실패: $e');
    }
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

  // ✅ 지오펜스 상태 확인
  @pragma('vm:entry-point')
  static Future<void> _checkGeofenceStatus() async {
    try {
      final locationMonitor = LocationMonitorService();

      if (!locationMonitor.isRunning) {
        print('🔄 지오펜스 서비스가 중단됨, 재시작 시도');
        await locationMonitor.startBackgroundMonitoring((type, alarm) {
          print('📱 백그라운드 알람 트리거: ${alarm['name']} ($type)');
          _showBackgroundNativeAlarm(alarm);
        });
      }
    } catch (e) {
      print('⚠️ 지오펜스 상태 확인 실패: $e');
    }
  }

  // ✅ 백그라운드 Native 알람 표시
  @pragma('vm:entry-point')
  static Future<void> _showBackgroundNativeAlarm(
    Map<String, dynamic> alarm,
  ) async {
    try {
      print('📱 백그라운드 Native 알람 표시: ${alarm['name']}');

      const platform = MethodChannel('com.example.ringinout/alarm');
      await platform.invokeMethod('showFullScreenAlarm', {
        'title': alarm['name'],
        'message': '${alarm['place']} 위치 알람',
      });
    } catch (e) {
      print('❌ 백그라운드 Native 알람 실패: $e');
    }
  }
}

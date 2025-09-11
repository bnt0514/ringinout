// lib/services/background_services.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Project imports
import 'package:ringinout/config/constants.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';

class BackgroundServiceManager {
  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Initialize and configure background service
  static Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStart: true,
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

  // ✅ 조용한 알림 설정
  static const String notificationTitle = 'Ringinout';
  static const String notificationContent = '위치 알람 활성화됨';

  // ✅ 알림 설정 개선
  static const bool showOngoing = false;
  static const bool autoCancel = true;
}

/// Background service handler for both platforms
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up Android foreground service
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    // ✅ 최초 시작 시 조용한 알림
    service.setForegroundNotificationInfo(
      title: ServiceConstants.notificationTitle,
      content: ServiceConstants.notificationContent,
    );

    // ✅ 3초 후 알림을 완전히 숨김 (백그라운드 모드)
    Future.delayed(Duration(seconds: 3), () {
      try {
        // 알림을 최소한으로 줄임 (안드로이드 요구사항 때문에 완전 제거는 불가)
        service.setForegroundNotificationInfo(
          title: "", // 빈 제목
          content: "", // 빈 내용
        );
        print('🔕 백그라운드 알림 최소화 완료');
      } catch (e) {
        print('⚠️ 알림 최소화 실패: $e');
      }
    });
  }

  // ✅ 백그라운드 Hive 초기화 (경로 통일)
  await _initializeBackgroundHive();

  // ✅ 위치 모니터링 시작 (알림과 독립적)
  final locationMonitor = LocationMonitorService();
  await locationMonitor.startBackgroundMonitoring((type, alarm) async {
    // 백그라운드 알람 트리거
    print('🚨 백그라운드 알람: ${alarm['name']} ($type)');

    // 네이티브 전체화면 + 벨소리
    await AlarmNotificationHelper.showNativeAlarm(
      title: alarm['name'] ?? '위치 알람',
      message: type == 'entry' ? '도착했습니다!' : '출발했습니다!',
    );
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

    // ✅ 메인 앱과 완전히 동일한 경로 사용
    final directory = await getApplicationDocumentsDirectory();
    final uniquePath = '${directory.path}/ringinout_unique_v3';
    final uniqueDir = Directory(uniquePath);

    if (!await uniqueDir.exists()) {
      await uniqueDir.create(recursive: true);
      print('📁 백그라운드 고유 디렉토리 생성: $uniquePath');
    }

    // ✅ Hive 초기화 (Flutter 의존성 없는 방식)
    Hive.init(uniquePath);
    print('📦 백그라운드 Hive 경로 설정: $uniquePath');

    // ✅ 메인 앱과 동일한 박스명 사용 (버전 포함)
    await _openBoxSafely('savedLocations_v2');
    await _openBoxSafely('locationAlarms_v2');
    await _openBoxSafely('settings_v2');

    print('✅ 백그라운드 Hive 초기화 완료');

    // ✅ 데이터 확인 로그
    await _logBackgroundData();
  } catch (e) {
    print('❌ 백그라운드 Hive 초기화 실패: $e');
    rethrow;
  }
}

/// ✅ 안전한 박스 열기
Future<void> _openBoxSafely(String boxName) async {
  try {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
      print('📦 백그라운드 $boxName 박스 열기 완료');
    } else {
      print('📦 백그라운드 $boxName 박스 이미 열려있음');
    }
  } catch (e) {
    print('❌ 백그라운드 $boxName 박스 열기 실패: $e');
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

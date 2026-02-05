// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:firebase_core/firebase_core.dart';

// Project imports
import 'package:ringinout/app/app.dart';
import 'package:ringinout/config/initializer.dart';
import 'package:ringinout/features/navigation/navigation_state.dart';
import 'package:ringinout/features/alarm/alarm_controller.dart';
import 'package:ringinout/services/locale_provider.dart';
import 'package:ringinout/firebase_options.dart';

import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/test_controller.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/services/smart_location_monitor.dart'; // ✅ 추가

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 네이버맵 초기화 (flutter_naver_map 최신 API)
  await FlutterNaverMap().init(
    clientId: 'k68ej9xnz7',
    onAuthFailed: (ex) => print('네이버맵 인증 실패: $ex'),
  );

  // 앱 초기화
  await AppInitializer.initialize();

  // AlarmController 생성 및 초기화
  final alarmController = AlarmController();
  await alarmController.initialize();

  // ✅ TestGeofenceController 생성 및 초기화
  final testGeofenceController = TestGeofenceController();

  // ✅ 지연 초기화 (UI가 준비된 후)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    testGeofenceController.initialize();
  });

  // ✅ 하나의 navigatorKey만 사용 (통일)
  final globalNavigatorKey = LocationMonitorService.navigatorKey;

  // ✅ AlarmNotificationHelper에 같은 키 설정
  AlarmNotificationHelper.setNavigatorKey(globalNavigatorKey);

  print('🔑 NavigatorKey 통일 설정 완료');

  // ✅ SmartLocationMonitor는 메인 앱용만 (백그라운드 중복 방지)
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(seconds: 2)); // UI 안정화 대기

    // 메인 앱에서만 SmartLocationMonitor 시작 (중복 방지)
    await SmartLocationMonitor.startSmartMonitoring();
  });

  // 앱 실행
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationState()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider.value(value: alarmController),
        ChangeNotifierProvider.value(value: testGeofenceController),
      ],
      child: RinginoutApp(navigatorKey: globalNavigatorKey),
    ),
  );
}

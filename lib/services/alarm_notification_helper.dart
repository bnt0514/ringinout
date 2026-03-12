// lib/services/alarm_notification_helper.dart
// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Package imports:
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// App imports:
import '../pages/full_screen_alarm_page.dart';
import '../app/app.dart';
import 'dart:typed_data';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ 기존 함수들 그대로 유지
Future<void> createNotificationChannel() async {
  final androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  // 1. 알람 알림 채널 (높은 우선순위)
  const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
    'ringinout_channel',
    'Ringinout 알람',
    description: '위치 기반 알림 채널',
    importance: Importance.max,
  );
  await androidPlugin?.createNotificationChannel(alarmChannel);

  // 2. ✅ 백그라운드 서비스 알림 채널 (조용한 모드)
  const AndroidNotificationChannel backgroundChannel =
      AndroidNotificationChannel(
        'ringinout_background_quiet',
        'Ringinout 백그라운드 서비스',
        description: '위치 기반 알람 서비스',
        importance: Importance.low, // 조용한 알림
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
  await androidPlugin?.createNotificationChannel(backgroundChannel);
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  // ✅ 알림 터치 콜백 추가
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );
}

// ✅ 알림 터치 시 전체화면으로 이동
Future<void> _onNotificationTapped(NotificationResponse response) async {
  if (response.payload != null) {
    try {
      final alarmData = jsonDecode(response.payload!);
      print('📱 푸쉬 알림 터치됨: ${alarmData['name']}');

      // 전체화면 알람으로 이동
      AlarmNotificationHelper._showFullScreenAlarm(
        title: alarmData['name'] ?? '위치 알람',
        message: '알람을 확인하세요',
        alarmData: alarmData,
      );
    } catch (e) {
      print('❌ 알림 터치 처리 실패: $e');
    }
  }
}

Future<void> cancelAllAlarmNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
}

class AlarmNotificationHelper {
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // ✅ 기존 메인 진입점 (테스트용)
  static Future<void> showNativeAlarm({
    required String title,
    required String message,
    String sound = 'default',
    bool vibrate = true,
    Map<String, dynamic>? alarmData, // ✅ alarmData 추가
  }) async {
    try {
      print('🔔 네이티브 알람 시작: $title');

      // 1. 즉시 네이티브 전체화면 (최우선)
      await _showNativeFullScreenAlarm(title, message, alarmData);

      // 2. 기존 벨소리 채널로 사운드 재생
      await _playSystemRingtone();

      // ✅ 3. Flutter 전체화면 알람 표시 제거 (중복 방지)
      // Native에서 이미 전체화면을 표시하므로 Flutter에서는 표시하지 않음
      // _showFullScreenAlarm(...) 제거

      // ✅ 4. 네이티브 안드로이드 알림 제거 (이미 영구 푸쉬 알림이 있으므로 불필요)
      // await _showNativeAndroidAlarm(title, message, vibrate);
    } catch (e) {
      print('❌ 네이티브 알람 실패: $e');
    }
  }

  // showPersistentAlarmNotification 메서드 수정

  static Future<void> showPersistentAlarmNotification({
    required String title,
    required String body,
    required Map<String, dynamic> alarmData,
  }) async {
    try {
      await initializeNotifications();

      print('📢 영구 푸쉬 알림 생성 시작: $title');

      const androidDetails = AndroidNotificationDetails(
        'persistent_alarm_channel',
        'Persistent Location Alarms',
        channelDescription: '영구 위치 알람 (터치 시 전체화면)',
        importance: Importance.max,
        priority: Priority.high,

        // ✅ 영구 알림 설정
        ongoing: true, // 지속적 알림 (스와이프로 삭제 불가)
        autoCancel: false, // 자동 삭제 불가
        // ✅ 알람 특성
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true, // 전체화면 시도
        visibility: NotificationVisibility.public,

        // ✅ 사운드/진동 (별도로 처리하므로 false)
        playSound: false, // 사운드는 _triggerAlarm에서 처리
        enableVibration: false, // 진동도 _triggerAlarm에서 처리
        // ❌ 액션 버튼 제거 (터치만으로 전체화면 이동)
        // actions: [], // 완전히 제거

        // ✅ 스타일링
        icon: '@mipmap/ic_launcher',
        color: Color(0xFF2196F3),
        ledColor: Color(0xFFFF0000),
        ledOnMs: 1000,
        ledOffMs: 500,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      // ✅ 고정 ID 사용 (기존 알람 덮어쓰기)
      const persistentAlarmId = 999;

      await flutterLocalNotificationsPlugin.show(
        persistentAlarmId,
        title,
        body,
        notificationDetails,
        payload: jsonEncode(alarmData), // ✅ 터치 시 전달할 데이터
      );

      print('✅ 영구 푸쉬 알림 생성 완료 (버튼 없음, 터치로 전체화면): $title');
      print('📝 페이로드: ${jsonEncode(alarmData)}');
    } catch (e) {
      print('❌ 영구 푸쉬 알림 생성 실패: $e');
      rethrow;
    }
  }

  // ✅ 영구 알림 제거
  static Future<void> dismissPersistentAlarm() async {
    try {
      await flutterLocalNotificationsPlugin.cancel(999);
      print('✅ 영구 푸쉬 알림 제거됨');
    } catch (e) {
      print('❌ 영구 푸쉬 알림 제거 실패: $e');
    }
  }

  // ✅ 네이티브 전체화면
  static Future<void> _showNativeFullScreenAlarm(
    String title,
    String message,
    Map<String, dynamic>? alarmData, // ✅ alarmData 추가
  ) async {
    try {
      const platform = MethodChannel('com.example.ringinout/alarm');

      // ✅ alarmId 추출
      final alarmId = alarmData?['id'] ?? -1;

      await platform.invokeMethod('showFullScreenAlarm', {
        'title': title,
        'message': message,
        'alarmId': alarmId, // ✅ alarmId 전달
        'placeId':
            alarmData?['id']?.toString() ?? '', // ✅ placeId 전달 (passing버튼용)
      });
      print('📱 네이티브 전체화면 알람 요청 완료 (ID: $alarmId)');
    } catch (e) {
      print('❌ 네이티브 전체화면 실패: $e');
    }
  }

  // ✅ 시스템 벨소리 재생
  static Future<void> _playSystemRingtone() async {
    try {
      const platform = MethodChannel('flutter.bell');
      await platform.invokeMethod('playSystemRingtone');
      print('🔊 시스템 벨소리 재생 시작');
    } catch (e) {
      print('❌ 시스템 벨소리 재생 실패: $e');
    }
  }

  // ✅ 벨소리 정지
  static Future<void> _stopSystemRingtone() async {
    try {
      const platform = MethodChannel('flutter.bell');
      await platform.invokeMethod('stopSystemRingtone');
      print('🔕 시스템 벨소리 정지');
    } catch (e) {
      print('❌ 시스템 벨소리 정지 실패: $e');
    }
  }

  // ✅ 네이티브 안드로이드 알림 (기존 테스트용)
  static Future<void> _showNativeAndroidAlarm(
    String title,
    String message,
    bool vibrate,
  ) async {
    await initializeNotifications();

    final vibrationPattern =
        vibrate ? Int64List.fromList([0, 1000, 500, 1000]) : null;

    final androidDetails = AndroidNotificationDetails(
      'native_alarm_channel',
      'Native Alarm Channel',
      channelDescription: '네이티브 알람 채널',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: false,
      enableVibration: vibrate,
      vibrationPattern: vibrationPattern,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'stop_alarm',
          '알람 끄기',
          cancelNotification: true,
        ),
      ],
      icon: '@mipmap/ic_launcher',
    );

    final details = NotificationDetails(android: androidDetails);
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      message,
      details,
    );

    // 10초 후 자동 해제
    Future.delayed(Duration(seconds: 10), () async {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
    });
  }

  // ✅ 전체화면 알람 (수정됨)
  static void _showFullScreenAlarm({
    required String title,
    required String message,
    String sound = 'default',
    required Map<String, dynamic> alarmData,
  }) {
    try {
      _navigatorKey?.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (context) => FullScreenAlarmPage(
                alarmTitle: title,
                alarmData: alarmData,
                soundPath: sound,
                onDismiss: () async {
                  // ✅ 알람 끄기 시 모든 관련 요소 정지
                  await _stopSystemRingtone();
                  await dismissPersistentAlarm(); // ✅ 영구 알림도 제거
                  await cancelAllAlarmNotifications();
                  print('🔕 전체화면 알람 + 벨소리 + 영구알림 모두 정지');
                },
              ),
        ),
        (route) => false, // ✅ 모든 기존 화면 제거
      );

      print('📱 전체화면 알람 표시: $title');
    } catch (e) {
      print('❌ 전체화면 알람 실패: $e');
    }
  }
}

// ✅ 기존 테스트용 알림 표시 (그대로 유지)
Future<void> _showTestNotification(String title, String message) async {
  const androidDetails = AndroidNotificationDetails(
    'test_alarm_channel',
    'Test Alarms',
    channelDescription: 'Notifications for test alarms',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    enableVibration: true,
    playSound: true,
    icon: '@mipmap/ic_launcher',
  );

  const details = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    message,
    details,
  );
}

// lib/services/alarm_notification_helper.dart
// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'ringinout_channel',
    'Ringinout 알람',
    description: '위치 기반 알림 채널',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

Future<void> cancelAllAlarmNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
}

// lib/services/alarm_notification_helper.dart

class AlarmNotificationHelper {
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // ✅ 메인 진입점 - 순서 수정
  static Future<void> showNativeAlarm({
    required String title,
    required String message,
    String sound = 'default',
    bool vibrate = true,
  }) async {
    try {
      print('🔔 네이티브 알람 시작: $title');

      // 1. 즉시 네이티브 전체화면 (최우선)
      await _showNativeFullScreenAlarm(title, message);

      // 2. 기존 벨소리 채널로 사운드 재생
      await _playSystemRingtone();

      // 3. Flutter 전체화면 알람 표시 (백업용)
      _showFullScreenAlarm(title: title, message: message, sound: sound);

      // 4. 네이티브 안드로이드 알림 (사운드 없이)
      await _showNativeAndroidAlarm(title, message, vibrate);
    } catch (e) {
      print('❌ 네이티브 알람 실패: $e');
    }
  }

  // ✅ 새로 추가할 메서드 (여기에 추가!)
  static Future<void> _showNativeFullScreenAlarm(
    String title,
    String message,
  ) async {
    try {
      const platform = MethodChannel('com.example.ringinout/alarm');
      await platform.invokeMethod('showFullScreenAlarm', {
        'title': title,
        'message': message,
      });
      print('📱 네이티브 전체화면 알람 요청 완료');
    } catch (e) {
      print('❌ 네이티브 전체화면 실패: $e');
    }
  }

  // ✅ 기존 flutter.bell 채널 사용
  static Future<void> _playSystemRingtone() async {
    try {
      const platform = MethodChannel('flutter.bell');
      await platform.invokeMethod('playSystemRingtone');
      print('🔊 시스템 벨소리 재생 시작');
    } catch (e) {
      print('❌ 시스템 벨소리 재생 실패: $e');
    }
  }

  // ✅ 벨소리 정지 메서드
  static Future<void> _stopSystemRingtone() async {
    try {
      const platform = MethodChannel('flutter.bell');
      await platform.invokeMethod('stopSystemRingtone');
      print('🔕 시스템 벨소리 정지');
    } catch (e) {
      print('❌ 시스템 벨소리 정지 실패: $e');
    }
  }

  // ✅ 네이티브 안드로이드 알림만 처리 (사운드 제거)
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

      // ✅ 사운드 제거 (벨소리는 별도 재생)
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

  // ✅ 전체화면 알람 (벨소리 정지 추가)
  static void _showFullScreenAlarm({
    required String title,
    required String message,
    String sound = 'default',
  }) {
    try {
      _navigatorKey?.currentState?.push(
        MaterialPageRoute(
          builder:
              (context) => FullScreenAlarmPage(
                alarmTitle: title,
                alarmData: {'id': DateTime.now().millisecondsSinceEpoch},
                soundPath: sound,
                onDismiss: () async {
                  // ✅ 알람 끄기 시 벨소리도 정지
                  await _stopSystemRingtone();
                  await cancelAllAlarmNotifications();
                  print('🔕 전체화면 알람 + 벨소리 정지');
                },
              ),
        ),
      );

      print('📱 전체화면 알람 표시: $title');
    } catch (e) {
      print('❌ 전체화면 알람 실패: $e');
    }
  }

  // ✅ 불필요한 메서드들 제거
  // _playSystemAlarmSound() - 삭제 (중복)
  // showFullScreenAlarm() - _showFullScreenAlarm()으로 통합
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

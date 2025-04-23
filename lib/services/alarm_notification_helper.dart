import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      switch (response.actionId) {
        case 'CONFIRM':
          print('🔕 알람 확인됨');
          if (response.id == 1) {
            print('🧠 피드백 창 예정');
          }
          break;
        case 'SNOOZE':
          print('⏰ 다시 울림 선택됨');
          break;
        default:
          print('🔔 일반 알림 클릭됨');
      }
    },
  );
}

Future<void> showAlarmNotification(
  String title,
  String body, {
  int id = 0,
}) async {
  final actions =
      id == 0
          ? [AndroidNotificationAction('CONFIRM', '확인')]
          : [
            AndroidNotificationAction('CONFIRM', '확인'),
            AndroidNotificationAction('SNOOZE', '다시 울림'),
          ];

  final androidDetails = AndroidNotificationDetails(
    'ringinout_channel',
    'Ringinout 알람',
    channelDescription: '위치 기반 알람 알림',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true, // ✅ 핵심: 앱 상태 관계없이 알림 띄움
    actions: actions,
  );

  final notificationDetails = NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.show(
    id,
    title,
    body,
    notificationDetails,
  );
}

Future<void> cancelAllAlarmNotifications() async {
  await flutterLocalNotificationsPlugin.cancelAll();
}

Future<void> showSilentAlarmNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'ringinout_channel',
    'Ringinout 알람',
    channelDescription: '무음 알람',
    importance: Importance.high,
    priority: Priority.high,
    playSound: false,
    enableVibration: false,
    visibility: NotificationVisibility.public,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    1,
    title,
    body,
    notificationDetails,
  );
}

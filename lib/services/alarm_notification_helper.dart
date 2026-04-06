// lib/services/alarm_notification_helper.dart
// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

// Package imports:
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// App imports:
import '../pages/full_screen_alarm_page.dart';

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
        'RingInOut 백그라운드 서비스',
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

  // ✅ 메인 알람 진입점 — 코틀린 네이티브 전체화면 알람 표시
  static Future<void> showNativeAlarm({
    required String title,
    required String message,
    String sound = 'default',
    bool vibrate = true,
    Map<String, dynamic>? alarmData,
  }) async {
    try {
      print('🔔 네이티브 알람 시작: $title');

      // 네이티브 전체화면 (벨소리는 AlarmFullscreenActivity에서 직접 재생)
      await _showNativeFullScreenAlarm(title, message, alarmData);
    } catch (e) {
      print('❌ 네이티브 알람 실패: $e');
      // 폴백: 푸시 알림
      try {
        final isEntry = (alarmData?['trigger'] ?? '') != 'exit';
        final placeName = alarmData?['place'] ?? '지정 장소';
        await showPersistentAlarmNotification(
          title: '🚨 $title',
          body: isEntry ? '$placeName에 도착했습니다!' : '$placeName에서 벗어났습니다!',
          alarmData: alarmData ?? {},
        );
      } catch (e2) {
        print('❌ 폴백 알림도 실패: $e2');
      }
    }
  }

  // ✅ 네이티브 전체화면 알람 호출
  static Future<void> _showNativeFullScreenAlarm(
    String title,
    String message,
    Map<String, dynamic>? alarmData,
  ) async {
    try {
      const platform = MethodChannel('com.bnt0514.ringinout/alarm');
      final alarmId = alarmData?['id'] ?? -1;

      // ✅ repeat 필드가 List이면 반복 알람
      final repeat = alarmData?['repeat'];
      final isRepeat = (repeat is List && repeat.isNotEmpty);

      await platform.invokeMethod('showFullScreenAlarm', {
        'title': title,
        'message': message,
        'alarmId': alarmId,
        'alarmKey': alarmData?['id']?.toString() ?? '',
        'placeId': alarmData?['placeId']?.toString() ?? '',
        'isRepeat': isRepeat,
      });
      print('📱 네이티브 전체화면 알람 요청 완료 (ID: $alarmId)');
    } catch (e) {
      print('❌ 네이티브 전체화면 실패: $e');
      rethrow;
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

  // ✅ 전체화면 알람 (스택 지원 — 여러 알람이 중첩 가능)
  static void _showFullScreenAlarm({
    required String title,
    required String message,
    String sound = 'default',
    required Map<String, dynamic> alarmData,
  }) {
    try {
      // ✅ push 사용 — 기존 알람 화면 위에 새 알람 화면이 스택됨
      _navigatorKey?.currentState?.push(
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
      );

      print('📱 전체화면 알람 표시 (스택): $title');
    } catch (e) {
      print('❌ 전체화면 알람 실패: $e');
    }
  }
}

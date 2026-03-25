import 'package:flutter/services.dart';
import 'package:ringinout/config/constants.dart';

/// Handles all method channel communications for the app
class MethodChannelHandler {
  // Singleton instance
  static final MethodChannelHandler _instance =
      MethodChannelHandler._internal();
  factory MethodChannelHandler() => _instance;
  MethodChannelHandler._internal();

  // Channel instances
  final MethodChannel _audioChannel = const MethodChannel(ChannelNames.audio);
  final MethodChannel _notificationChannel = const MethodChannel(
    ChannelNames.notification,
  );
  final MethodChannel _fullscreenChannel = const MethodChannel(
    ChannelNames.fullscreenNative,
  );
  final MethodChannel _permissionsChannel = const MethodChannel(
    ChannelNames.permissions,
  );

  /// Audio related methods
  Future<void> playAlarmSound() async {
    try {
      await _audioChannel.invokeMethod('playRingtoneLoud');
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }

  Future<void> stopAlarmSound() async {
    try {
      await _audioChannel.invokeMethod('stopRingtone');
    } catch (e) {
      print('🔕 벨소리 정지 실패: $e');
    }
  }

  /// Notification related methods
  Future<void> showFullScreenAlarm(Map<String, dynamic> alarmData) async {
    try {
      await _fullscreenChannel.invokeMethod('launchNativeAlarm', {
        'title': alarmData['name'] ?? 'Ringinout 알람',
        'alarmId': alarmData['id'],
      });
      print('📣 Native AlarmFullscreenActivity 호출 완료');
    } catch (e) {
      print('⚠️ Native AlarmFullscreenActivity 호출 실패: $e');
    }
  }

  /// Permission related methods
  Future<void> requestDndPermission() async {
    try {
      await _permissionsChannel.invokeMethod('requestDndPermission');
    } catch (e) {
      print('⚠️ DND 권한 요청 실패: $e');
    }
  }

  /// Set up method channel handlers
  void setupMethodCallHandler({
    required Function(Map<String, dynamic>) onAlarmReceived,
  }) {
    _notificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'navigateToFullScreenAlarm') {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        onAlarmReceived(args);
      }
    });
  }
}

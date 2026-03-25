import 'package:flutter/services.dart';

class NativeAlarmLauncher {
  static const MethodChannel _channel = MethodChannel('alarm_channel');

  static Future<void> triggerAlarm(int alarmId) async {
    try {
      await _channel.invokeMethod('triggerAlarm', {'alarmId': alarmId});
    } catch (e) {
      print('🔥 Native 알람 실행 실패: $e');
    }
  }
}

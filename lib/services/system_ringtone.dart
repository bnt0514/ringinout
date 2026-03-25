import 'package:flutter/services.dart';

class SystemRingtone {
  static const MethodChannel _channel = MethodChannel('flutter.bell');

  /// 시스템 기본 벨소리 재생 요청
  static Future<void> play() async {
    try {
      await _channel.invokeMethod('playSystemRingtone');
    } catch (e) {
      print('🔔 시스템 벨소리 재생 실패: $e');
    }
  }

  /// 시스템 기본 벨소리 정지 요청
  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopSystemRingtone');
    } catch (e) {
      print('🔕 시스템 벨소리 정지 실패: $e');
    }
  }
}

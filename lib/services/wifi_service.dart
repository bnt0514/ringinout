// lib/services/wifi_service.dart
//
// Flutter ↔ Native Wi-Fi 통신 서비스
// MethodChannel: com.bnt0514.ringinout/wifi

import 'package:flutter/services.dart';

class WifiService {
  static const MethodChannel _channel = MethodChannel(
    'com.bnt0514.ringinout/wifi',
  );

  /// 현재 연결된 Wi-Fi 정보 가져오기
  /// 반환: {ssid: String, bssid: String} 또는 null
  static Future<Map<String, String>?> getConnectedWifi() async {
    try {
      final result = await _channel.invokeMethod('getConnectedWifi');
      if (result == null) return null;
      return Map<String, String>.from(result as Map);
    } catch (e) {
      print('[WifiService] ❌ getConnectedWifi 실패: $e');
      return null;
    }
  }

  /// 현재 연결된 Wi-Fi + SSID 프리픽스 유사 네트워크 목록
  /// 반환: [{ssid, bssid, isConnected, signalLevel}]
  static Future<List<Map<String, dynamic>>> getSimilarNetworks() async {
    try {
      final result = await _channel.invokeMethod('getSimilarNetworks');
      if (result == null) return [];
      return (result as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      print('[WifiService] ❌ getSimilarNetworks 실패: $e');
      return [];
    }
  }

  /// Wi-Fi 하드웨어 활성 상태 확인
  static Future<bool> isWifiEnabled() async {
    try {
      final result = await _channel.invokeMethod('isWifiEnabled');
      return result as bool? ?? false;
    } catch (e) {
      print('[WifiService] ❌ isWifiEnabled 실패: $e');
      return false;
    }
  }
}

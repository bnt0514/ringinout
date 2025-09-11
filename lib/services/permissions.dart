import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:ringinout/config/constants.dart';

class PermissionManager {
  static const MethodChannel _channel = MethodChannel(ChannelNames.permissions);

  /// Request all required permissions
  static Future<void> requestAllPermissions() async {
    await _requestLocationPermissions();
    await _requestNotificationPermissions();
    await _requestSystemPermissions();
  }

  /// Request location permissions
  static Future<void> _requestLocationPermissions() async {
    await Permission.location.request();
    await Permission.locationAlways.request();
    await Permission.activityRecognition.request();
  }

  /// Request notification permissions
  static Future<void> _requestNotificationPermissions() async {
    await Permission.notification.request();
  }

  /// Request system permissions
  static Future<void> _requestSystemPermissions() async {
    await Permission.systemAlertWindow.request();
    await Permission.accessNotificationPolicy.request();
    await _requestDoNotDisturbAccess();
  }

  /// Request DND access
  static Future<void> _requestDoNotDisturbAccess() async {
    try {
      await _channel.invokeMethod('requestDndPermission');
    } catch (e) {
      print('⚠️ DND 권한 요청 실패: $e');
    }
  }

  /// Check location permission status
  static Future<bool> hasLocationPermissions() async {
    final location = await Permission.location.status;
    final background = await Permission.locationAlways.status;
    return location.isGranted && background.isGranted;
  }

  /// Check notification permission status
  static Future<bool> hasNotificationPermissions() async {
    return await Permission.notification.status.isGranted;
  }

  /// Check if all required permissions are granted
  static Future<bool> hasAllRequiredPermissions() async {
    final locationGranted = await hasLocationPermissions();
    final notificationGranted = await hasNotificationPermissions();
    final systemAlertGranted =
        await Permission.systemAlertWindow.status.isGranted;

    return locationGranted && notificationGranted && systemAlertGranted;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

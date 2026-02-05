import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionManager {
  /// Request all required permissions
  static Future<void> requestAllPermissions() async {
    await _requestLocationPermissions();
    await _requestNotificationPermissions();
    await _requestSystemPermissions();
    await _requestBatteryOptimization(); // ✅ 배터리 최적화 해제 추가
  }

  /// Request location permissions
  static Future<void> _requestLocationPermissions() async {
    await ph.Permission.location.request();
    await ph.Permission.locationAlways.request();
    await ph.Permission.activityRecognition.request();
  }

  /// Request notification permissions
  static Future<void> _requestNotificationPermissions() async {
    await ph.Permission.notification.request();
  }

  /// Request system permissions (다른 앱 위에 표시)
  static Future<void> _requestSystemPermissions() async {
    await ph.Permission.systemAlertWindow.request();
  }

  /// ✅ 배터리 최적화 해제 요청 (백그라운드 강제 종료 방지)
  static Future<void> _requestBatteryOptimization() async {
    final status = await ph.Permission.ignoreBatteryOptimizations.status;
    if (!status.isGranted) {
      await ph.Permission.ignoreBatteryOptimizations.request();
    }
  }

  /// ✅ 배터리 최적화 해제 상태 확인
  static Future<bool> isBatteryOptimizationDisabled() async {
    return await ph.Permission.ignoreBatteryOptimizations.status.isGranted;
  }

  /// Check location permission status
  static Future<bool> hasLocationPermissions() async {
    final location = await ph.Permission.location.status;
    final background = await ph.Permission.locationAlways.status;
    return location.isGranted && background.isGranted;
  }

  /// Check notification permission status
  static Future<bool> hasNotificationPermissions() async {
    return await ph.Permission.notification.status.isGranted;
  }

  /// Check if all required permissions are granted
  static Future<bool> hasAllRequiredPermissions() async {
    final locationGranted = await hasLocationPermissions();
    final notificationGranted = await hasNotificationPermissions();
    final systemAlertGranted =
        await ph.Permission.systemAlertWindow.status.isGranted;
    final batteryOptDisabled = await isBatteryOptimizationDisabled(); // ✅ 추가

    return locationGranted &&
        notificationGranted &&
        systemAlertGranted &&
        batteryOptDisabled;
  }

  /// Open app settings
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}

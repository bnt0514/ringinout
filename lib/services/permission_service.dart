import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:ringinout/services/permissions.dart';

class PermissionService {
  /// 모든 필수 권한이 허용되었는지 체크
  static Future<bool> areAllGranted() async {
    return await PermissionManager.hasAllRequiredPermissions();
  }

  /// 모든 권한 요청 (UI 포함)
  static Future<bool> requestAllPermissions(BuildContext context) async {
    await PermissionManager.requestAllPermissions();

    // 배터리 최적화 안내 다이얼로그
    final batteryOptDisabled =
        await PermissionManager.isBatteryOptimizationDisabled();
    if (!batteryOptDisabled && context.mounted) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('배터리 최적화 해제'),
              content: const Text(
                '백그라운드에서 알람이 정상 작동하려면 배터리 최적화를 해제해야 합니다.\n'
                '설정에서 "배터리 최적화" 항목을 찾아 Ringinout을 "최적화 안 함"으로 설정해주세요.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ph.openAppSettings();
                  },
                  child: const Text('설정 열기'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('나중에'),
                ),
              ],
            ),
      );
    }

    return await PermissionManager.hasAllRequiredPermissions();
  }
}

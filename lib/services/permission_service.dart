import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:ringinout/services/app_localizations.dart';
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
              title: Text(
                AppLocalizations.of(context).get('battery_opt_title'),
              ),
              content: Text(
                AppLocalizations.of(context).get('battery_opt_msg'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ph.openAppSettings();
                  },
                  child: Text(
                    AppLocalizations.of(context).get('open_settings_btn'),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppLocalizations.of(context).get('later_btn')),
                ),
              ],
            ),
      );
    }

    return await PermissionManager.hasAllRequiredPermissions();
  }
}

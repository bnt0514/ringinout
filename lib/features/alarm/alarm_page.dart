import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/location_alarm_list.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/services/app_localizations.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage> {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await PermissionManager.hasAllRequiredPermissions();
    if (!hasPermissions) {
      await PermissionManager.requestAllPermissions();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('page_title_alarm')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              AlarmListController.instance?.clearSelection();
              LocationAlarmList.showSortDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              AlarmListController.instance?.clearSelection();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: const LocationAlarmList(),
    );
  }
}

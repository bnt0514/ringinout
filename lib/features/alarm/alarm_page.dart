import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/location_alarm_list.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';
import 'package:ringinout/services/app_localizations.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage>
    with SingleTickerProviderStateMixin {
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

  void _showSortOptions() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('sort_options')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.get('sort_by_time')),
                  onTap: () => Navigator.pop(context, 'time'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: Text(l10n.get('sort_custom')),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringinout 알람'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortOptions),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: const KeepAliveWidget(child: LocationAlarmList()),
    );
  }
}

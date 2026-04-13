// lib/pages/device_alarm_list.dart
//
// 독립형 블루투스 기기 알람 목록 페이지
// - 장소에 종속되지 않는 BT 기기 연결/해제 알람
// - HiveHelper.deviceAlarmBox 사용

import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/app_localizations.dart';
import '../services/hive_helper.dart';

class DeviceAlarmList extends StatefulWidget {
  const DeviceAlarmList({super.key});

  @override
  State<DeviceAlarmList> createState() => _DeviceAlarmListState();
}

class _DeviceAlarmListState extends State<DeviceAlarmList> {
  List<Map<String, dynamic>> _deviceAlarms = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceAlarms();
  }

  void _loadDeviceAlarms() {
    final alarms = HiveHelper.getDeviceAlarms();
    setState(() {
      _deviceAlarms = alarms;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_deviceAlarms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.get('device_alarm_empty'),
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.get('device_alarm_empty_desc'),
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/add_device_alarm',
                );
                if (result == true) _loadDeviceAlarms();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.get('device_alarm_add')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _deviceAlarms.length,
            itemBuilder: (context, index) {
              final alarm = _deviceAlarms[index];
              return _buildDeviceAlarmCard(alarm, index);
            },
          ),
        ),
        _buildFixedAddBar(),
      ],
    );
  }

  Widget _buildDeviceAlarmCard(Map<String, dynamic> alarm, int index) {
    final l10n = AppLocalizations.of(context);
    final deviceName = (alarm['deviceName'] ?? '').toString();
    final macAddress = (alarm['macAddress'] ?? '').toString();
    final alarmName = (alarm['name'] ?? deviceName).toString();
    final triggerType = (alarm['triggerType'] ?? 'connect').toString();
    final enabled = alarm['enabled'] as bool? ?? true;

    final isConnect = triggerType == 'connect';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              enabled
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ListTile(
              leading: Icon(
                isConnect
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: enabled ? AppColors.primary : AppColors.textSecondary,
              ),
              title: Text(
                alarmName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: enabled ? null : AppColors.textSecondary,
                ),
              ),
              subtitle: Text(
                '${isConnect ? l10n.get('device_trigger_connect') : l10n.get('device_trigger_disconnect')} · $macAddress',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/add_device_alarm',
                  arguments: {'editAlarm': alarm},
                );
                if (result == true) _loadDeviceAlarms();
              },
              onLongPress: () {
                final id = alarm['id']?.toString() ?? '';
                if (id.isNotEmpty) _showDeleteDialog(id, alarmName);
              },
            ),
          ),
          _buildEnableSwitch(alarm, index),
        ],
      ),
    );
  }

  Widget _buildEnableSwitch(Map<String, dynamic> alarm, int index) {
    final enabled = alarm['enabled'] as bool? ?? true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final willEnable = !enabled;
        alarm['enabled'] = willEnable;
        final id = alarm['id']?.toString() ?? '';
        if (id.isNotEmpty) {
          await HiveHelper.updateDeviceAlarm(id, alarm);
        }
        _loadDeviceAlarms();
      },
      child: Container(
        width: 64,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.divider)),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: enabled ? AppColors.active : AppColors.inactive,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: enabled ? 20 : 12,
                height: enabled ? 20 : 12,
                decoration: const BoxDecoration(
                  color: AppColors.toggleThumb,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedAddBar() {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.pushNamed(
                context,
                '/add_device_alarm',
              );
              if (result == true) _loadDeviceAlarms();
            },
            icon: const Icon(Icons.bluetooth_searching, size: 20),
            label: Text(l10n.get('add_device_alarm_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(String id, String name) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('delete')),
            content: Text('$name\n${l10n.get('device_alarm_delete_confirm')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await HiveHelper.deleteDeviceAlarm(id);
                  _loadDeviceAlarms();
                },
                child: Text(
                  l10n.get('delete'),
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
    );
  }
}

// lib/pages/my_devices_page.dart
//
// 내 기기 관리 페이지
// - HiveHelper.myDevicesBox 기반 등록 기기 관리
// - 페어링된 BT 기기 탐색 → 커스텀 명칭 지정 → 저장
// - 편집/삭제/새 알람 추가 지원
// - 롱프레스 → 선택 모드

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../config/app_theme.dart';
import '../services/app_localizations.dart';
import '../services/hive_helper.dart';

class MyDevicesPage extends StatefulWidget {
  const MyDevicesPage({super.key});

  @override
  State<MyDevicesPage> createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends State<MyDevicesPage> {
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder(
      valueListenable: HiveHelper.myDevicesBox.listenable(),
      builder: (context, Box box, _) {
        final devices = HiveHelper.getMyDevices();

        if (devices.isEmpty) {
          // 선택 모드 해제 (기기 모두 삭제 시)
          if (isSelectionMode) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                isSelectionMode = false;
                selectedIndexes.clear();
              });
            });
          }
          return _buildEmptyState(l10n);
        }

        return Column(
          children: [
            if (isSelectionMode) _buildSelectionBar(l10n, devices),
            Expanded(child: _buildDeviceList(devices, l10n)),
            if (!isSelectionMode) _buildFixedAddBar(l10n),
          ],
        );
      },
    );
  }

  Widget _buildSelectionBar(
    AppLocalizations l10n,
    List<Map<String, dynamic>> devices,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed:
                () => setState(() {
                  isSelectionMode = false;
                  selectedIndexes.clear();
                }),
          ),
          Text(
            '${selectedIndexes.length}${l10n.get('selected_count_suffix')}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              final devices = HiveHelper.getMyDevices();
              setState(() {
                if (selectedIndexes.length == devices.length) {
                  selectedIndexes.clear();
                } else {
                  selectedIndexes = Set<int>.from(
                    List.generate(devices.length, (i) => i),
                  );
                }
              });
            },
            child: Text(
              selectedIndexes.length == devices.length
                  ? l10n.get('deselect_all')
                  : l10n.get('select_all'),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.delete, color: AppColors.danger),
            onPressed:
                selectedIndexes.isEmpty
                    ? null
                    : () => _showBulkDeleteDialog(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.get('my_devices_empty'),
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.get('my_devices_empty_desc'),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDeviceDialog(),
            icon: const Icon(Icons.add),
            label: Text(l10n.get('my_devices_add')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
    List<Map<String, dynamic>> devices,
    AppLocalizations l10n,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: devices.length,
      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1),
      itemBuilder: (context, index) {
        final device = devices[index];
        return _buildDeviceCard(device, index, l10n);
      },
    );
  }

  Widget _buildDeviceCard(
    Map<String, dynamic> device,
    int index,
    AppLocalizations l10n,
  ) {
    final customName = (device['customName'] ?? '').toString();
    final originalName = (device['originalName'] ?? '').toString();
    final mac = (device['macAddress'] ?? '').toString();
    final displayName = customName.isNotEmpty ? customName : originalName;
    final isSelected = selectedIndexes.contains(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color:
            isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.divider.withValues(alpha: 0.5),
        ),
      ),
      child: ListTile(
        leading:
            isSelectionMode
                ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(index),
                  activeColor: AppColors.primary,
                )
                : Icon(Icons.bluetooth, color: AppColors.primary),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (customName.isNotEmpty && originalName.isNotEmpty)
              Text(
                '${l10n.get('my_devices_original_name')}: $originalName',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            Text(
              mac,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
        onTap: () {
          if (isSelectionMode) {
            _toggleSelection(index);
          }
        },
        onLongPress: () {
          if (!isSelectionMode) {
            setState(() {
              isSelectionMode = true;
              selectedIndexes.add(index);
            });
          }
        },
        trailing:
            isSelectionMode
                ? null
                : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditNameDialog(device);
                    } else if (value == 'add_alarm') {
                      _navigateToAddDeviceAlarm(device);
                    } else if (value == 'delete') {
                      _showDeleteDialog(device, displayName);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(l10n.get('edit_device_menu')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'add_alarm',
                          child: Row(
                            children: [
                              Icon(
                                Icons.alarm_add,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.get('add_device_alarm_menu')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 18,
                                color: AppColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.get('delete'),
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
      ),
    );
  }

  void _toggleSelection(int index) {
    setState(() {
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
        if (selectedIndexes.isEmpty) isSelectionMode = false;
      } else {
        selectedIndexes.add(index);
      }
    });
  }

  void _navigateToAddDeviceAlarm(Map<String, dynamic> device) {
    Navigator.pushNamed(
      context,
      '/add_device_alarm',
      arguments: {'preSelectedDevice': device},
    );
  }

  Widget _buildFixedAddBar(AppLocalizations l10n) {
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
            onPressed: _showAddDeviceDialog,
            icon: const Icon(Icons.bluetooth_searching, size: 20),
            label: Text(l10n.get('my_devices_add')),
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

  void _showAddDeviceDialog() {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    Map<String, dynamic>? selectedDevice;
    List<Map<String, dynamic>> bondedDevices = [];
    bool isLoading = true;

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              if (isLoading) {
                _loadBondedDevices().then((devices) {
                  setDialogState(() {
                    bondedDevices = devices;
                    isLoading = false;
                  });
                });
              }

              return AlertDialog(
                title: Text(l10n.get('my_devices_add_title')),
                content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.get('device_alarm_select_device'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isLoading)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (bondedDevices.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.get('bt_no_bonded_devices'),
                              style: TextStyle(color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...bondedDevices.map((device) {
                            final mac = device['macAddress'] ?? '';
                            final name = device['name'] ?? mac;
                            final alreadySaved = HiveHelper.hasMyDevice(mac);
                            return RadioListTile<String>(
                              title: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      alreadySaved
                                          ? AppColors.textSecondary
                                          : null,
                                ),
                              ),
                              subtitle: Text(
                                alreadySaved
                                    ? '$mac (${l10n.get('my_devices_source_manual')})'
                                    : mac,
                                style: const TextStyle(fontSize: 11),
                              ),
                              value: mac,
                              groupValue: selectedDevice?['macAddress'],
                              dense: true,
                              onChanged:
                                  alreadySaved
                                      ? null
                                      : (value) {
                                        setDialogState(() {
                                          selectedDevice = device;
                                          if (nameController.text.isEmpty) {
                                            nameController.text = name;
                                          }
                                        });
                                      },
                            );
                          }),
                        const Divider(),
                        Text(
                          l10n.get('my_devices_custom_name_label'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: l10n.get('my_devices_custom_name_hint'),
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                        if (selectedDevice != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${l10n.get('my_devices_original_name')}: ${selectedDevice!['name'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.get('cancel')),
                  ),
                  ElevatedButton(
                    onPressed:
                        selectedDevice == null
                            ? null
                            : () async {
                              final customName = nameController.text.trim();
                              await HiveHelper.saveMyDevice({
                                'macAddress':
                                    selectedDevice!['macAddress'] ?? '',
                                'originalName': selectedDevice!['name'] ?? '',
                                'customName':
                                    customName.isNotEmpty
                                        ? customName
                                        : selectedDevice!['name'] ?? '',
                              });
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            },
                    child: Text(l10n.get('save')),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showEditNameDialog(Map<String, dynamic> device) {
    final l10n = AppLocalizations.of(context);
    final mac = (device['macAddress'] ?? '').toString();
    final currentName =
        (device['customName'] ?? device['originalName'] ?? '').toString();
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.get('my_devices_edit_name')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.get('my_devices_original_name')}: ${device['originalName'] ?? ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: l10n.get('my_devices_custom_name_label'),
                    hintText: l10n.get('my_devices_custom_name_hint'),
                    border: const OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.get('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    final updated = Map<String, dynamic>.from(device);
                    updated['customName'] = newName;
                    await HiveHelper.updateMyDevice(mac, updated);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child: Text(l10n.get('save')),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> device, String displayName) {
    final l10n = AppLocalizations.of(context);
    final mac = (device['macAddress'] ?? '').toString();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.get('delete')),
            content: Text(
              '$displayName\n${l10n.get('my_devices_delete_confirm')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await HiveHelper.deleteMyDevice(mac);
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

  void _showBulkDeleteDialog(AppLocalizations l10n) {
    final devices = HiveHelper.getMyDevices();
    final count = selectedIndexes.length;
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.get('delete')),
            content: Text(
              '${count}${l10n.get('selected_count_suffix')}\n${l10n.get('my_devices_delete_confirm')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final sortedIndexes =
                      selectedIndexes.toList()..sort((a, b) => b.compareTo(a));
                  for (final idx in sortedIndexes) {
                    if (idx < devices.length) {
                      final mac = (devices[idx]['macAddress'] ?? '').toString();
                      if (mac.isNotEmpty) {
                        await HiveHelper.deleteMyDevice(mac);
                      }
                    }
                  }
                  setState(() {
                    isSelectionMode = false;
                    selectedIndexes.clear();
                  });
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

  Future<List<Map<String, dynamic>>> _loadBondedDevices() async {
    try {
      const channel = MethodChannel('ringinout_channel');
      final result = await channel.invokeMethod('getBondedBluetoothDevices');
      final List<dynamic> devices = result as List<dynamic>? ?? [];
      return devices.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    } catch (e) {
      debugPrint('❌ getBondedBluetoothDevices 실패: $e');
      return [];
    }
  }
}

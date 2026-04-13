// lib/widgets/bluetooth_selector_widget.dart
//
// 블루투스 기기 선택 위젯 — 페어링된(bonded) BT 기기 목록에서 선택
// Wi-Fi 선택기(wifi_selector_widget.dart)와 동일한 인터페이스 패턴

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_theme.dart';
import '../services/app_localizations.dart';

class BluetoothSelectorWidget extends StatefulWidget {
  /// 이미 선택된 BT 기기 목록 (편집 모드용)
  /// 각 항목: {name: String, macAddress: String, deviceType: int, alias: String}
  final List<Map<String, dynamic>> initialDevices;

  /// 선택 변경 콜백
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const BluetoothSelectorWidget({
    super.key,
    this.initialDevices = const [],
    required this.onChanged,
  });

  @override
  State<BluetoothSelectorWidget> createState() =>
      _BluetoothSelectorWidgetState();
}

class _BluetoothSelectorWidgetState extends State<BluetoothSelectorWidget> {
  static const _channel = MethodChannel('ringinout_channel');

  List<Map<String, dynamic>> _bondedDevices = [];
  Set<String> _selectedMacAddresses = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // 기존 선택 복원
    _selectedMacAddresses =
        widget.initialDevices
            .map((d) => (d['macAddress'] ?? '').toString().toUpperCase())
            .where((mac) => mac.isNotEmpty)
            .toSet();
    _loadBondedDevices();
  }

  /// 네이티브에서 페어링된 BT 기기 목록 조회
  Future<void> _loadBondedDevices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _channel.invokeMethod('getBondedBluetoothDevices');
      final List<dynamic> devices = result as List<dynamic>? ?? [];

      final parsed =
          devices.map((d) => Map<String, dynamic>.from(d as Map)).toList();

      // 이전에 저장했지만 현재 페어링 목록에 없는 기기도 유지 (retained)
      final bondedMacs =
          parsed
              .map((d) => (d['macAddress'] ?? '').toString().toUpperCase())
              .toSet();

      final retainedDevices =
          widget.initialDevices
              .where(
                (d) =>
                    !bondedMacs.contains(
                      (d['macAddress'] ?? '').toString().toUpperCase(),
                    ),
              )
              .map((d) => {...d, 'isRetained': true})
              .toList();

      setState(() {
        _bondedDevices = [...parsed, ...retainedDevices];
        _isLoading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _error = e.message ?? 'BT 기기 조회 실패';
        _isLoading = false;
      });
      // 에러 시 기존 선택된 기기만 표시
      if (widget.initialDevices.isNotEmpty) {
        setState(() {
          _bondedDevices =
              widget.initialDevices
                  .map((d) => {...d, 'isRetained': true})
                  .toList();
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _toggleDevice(String macAddress) {
    setState(() {
      if (_selectedMacAddresses.contains(macAddress)) {
        _selectedMacAddresses.remove(macAddress);
      } else {
        _selectedMacAddresses.add(macAddress);
      }
    });

    // 선택된 기기 정보를 콜백으로 전달
    final selected =
        _bondedDevices
            .where(
              (d) => _selectedMacAddresses.contains(
                (d['macAddress'] ?? '').toString().toUpperCase(),
              ),
            )
            .map(
              (d) => {
                'name': d['name'] ?? '',
                'macAddress': (d['macAddress'] ?? '').toString().toUpperCase(),
                'deviceType': d['deviceType'] ?? 0,
                'alias': d['alias'] ?? '',
              },
            )
            .toList();
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더: 아이콘 + 새로고침
        Row(
          children: [
            const Icon(Icons.bluetooth, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.get('bt_bonded_devices_title'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _isLoading ? null : _loadBondedDevices,
              tooltip: l10n.get('bt_refresh_tooltip'),
            ),
          ],
        ),

        // 설명 텍스트
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.get('bt_selector_description'),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),

        // 로딩 / 에러 / 기기 목록
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null && _bondedDevices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.bluetooth_disabled,
                    size: 32,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.get('bt_permission_needed'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else if (_bondedDevices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                l10n.get('bt_no_bonded_devices'),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ..._bondedDevices.map((device) => _buildDeviceTile(device)),

        // 선택 요약
        if (_selectedMacAddresses.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.getWithArgs('bt_selected_count', {
                'count': _selectedMacAddresses.length.toString(),
              }),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final name = (device['name'] ?? '').toString();
    final macAddress = (device['macAddress'] ?? '').toString().toUpperCase();
    final deviceType = device['deviceType'] as int? ?? 0;
    final isRetained = device['isRetained'] == true;
    final isSelected = _selectedMacAddresses.contains(macAddress);

    // 기기 타입에 따른 아이콘
    IconData icon;
    switch (deviceType) {
      case 1: // CLASSIC
        icon = Icons.bluetooth;
        break;
      case 2: // LE (BLE)
        icon = Icons.bluetooth_searching;
        break;
      case 3: // DUAL
        icon = Icons.bluetooth_connected;
        break;
      default:
        icon = Icons.bluetooth;
    }

    return InkWell(
      onTap: () => _toggleDevice(macAddress),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? macAddress : name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isRetained ? AppColors.textSecondary : null,
                    ),
                  ),
                  if (name.isNotEmpty)
                    Text(
                      macAddress,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (isRetained)
                    Text(
                      AppLocalizations.of(context).get('bt_device_retained'),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleDevice(macAddress),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}

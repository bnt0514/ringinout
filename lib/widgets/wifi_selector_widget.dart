// lib/widgets/wifi_selector_widget.dart
//
// Wi-Fi 네트워크 선택 위젯 (장소 추가/편집 시 사용)
// - 현재 연결된 Wi-Fi + 유사 SSID 목록 표시
// - 체크박스로 선택/해제
// - 선택된 네트워크 목록을 [{ssid, bssid}] 형태로 반환

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/wifi_service.dart';
import '../config/app_theme.dart';

class WifiSelectorWidget extends StatefulWidget {
  /// 기존 선택된 Wi-Fi 네트워크 목록 (편집 시)
  final List<Map<String, dynamic>> initialNetworks;

  /// 선택 변경 콜백
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const WifiSelectorWidget({
    super.key,
    this.initialNetworks = const [],
    required this.onChanged,
  });

  @override
  State<WifiSelectorWidget> createState() => _WifiSelectorWidgetState();
}

class _WifiSelectorWidgetState extends State<WifiSelectorWidget> {
  List<Map<String, dynamic>> _availableNetworks = [];
  Set<String> _selectedBssids = {};
  bool _isLoading = false;
  bool _wifiEnabled = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // 기존 선택된 네트워크의 BSSID를 초기화
    for (final network in widget.initialNetworks) {
      final bssid = network['bssid'] as String? ?? '';
      if (bssid.isNotEmpty) {
        _selectedBssids.add(bssid);
      }
    }

    _scanNetworks();
  }

  /// Wi-Fi SSID 조회에 필요한 권한 확인 및 요청
  Future<void> _ensureWifiPermissions() async {
    // Android 13+: NEARBY_WIFI_DEVICES 필요
    final nearbyWifi = await Permission.nearbyWifiDevices.status;
    if (!nearbyWifi.isGranted) {
      final result = await Permission.nearbyWifiDevices.request();
      if (!result.isGranted) {
        print('[WifiSelector] ⚠️ NEARBY_WIFI_DEVICES 권한 거부됨');
      }
    }

    // ACCESS_FINE_LOCATION도 필요
    final location = await Permission.locationWhenInUse.status;
    if (!location.isGranted) {
      await Permission.locationWhenInUse.request();
    }
  }

  Future<void> _scanNetworks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Wi-Fi SSID 조회에 필요한 권한 확인/요청
      await _ensureWifiPermissions();

      _wifiEnabled = await WifiService.isWifiEnabled();

      if (!_wifiEnabled) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Wi-Fi가 꺼져 있습니다';
        });
        return;
      }

      final networks = await WifiService.getSimilarNetworks();

      // 기존 선택된 네트워크 중 스캔에 없는 것도 목록에 포함
      final scannedBssids = networks.map((n) => n['bssid'] as String).toSet();
      final retained = <Map<String, dynamic>>[];
      for (final existing in widget.initialNetworks) {
        final bssid = existing['bssid'] as String? ?? '';
        if (bssid.isNotEmpty && !scannedBssids.contains(bssid)) {
          retained.add({
            'ssid': existing['ssid'] ?? '',
            'bssid': bssid,
            'isConnected': false,
            'signalLevel': 0,
            'isRetained': true, // 이전에 저장된 네트워크 (현재 미감지)
          });
        }
      }

      setState(() {
        _availableNetworks = [...networks, ...retained];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Wi-Fi 스캔 실패';
      });
    }
  }

  void _toggleNetwork(String bssid, String ssid) {
    setState(() {
      if (_selectedBssids.contains(bssid)) {
        _selectedBssids.remove(bssid);
      } else {
        _selectedBssids.add(bssid);
      }
    });

    // 선택된 네트워크 목록 구성
    final selected = <Map<String, dynamic>>[];
    for (final network in _availableNetworks) {
      final nb = network['bssid'] as String? ?? '';
      if (_selectedBssids.contains(nb)) {
        selected.add({'ssid': network['ssid'] ?? '', 'bssid': nb});
      }
    }
    widget.onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(Icons.wifi, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Wi-Fi 네트워크',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _scanNetworks,
                tooltip: '다시 스캔',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Wi-Fi 연결로 더 정확한 위치 감지를 할 수 있습니다',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),

        // 내용
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (!_wifiEnabled)
          _buildWarningCard('Wi-Fi가 꺼져 있습니다. Wi-Fi를 켜고 다시 시도해주세요.')
        else if (_errorMessage != null)
          _buildWarningCard(_errorMessage!)
        else if (_availableNetworks.isEmpty)
          _buildWarningCard('감지된 Wi-Fi 네트워크가 없습니다.')
        else
          _buildNetworkList(),

        // 선택 요약
        if (_selectedBssids.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedBssids.length}개 네트워크 선택됨',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWarningCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _availableNetworks.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 40,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
              ),
            _buildNetworkTile(_availableNetworks[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkTile(Map<String, dynamic> network) {
    final ssid = network['ssid'] as String? ?? '';
    final bssid = network['bssid'] as String? ?? '';
    final isConnected = network['isConnected'] as bool? ?? false;
    final signalLevel = network['signalLevel'] as int? ?? 0;
    final isRetained = network['isRetained'] as bool? ?? false;
    final isSelected = _selectedBssids.contains(bssid);

    return InkWell(
      onTap: () => _toggleNetwork(bssid, ssid),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Wi-Fi 신호 아이콘
            Icon(
              _getWifiIcon(signalLevel),
              size: 20,
              color:
                  isConnected
                      ? Theme.of(context).colorScheme.primary
                      : (isRetained
                          ? Colors.grey
                          : Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 12),
            // SSID + 상태
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ssid.isEmpty ? '(숨겨진 네트워크)' : ssid,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isConnected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isConnected)
                    Text(
                      '현재 연결됨',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (isRetained)
                    const Text(
                      '이전에 저장됨 (현재 감지 안 됨)',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
            // 체크박스
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleNetwork(bssid, ssid),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getWifiIcon(int level) {
    if (level >= 4) return Icons.wifi;
    if (level >= 3) return Icons.wifi;
    if (level >= 2) return Icons.wifi_2_bar;
    if (level >= 1) return Icons.wifi_1_bar;
    return Icons.wifi_off;
  }
}

// lib/widgets/wifi_selector_widget.dart
//
// Wi-Fi 네트워크 선택 위젯 (장소 추가/편집 시 사용)
// - 현재 연결된 Wi-Fi + 유사 SSID 목록 표시
// - 체크박스로 선택/해제
// - 선택된 네트워크 목록을 [{ssid, bssid}] 형태로 반환

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/wifi_service.dart';
import '../services/app_localizations.dart';
import '../utils/wifi_alarm_settings.dart';

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
  final Set<String> _selectedBssids = {};
  bool _isLoading = false;
  bool _wifiEnabled = true;
  String? _errorMessage;
  bool _didApplyDefaultSelection = false;

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
    _didApplyDefaultSelection = widget.initialNetworks.isNotEmpty;

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
          _errorMessage = 'wifi_disabled';
        });
        return;
      }

      final rawNetworks = await WifiService.getSimilarNetworks();
      Map<String, dynamic>? connectedNetwork;
      for (final network in rawNetworks) {
        if (network['isConnected'] == true) {
          connectedNetwork = network;
          break;
        }
      }
      final connectedSsid = connectedNetwork?['ssid']?.toString() ?? '';
      final networks =
          rawNetworks.map((network) {
            final normalized = Map<String, dynamic>.from(network);
            final ssid = normalized['ssid']?.toString() ?? '';
            final matchReason = normalized['matchReason']?.toString() ?? '';
            normalized['isGuestLike'] =
                matchReason == 'guest_like' ||
                WifiAlarmSettings.isGuestLikeSsid(ssid);
            normalized['isSuggestedSibling'] =
                normalized['isSuggestedSibling'] == true ||
                WifiAlarmSettings.isSuggestedSibling(connectedSsid, ssid);
            return normalized;
          }).toList();

      // 기존 선택된 네트워크 중 스캔에 없는 것도 목록에 포함
      final scannedBssids =
          networks.map((n) => n['bssid']?.toString() ?? '').toSet();
      final retained = <Map<String, dynamic>>[];
      for (final existing in widget.initialNetworks) {
        final bssid = existing['bssid'] as String? ?? '';
        if (bssid.isNotEmpty && !scannedBssids.contains(bssid)) {
          retained.add({
            'ssid': existing['ssid'] ?? '',
            'bssid': bssid,
            'isConnected': false,
            'signalLevel': 0,
            'isSuggestedSibling': false,
            'isGuestLike': false,
            'isRetained': true, // 이전에 저장된 네트워크 (현재 미감지)
          });
        }
      }

      final merged = [...networks, ...retained]..sort(_sortNetworks);
      if (!_didApplyDefaultSelection) {
        for (final network in merged) {
          final bssid = network['bssid']?.toString() ?? '';
          if (bssid.isNotEmpty && network['isConnected'] == true) {
            _selectedBssids.add(bssid);
          }
        }
        _didApplyDefaultSelection = true;
      }

      setState(() {
        _availableNetworks = merged;
        _isLoading = false;
      });
      _emitSelectedNetworks();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'wifi_scan_failed';
      });
    }
  }

  int _sortNetworks(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aConnected = a['isConnected'] == true;
    final bConnected = b['isConnected'] == true;
    if (aConnected != bConnected) return aConnected ? -1 : 1;

    final aRetained = a['isRetained'] == true;
    final bRetained = b['isRetained'] == true;
    if (aRetained != bRetained) return aRetained ? 1 : -1;

    final aSuggested = a['isSuggestedSibling'] == true;
    final bSuggested = b['isSuggestedSibling'] == true;
    if (aSuggested != bSuggested) return aSuggested ? -1 : 1;

    final aSignal = a['signalLevel'] as int? ?? 0;
    final bSignal = b['signalLevel'] as int? ?? 0;
    return bSignal.compareTo(aSignal);
  }

  void _emitSelectedNetworks() {
    final selected = <Map<String, dynamic>>[];
    for (final network in _availableNetworks) {
      final nb = network['bssid']?.toString() ?? '';
      if (_selectedBssids.contains(nb)) {
        selected.add({'ssid': network['ssid'] ?? '', 'bssid': nb});
      }
    }
    widget.onChanged(selected);
  }

  void _toggleNetwork(String bssid, String ssid) {
    setState(() {
      if (_selectedBssids.contains(bssid)) {
        _selectedBssids.remove(bssid);
      } else {
        _selectedBssids.add(bssid);
      }
    });
    _emitSelectedNetworks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(Icons.wifi, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.get('wifi_networks_label'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (!_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _scanNetworks,
                tooltip: l10n.get('wifi_rescan_tooltip'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.get('wifi_description'),
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
          _buildWarningCard(l10n.get('wifi_disabled_detail'))
        else if (_errorMessage != null)
          _buildWarningCard(l10n.get(_errorMessage!))
        else if (_availableNetworks.isEmpty)
          _buildWarningCard(l10n.get('wifi_no_networks'))
        else ...[
          _buildInfoCard(l10n.get('wifi_candidate_notice')),
          const SizedBox(height: 8),
          _buildNetworkList(),
        ],

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
                  l10n.getWithArgs('wifi_networks_selected', {
                    'count': _selectedBssids.length.toString(),
                  }),
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

  Widget _buildInfoCard(String message) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.35,
              ),
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
    final ssid = network['ssid']?.toString() ?? '';
    final bssid = network['bssid']?.toString() ?? '';
    final isConnected = network['isConnected'] as bool? ?? false;
    final signalLevel = network['signalLevel'] as int? ?? 0;
    final isRetained = network['isRetained'] as bool? ?? false;
    final isSuggestedSibling = network['isSuggestedSibling'] as bool? ?? false;
    final isGuestLike = network['isGuestLike'] as bool? ?? false;
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
                    ssid.isEmpty
                        ? AppLocalizations.of(
                          context,
                        ).get('wifi_hidden_network')
                        : ssid,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isConnected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (isConnected)
                    Text(
                      AppLocalizations.of(
                        context,
                      ).get('wifi_currently_connected'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  if (!isConnected && isSuggestedSibling)
                    _buildStatusBadge(
                      AppLocalizations.of(
                        context,
                      ).get('wifi_suggested_sibling'),
                      Theme.of(context).colorScheme.primary,
                    ),
                  if (!isConnected && isGuestLike)
                    _buildStatusBadge(
                      AppLocalizations.of(
                        context,
                      ).get('wifi_guest_like_candidate'),
                      Colors.orange,
                    ),
                  if (isRetained)
                    Text(
                      AppLocalizations.of(context).get('wifi_previously_saved'),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  Widget _buildStatusBadge(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
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

// lib/widgets/map_toggle_button.dart
// 맵 전환 버튼 위젯 (네이버 / 구글 / OSM) — 활성화된 제공자만 표시
// 무료 플랜: 네이버(한국)/구글(해외) 전환 시 월 차감 안내 다이얼로그 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/services/subscription_service.dart';

class MapToggleButton extends StatelessWidget {
  /// 맵 전환 시 추가 동작 (컨트롤러 리셋 등)
  final VoidCallback? onToggle;

  const MapToggleButton({super.key, this.onToggle});

  static const _naverColor = Color(0xFF03C75A);
  static const _googleColor = Color(0xFF4285F4);
  static const _osmColor = Color(0xFFFF6B35);
  static const _trackColor = Color(0x1A000000); // 배경 트랙

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProviderService>(
      builder: (context, mapService, _) {
        // 사용 가능한 제공자 목록 수집 (한국: Naver+OSM, 해외: Google+OSM)
        final available = mapService.availableProviders;

        // 1개뿐이면 토글 의미 없으므로 숨김
        if (available.length <= 1) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 64,
            decoration: BoxDecoration(
              color: _trackColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  available.map((p) {
                    return _SegmentTab(
                      label: _labelFor(p),
                      selected: mapService.provider == p,
                      selectedColor: _colorFor(p),
                      isFirst: available.first == p,
                      isLast: available.last == p,
                      onTap: () => _onTabTap(context, mapService, p),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onTabTap(
    BuildContext context,
    MapProviderService mapService,
    MapProvider p,
  ) async {
    if (mapService.provider == p) return;

    // OSM은 항상 바로 전환 (비용 없음)
    if (p == MapProvider.osm) {
      mapService.setProvider(p);
      onToggle?.call();
      return;
    }

    // 네이버(한국)/구글(해외) 전환 시: 정식 플랜에는 월 한도 적용 (beta free/special 제외)
    final plan = await SubscriptionService.getCurrentPlan();
    final limit = SubscriptionService.mapOpenMonthlyLimit(plan);
    if (limit != null) {
      // beta free/special(null)은 통과. 정식 free=100, plus=300, pro=1000
      final canOpen = await MapUsageService.canOpenMap(provider: p.name);
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context);

      if (!canOpen) {
        // 한도 초과
        await showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text(l10n.get('map_free_limit_exceeded_title')),
                content: Text(
                  l10n.getWithArgs('map_free_limit_exceeded_body', {
                    'limit': '$limit',
                  }),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.get('map_switch_btn_cancel')),
                  ),
                ],
              ),
        );
        return;
      }

      // 한도 내: 차감 안내
      final openCount = await MapUsageService.getMapOpenCount();
      final remaining = limit - openCount;
      if (!context.mounted) return;

      final confirmTitle = l10n.get('map_switch_confirm_title');

      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(confirmTitle),
              content: Text(
                l10n.getWithArgs('map_switch_confirm_body', {
                  'limit': '$limit',
                  'remaining': '$remaining',
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.get('map_switch_btn_cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l10n.get('map_switch_btn_confirm')),
                ),
              ],
            ),
      );

      if (confirmed != true) return;
    }

    if (!context.mounted) return;
    mapService.setProvider(p);
    onToggle?.call();
  }

  static String _labelFor(MapProvider p) {
    switch (p) {
      case MapProvider.naver:
        return 'Naver';
      case MapProvider.google:
        return 'Google';
      case MapProvider.osm:
        return 'OSM';
    }
  }

  static Color _colorFor(MapProvider p) {
    switch (p) {
      case MapProvider.naver:
        return _naverColor;
      case MapProvider.google:
        return _googleColor;
      case MapProvider.osm:
        return _osmColor;
    }
  }
}

class _SegmentTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(13) : Radius.zero,
      bottom: isLast ? const Radius.circular(13) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: radius,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black45,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

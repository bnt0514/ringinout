// lib/widgets/map_toggle_button.dart
// 맵 전환 버튼 위젯 (네이버 / 구글 / OSM) — 활성화된 제공자만 표시
// 무료 플랜: 네이버/구글 전환 시 월 차감 안내 다이얼로그 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    // 네이버/구글 전환 시: 무료 플랜 여부 체크
    final plan = await SubscriptionService.getCurrentPlan();
    if (plan == SubscriptionPlan.free) {
      final canOpen = await MapUsageService.canFreeUserOpenMap(
        provider: p.name,
      );
      if (!context.mounted) return;

      if (!canOpen) {
        // 한도 초과
        await showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text('무료 플랜 제한'),
                content: Text(
                  '이번 달 네이버/구글 지도 오픈 횟수(${kFreeMapOpenLimit}회)를 '
                  '모두 사용했습니다.\n\n'
                  'OSM 지도는 계속 무제한 이용 가능합니다.\n'
                  '제한 없이 사용하려면 유료 플랜으로 업그레이드하세요.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('확인'),
                  ),
                ],
              ),
        );
        return;
      }

      // 한도 내: 차감 안내
      final openCount = await MapUsageService.getFreeUserOpenCount();
      final remaining = kFreeMapOpenLimit - openCount;
      if (!context.mounted) return;

      final providerName = p == MapProvider.naver ? '네이버' : '구글';
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text('$providerName 지도로 전환'),
              content: Text(
                '무료 플랜은 네이버/구글 지도를 월 $kFreeMapOpenLimit회 이용할 수 있습니다.\n\n'
                '남은 횟수: $remaining/$kFreeMapOpenLimit회\n\n'
                '$providerName 지도로 전환하면 1회가 차감됩니다.\n'
                'OSM은 차감 없이 무제한 이용 가능합니다.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('전환'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // 카운트 차감
      await MapUsageService.incrementFreeUserOpenCount(provider: p.name);
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

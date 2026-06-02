// lib/widgets/map_toggle_button.dart
// 맵 전환 버튼 위젯 (네이버 / 구글) — 활성화된 제공자만 표시
// 맵 전환 버튼 위젯 (네이버 / 구글) — 전체 안전 한도 도달 시 무료 사용자만 차단 안내

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';

class MapToggleButton extends StatelessWidget {
  /// 맵 전환 시 추가 동작 (컨트롤러 리셋 등)
  final VoidCallback? onToggle;

  const MapToggleButton({super.key, this.onToggle});

  static const _naverColor = Color(0xFF03C75A);
  static const _googleColor = Color(0xFF4285F4);
  static const _trackColor = Color(0x1A000000); // 배경 트랙

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProviderService>(
      builder: (context, mapService, _) {
        // 사용 가능한 제공자 목록 수집
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

    final canOpen = await MapUsageService.canOpenMap(provider: p.name);
    if (!context.mounted) return;
    if (!canOpen) {
      final l10n = AppLocalizations.of(context);
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(l10n.get('map_free_limit_exceeded_title')),
              content: Text(l10n.get('map_free_limit_exceeded_body')),
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

    mapService.setProvider(p);
    onToggle?.call();
  }

  static String _labelFor(MapProvider p) {
    switch (p) {
      case MapProvider.naver:
        return 'Naver';
      case MapProvider.google:
        return 'Google';
    }
  }

  static Color _colorFor(MapProvider p) {
    switch (p) {
      case MapProvider.naver:
        return _naverColor;
      case MapProvider.google:
        return _googleColor;
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

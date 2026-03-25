// lib/widgets/map_toggle_button.dart
// 맵 전환 버튼 위젯 (네이버 / 구글 / OSM) — 활성화된 제공자만 표시

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/map_provider_service.dart';

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
        // 사용 가능한 제공자 목록 수집
        final available = [
          if (mapService.isNaverAvailable) MapProvider.naver,
          if (mapService.isGoogleAvailable) MapProvider.google,
          MapProvider.osm, // OSM은 항상 포함
        ];

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
                      onTap: () {
                        if (mapService.provider != p) {
                          mapService.setProvider(p);
                          onToggle?.call();
                        }
                      },
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
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

// lib/widgets/unified_map_widget.dart
// 네이버맵 / 구글맵 통합 위젯

import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:provider/provider.dart';
import 'package:ringinout/services/map_provider_service.dart';

/// 통합 좌표
class UnifiedLatLng {
  final double latitude;
  final double longitude;
  UnifiedLatLng(this.latitude, this.longitude);

  NLatLng toNaver() => NLatLng(latitude, longitude);
  gmap.LatLng toGoogle() => gmap.LatLng(latitude, longitude);
}

/// 통합 맵 컨트롤러
class UnifiedMapController {
  NaverMapController? _naverController;
  gmap.GoogleMapController? _googleController;
  MapProvider _provider;

  UnifiedMapController(this._provider);

  void setNaverController(NaverMapController controller) {
    _naverController = controller;
  }

  void setGoogleController(gmap.GoogleMapController controller) {
    _googleController = controller;
  }

  void updateCamera(UnifiedLatLng target, {double zoom = 16}) {
    if (_provider == MapProvider.naver && _naverController != null) {
      _naverController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: target.toNaver(), zoom: zoom),
      );
    } else if (_provider == MapProvider.google && _googleController != null) {
      _googleController!.animateCamera(
        gmap.CameraUpdate.newLatLngZoom(target.toGoogle(), zoom),
      );
    }
  }

  void clearOverlays() {
    if (_provider == MapProvider.naver && _naverController != null) {
      _naverController!.clearOverlays();
    }
    // Google markers/circles are handled via state in the widget
  }

  /// Naver 전용: 오버레이 직접 추가
  void addNaverOverlay(NAddableOverlay overlay) {
    if (_provider == MapProvider.naver && _naverController != null) {
      _naverController!.addOverlay(overlay);
    }
  }

  NaverMapController? get naverController => _naverController;
  gmap.GoogleMapController? get googleController => _googleController;
  MapProvider get provider => _provider;

  set provider(MapProvider p) => _provider = p;
}

/// 통합 맵 위젯
class UnifiedMapWidget extends StatefulWidget {
  final UnifiedLatLng initialTarget;
  final double initialZoom;
  final void Function(UnifiedMapController controller)? onMapReady;
  final void Function(UnifiedLatLng latLng)? onMapTapped;
  final bool locationButtonEnable;
  final EdgeInsets contentPadding;

  /// Google Maps용 마커/서클을 외부에서 관리할 때 사용
  final Set<gmap.Marker>? googleMarkers;
  final Set<gmap.Circle>? googleCircles;

  const UnifiedMapWidget({
    super.key,
    required this.initialTarget,
    this.initialZoom = 16,
    this.onMapReady,
    this.onMapTapped,
    this.locationButtonEnable = true,
    this.contentPadding = EdgeInsets.zero,
    this.googleMarkers,
    this.googleCircles,
  });

  @override
  State<UnifiedMapWidget> createState() => _UnifiedMapWidgetState();
}

class _UnifiedMapWidgetState extends State<UnifiedMapWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MapProviderService>(
      builder: (context, mapService, child) {
        if (!mapService.isCurrentProviderAvailable) {
          return const Center(child: Text('지도 공급자가 일시적으로 비활성화되었습니다.'));
        }
        if (mapService.isNaver) {
          return _buildNaverMap(context);
        } else {
          return _buildGoogleMap(context, mapService.googleLanguage);
        }
      },
    );
  }

  Widget _buildNaverMap(BuildContext context) {
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(
          target: widget.initialTarget.toNaver(),
          zoom: widget.initialZoom,
        ),
        locationButtonEnable: widget.locationButtonEnable,
        indoorEnable: true,
        buildingHeight: 1.0,
        contentPadding: widget.contentPadding,
      ),
      onMapReady: (controller) {
        final unified = UnifiedMapController(MapProvider.naver);
        unified.setNaverController(controller);
        widget.onMapReady?.call(unified);
      },
      onMapTapped: (point, latLng) {
        widget.onMapTapped?.call(
          UnifiedLatLng(latLng.latitude, latLng.longitude),
        );
      },
    );
  }

  Widget _buildGoogleMap(BuildContext context, String languageCode) {
    final locale = switch (languageCode) {
      'ko' => const Locale('ko', 'KR'),
      'ja' => const Locale('ja', 'JP'),
      'zh' => const Locale('zh', 'CN'),
      'de' => const Locale('de', 'DE'),
      'fr' => const Locale('fr', 'FR'),
      'es' => const Locale('es', 'ES'),
      _ => const Locale('en', 'US'),
    };

    return Localizations.override(
      context: context,
      locale: locale,
      child: gmap.GoogleMap(
        key: ValueKey('google-map-$languageCode'),
        initialCameraPosition: gmap.CameraPosition(
          target: widget.initialTarget.toGoogle(),
          zoom: widget.initialZoom,
        ),
        myLocationEnabled: widget.locationButtonEnable,
        myLocationButtonEnabled: false, // 커스텀 버튼으로 대체 (MapToggleButton과 겹침 방지)
        zoomControlsEnabled: false,
        markers: widget.googleMarkers ?? {},
        circles: widget.googleCircles ?? {},
        onMapCreated: (controller) {
          final unified = UnifiedMapController(MapProvider.google);
          unified.setGoogleController(controller);
          widget.onMapReady?.call(unified);
        },
        onTap: (latLng) {
          widget.onMapTapped?.call(
            UnifiedLatLng(latLng.latitude, latLng.longitude),
          );
        },
        padding: widget.contentPadding,
      ),
    );
  }
}

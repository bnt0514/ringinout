// lib/widgets/unified_map_widget.dart
// 네이버맵 / 구글맵 / OSM 통합 위젯

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:ringinout/services/map_provider_service.dart';

/// 통합 좌표
class UnifiedLatLng {
  final double latitude;
  final double longitude;
  UnifiedLatLng(this.latitude, this.longitude);

  NLatLng toNaver() => NLatLng(latitude, longitude);
  gmap.LatLng toGoogle() => gmap.LatLng(latitude, longitude);
  ll.LatLng toOsm() => ll.LatLng(latitude, longitude);
}

/// 통합 맵 컨트롤러
class UnifiedMapController {
  NaverMapController? _naverController;
  gmap.GoogleMapController? _googleController;
  MapController? _osmController;
  MapProvider _provider;

  UnifiedMapController(this._provider);

  void setNaverController(NaverMapController controller) {
    _naverController = controller;
  }

  void setGoogleController(gmap.GoogleMapController controller) {
    _googleController = controller;
  }

  void setOsmController(MapController controller) {
    _osmController = controller;
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
    } else if (_provider == MapProvider.osm && _osmController != null) {
      _osmController!.move(target.toOsm(), zoom);
    }
  }

  void clearOverlays() {
    if (_provider == MapProvider.naver && _naverController != null) {
      _naverController!.clearOverlays();
    }
    // Google/OSM markers/circles are handled via state in the widget
  }

  /// Naver 전용: 오버레이 직접 추가
  void addNaverOverlay(NAddableOverlay overlay) {
    if (_provider == MapProvider.naver && _naverController != null) {
      _naverController!.addOverlay(overlay);
    }
  }

  NaverMapController? get naverController => _naverController;
  gmap.GoogleMapController? get googleController => _googleController;
  MapController? get osmController => _osmController;
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

  /// OSM용 마커/서클을 외부에서 관리할 때 사용
  final List<Marker>? osmMarkers;
  final List<CircleMarker>? osmCircles;

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
    this.osmMarkers,
    this.osmCircles,
  });

  @override
  State<UnifiedMapWidget> createState() => _UnifiedMapWidgetState();
}

class _UnifiedMapWidgetState extends State<UnifiedMapWidget> {
  late final MapController _osmController;

  @override
  void initState() {
    super.initState();
    _osmController = MapController();
  }

  @override
  void dispose() {
    _osmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProviderService>(
      builder: (context, mapService, child) {
        if (mapService.isNaver) {
          return _buildNaverMap(context);
        } else if (mapService.isOsm) {
          return _buildOsmMap(context);
        } else {
          return _buildGoogleMap(context);
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

  Widget _buildGoogleMap(BuildContext context) {
    return gmap.GoogleMap(
      initialCameraPosition: gmap.CameraPosition(
        target: widget.initialTarget.toGoogle(),
        zoom: widget.initialZoom,
      ),
      myLocationEnabled: widget.locationButtonEnable,
      myLocationButtonEnabled: widget.locationButtonEnable,
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
    );
  }

  Widget _buildOsmMap(BuildContext context) {
    return FlutterMap(
      mapController: _osmController,
      options: MapOptions(
        initialCenter: widget.initialTarget.toOsm(),
        initialZoom: widget.initialZoom,
        onMapReady: () {
          final unified = UnifiedMapController(MapProvider.osm);
          unified.setOsmController(_osmController);
          widget.onMapReady?.call(unified);
        },
        onTap: (tapPosition, latLng) {
          widget.onMapTapped?.call(
            UnifiedLatLng(latLng.latitude, latLng.longitude),
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ringinout',
          // ✅ 뷰포트 주변 타일 미리 로드 → 드래그/줌 시 회색 방지
          keepBuffer: 6,
          panBuffer: 3,
          maxZoom: 19,
          // ✅ 줌 레벨 변경 시 이전 타일 유지 (회색 방지)
          evictErrorTileStrategy:
              EvictErrorTileStrategy.notVisibleRespectMargin,
        ),
        if (widget.osmMarkers != null && widget.osmMarkers!.isNotEmpty)
          MarkerLayer(markers: widget.osmMarkers!),
        if (widget.osmCircles != null && widget.osmCircles!.isNotEmpty)
          CircleLayer(circles: widget.osmCircles!),
      ],
    );
  }
}

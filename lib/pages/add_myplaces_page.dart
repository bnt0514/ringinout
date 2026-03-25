// add_myplaces_page.dart

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:provider/provider.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/google_geocoding_service.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/services/naver_geocoding_service.dart';
import 'package:ringinout/services/osm_geocoding_service.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';
import 'package:ringinout/widgets/unified_map_widget.dart';
import 'package:ringinout/widgets/map_toggle_button.dart';

class AddMyPlacesPage extends StatefulWidget {
  final Future<void> Function(double lat, double lng, String name, int radius)
  onLocationSelected;

  const AddMyPlacesPage({super.key, required this.onLocationSelected});

  @override
  State<AddMyPlacesPage> createState() => _AddMyPlacesPageState();
}

class _AddMyPlacesPageState extends State<AddMyPlacesPage> {
  UnifiedMapController? _mapController;
  UnifiedLatLng? _selectedLatLng;
  String _address = '';
  int _selectedRadius = 100; // ✅ 기본값 100m
  final TextEditingController _searchController = TextEditingController();
  List<LocalSearchResult> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  double? _currentLat; // ✅ 현재 사용자 위치 (검색 기준)
  double? _currentLng;

  // Google Maps 전용 마커/서클 상태
  Set<gmap.Marker> _googleMarkers = {};
  Set<gmap.Circle> _googleCircles = {};

  // OSM 전용 마커/서클 상태
  List<fmap.Marker> _osmMarkers = [];
  List<fmap.CircleMarker> _osmCircles = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.deniedForever) {
      return;
    }
    geo.Position position = await geo.Geolocator.getCurrentPosition();
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    _moveCamera(position.latitude, position.longitude);
  }

  void _moveCamera(double lat, double lng) {
    final pos = UnifiedLatLng(lat, lng);
    setState(() {
      _selectedLatLng = pos;
    });
    _mapController?.updateCamera(pos, zoom: 16);
    _reverseGeocode(pos);
    _updateMarker();
  }

  void _updateMarker() {
    if (_mapController == null || _selectedLatLng == null) return;
    final mapService = context.read<MapProviderService>();

    if (mapService.isNaver) {
      // Naver: 오버레이 직접 조작
      _mapController!.clearOverlays();
      final marker = NMarker(
        id: 'selected',
        position: _selectedLatLng!.toNaver(),
      );
      _mapController!.addNaverOverlay(marker);
      final circle = NCircleOverlay(
        id: 'radius_circle',
        center: _selectedLatLng!.toNaver(),
        radius: _selectedRadius.toDouble(),
        color: AppColors.mapCircleFill,
        outlineColor: AppColors.mapCircleBorder,
        outlineWidth: 2,
      );
      _mapController!.addNaverOverlay(circle);
    } else if (mapService.isOsm) {
      // OSM: setState로 마커/서클 업데이트
      setState(() {
        _osmMarkers = [
          fmap.Marker(
            point: _selectedLatLng!.toOsm(),
            width: 40,
            height: 40,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        ];
        _osmCircles = [
          fmap.CircleMarker(
            point: _selectedLatLng!.toOsm(),
            radius: _selectedRadius.toDouble(),
            useRadiusInMeter: true,
            color: AppColors.mapCircleFill,
            borderColor: AppColors.mapCircleBorder,
            borderStrokeWidth: 2,
          ),
        ];
      });
    } else {
      // Google: setState로 마커/서클 업데이트
      setState(() {
        _googleMarkers = {
          gmap.Marker(
            markerId: const gmap.MarkerId('selected'),
            position: _selectedLatLng!.toGoogle(),
          ),
        };
        _googleCircles = {
          gmap.Circle(
            circleId: const gmap.CircleId('radius_circle'),
            center: _selectedLatLng!.toGoogle(),
            radius: _selectedRadius.toDouble(),
            fillColor: AppColors.mapCircleFill,
            strokeColor: AppColors.mapCircleBorder,
            strokeWidth: 2,
          ),
        };
      });
    }
  }

  Future<void> _reverseGeocode(UnifiedLatLng pos) async {
    try {
      final mapService = context.read<MapProviderService>();
      String? address;
      if (mapService.isNaver) {
        address = await NaverGeocodingService.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );
      } else if (mapService.isOsm) {
        address = await OsmGeocodingService.reverseGeocode(
          pos.latitude,
          pos.longitude,
        );
      } else {
        // 구글맵 역지오코딩은 비용 발생(Geocoding API 과금)으로 비활성화
        // 지도 탭 시 주소 표시 없이 좌표만 사용
        address = null;
      }
      if (address != null) {
        setState(() {
          _address = address!;
        });
      }
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
    }
  }

  void _onMapTapped(UnifiedLatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
      _showSearchResults = false;
    });
    _reverseGeocode(latLng);
    _updateMarker();
  }

  /// 주소 + 장소명 통합 검색
  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
      _searchResults = [];
    });

    try {
      final mapService = context.read<MapProviderService>();

      // 1️⃣ 장소명 검색 — 현재 위치 기준
      List<LocalSearchResult> placeResults;
      GeocodingResult? geoResult;

      if (mapService.isNaver) {
        placeResults = await NaverGeocodingService.searchPlace(
          query,
          lat: _currentLat,
          lng: _currentLng,
        );
        geoResult = await NaverGeocodingService.searchAddress(query);
      } else {
        placeResults = await GoogleGeocodingService.searchPlace(
          query,
          lat: _currentLat,
          lng: _currentLng,
        );
        geoResult = await GoogleGeocodingService.searchAddress(query);
      }

      final combinedResults = <LocalSearchResult>[];

      // 주소 결과가 있으면 맨 위에 추가
      if (geoResult != null) {
        combinedResults.add(
          LocalSearchResult(
            title: '📍 ${geoResult.displayAddress}',
            address: geoResult.jibunAddress,
            roadAddress: geoResult.roadAddress,
            category: AppLocalizations.of(context).get('address_search_result'),
            lat: geoResult.lat,
            lng: geoResult.lng,
          ),
        );
      }

      // 장소 검색 결과 추가
      combinedResults.addAll(placeResults);

      if (mounted) {
        setState(() {
          _searchResults = combinedResults;
          _isSearching = false;
        });

        // 결과가 딱 1개(주소만)이면 바로 이동
        if (combinedResults.length == 1 && geoResult != null) {
          _moveCamera(geoResult.lat, geoResult.lng);
          setState(() {
            _address = geoResult!.displayAddress;
            _showSearchResults = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 통합 검색 실패: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _saveLocation() async {
    debugPrint('🚀 _saveLocation 진입');
    if (_selectedLatLng == null) {
      debugPrint('⚠️ _selectedLatLng is null, 저장 중단됨');
      return;
    }

    final plan = await SubscriptionService.getCurrentPlan();
    final limit = SubscriptionService.placeLimit(plan);
    debugPrint(
      '🔍 [PlaceLimit] plan=$plan, limit=$limit, currentCount=${HiveHelper.placeBox.length}',
    );
    if (limit != null) {
      final currentCount = HiveHelper.placeBox.length;
      if (currentCount >= limit) {
        if (mounted) {
          await SubscriptionLimitDialog.showPlaceLimit(
            context,
            plan: plan,
            limit: limit,
          );
        }
        return;
      }
    }

    final TextEditingController nameController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppLocalizations.of(context).get('save_place_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(
                      context,
                    ).get('place_name_label'),
                    hintText: AppLocalizations.of(
                      context,
                    ).get('place_name_hint'),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).getWithArgs('radius_display', {
                    'radius': '$_selectedRadius',
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).get('radius_shown_on_map'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('cancel_btn')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    await SubscriptionService.requestAdIfNeeded(plan);
                    await HiveHelper.addLocation({
                      'name': name,
                      'lat': _selectedLatLng!.latitude,
                      'lng': _selectedLatLng!.longitude,
                      'radius': _selectedRadius,
                    });

                    // 🔄 장소 업데이트 → LocationMonitorService에서 자동 반영
                    await SmartLocationService.updatePlaces();

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).get('place_saved_msg'),
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context, 'location_saved');
                    }
                  }
                },
                child: Text(AppLocalizations.of(context).get('save_place_btn')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('select_on_map')),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: AppLocalizations.of(context).get('move_to_current'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onSubmitted: (value) => _performSearch(value),
              onChanged: (value) {
                // 검색어 지우면 결과도 숨김
                if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                    _showSearchResults = false;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).get('search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults = [];
                              _showSearchResults = false;
                            });
                          },
                        )
                        : null,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // ✅ 지도 + 검색 결과 오버레이 (Stack으로 overflow 방지)
          Expanded(
            child: Stack(
              children: [
                UnifiedMapWidget(
                  initialTarget:
                      _selectedLatLng ??
                      (_currentLat != null && _currentLng != null
                          ? UnifiedLatLng(_currentLat!, _currentLng!)
                          : UnifiedLatLng(37.5665, 126.9780)),
                  initialZoom: 16,
                  locationButtonEnable: true,
                  contentPadding: const EdgeInsets.only(bottom: 100),
                  googleMarkers: _googleMarkers,
                  googleCircles: _googleCircles,
                  osmMarkers: _osmMarkers,
                  osmCircles: _osmCircles,
                  onMapReady: (controller) {
                    _mapController = controller;
                    // 사용량 트래킹
                    MapUsageService.onMapLoaded(controller.provider.name);
                    MapUsageService.incrementFreeUserOpenCount();
                    // 맵 전환 후 위치 복원
                    if (_selectedLatLng != null) {
                      _mapController?.updateCamera(_selectedLatLng!, zoom: 16);
                      _updateMarker();
                    } else if (_currentLat != null && _currentLng != null) {
                      _moveCamera(_currentLat!, _currentLng!);
                    }
                  },
                  onMapTapped: (latLng) {
                    _onMapTapped(latLng);
                    FocusScope.of(context).unfocus();
                  },
                ),
                // ✅ 검색 결과 오버레이 (지도 위에 표시)
                if (_isSearching)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (_showSearchResults && _searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 8,
                    right: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.place,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              title: Text(
                                result.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.displayAddress,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (result.category.isNotEmpty)
                                    Text(
                                      result.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              onTap: () {
                                _moveCamera(result.lat, result.lng);
                                setState(() {
                                  _address = result.displayAddress;
                                  _showSearchResults = false;
                                });
                                FocusScope.of(context).unfocus();
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (_showSearchResults &&
                    _searchResults.isEmpty &&
                    !_isSearching)
                  Positioned(
                    top: 0,
                    left: 8,
                    right: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppLocalizations.of(context).get('no_search_result'),
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                // 북동선 오른쪽: 맵 토글 버튼 오버레이
                Positioned(
                  top: 8,
                  right: 8,
                  child: MapToggleButton(
                    onToggle: () {
                      _mapController = null;
                      _googleMarkers = {};
                      _googleCircles = {};
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_selectedLatLng != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      ).getWithArgs('address_label', {'address': _address}),
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // 반경 선택
                    Row(
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          ).get('radius_label_prefix'),
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildRadiusChip(30),
                              _buildRadiusChip(100),
                              _buildRadiusChip(200),
                              ChoiceChip(
                                label: Text(
                                  _selectedRadius > 200 ||
                                          ![
                                            30,
                                            100,
                                            200,
                                          ].contains(_selectedRadius)
                                      ? '${_selectedRadius}m'
                                      : AppLocalizations.of(
                                        context,
                                      ).get('custom_input'),
                                ),
                                selected:
                                    ![30, 100, 200].contains(_selectedRadius),
                                onSelected: (_) => _showCustomRadiusDialog(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedRadius <= 30)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).get('signal_warning'),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveLocation,
                        icon: const Icon(Icons.save),
                        label: Text(
                          AppLocalizations.of(context).get('save_location_btn'),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRadiusChip(int radius) {
    return ChoiceChip(
      label: Text('${radius}m'),
      selected: _selectedRadius == radius,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedRadius = radius;
          });
          _updateMarker();
        }
      },
    );
  }

  Future<void> _showCustomRadiusDialog() async {
    int customRadius = _selectedRadius;
    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    AppLocalizations.of(context).get('radius_input_title'),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${customRadius}m',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Slider(
                        value: customRadius.toDouble(),
                        min: 30,
                        max: 500,
                        divisions: 47, // (500-30)/10 = 47
                        label: '${customRadius}m',
                        onChanged: (value) {
                          setDialogState(() {
                            customRadius = (value / 10).round() * 10; // 10m 단위
                            if (customRadius < 30) customRadius = 30;
                          });
                        },
                      ),
                      Text(
                        AppLocalizations.of(context).get('radius_input_range'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        AppLocalizations.of(context).get('cancel_btn'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedRadius = customRadius;
                        });
                        _updateMarker();
                        Navigator.pop(context);
                      },
                      child: Text(AppLocalizations.of(context).get('confirm')),
                    ),
                  ],
                ),
          ),
    );
  }
}

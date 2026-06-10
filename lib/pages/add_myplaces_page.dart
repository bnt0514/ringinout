// add_myplaces_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/config/app_theme.dart';
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
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';
import 'package:ringinout/widgets/unified_map_widget.dart';
import 'package:ringinout/widgets/map_toggle_button.dart';
import 'package:ringinout/widgets/wifi_selector_widget.dart';
// import 'package:ringinout/widgets/bluetooth_selector_widget.dart'; // 추후 활성화 예정

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

  /// 사용자가 직접 지도를 조작(탭/검색 결과 선택)했는지 여부
  /// true이면 현재 위치 자동 이동을 하지 않는다
  bool _userInteracted = false;

  /// 현재 위치 확정 여부 — false이면 맵/검색 잠금
  bool _locationReady = true;

  /// 지오코딩(검색 + 역지오코딩) 허용 여부
  /// false이면 검색바 숨김 + 맵 탭 시 주소 조회 안 함 (좌표만 표시)
  bool _geocodingAllowed = true;
  bool _addressOnlySearchMode = false;
  bool _isLocatingCurrentPosition = true;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _refreshGeocodingAllowed();
  }

  Future<void> _determinePosition() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _locationReady = true;
          _isLocatingCurrentPosition = false;
        });
      }
      return;
    }
    geo.Position? position = await geo.Geolocator.getLastKnownPosition();
    try {
      position ??= await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (e) {
      debugPrint('Current location bootstrap failed: $e');
      if (mounted) {
        setState(() {
          _locationReady = true;
          _isLocatingCurrentPosition = false;
        });
      }
      return;
    }
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    if (mounted) {
      context.read<MapProviderService>().updateRegionFromCoordinates(
        position.latitude,
        position.longitude,
      );
    }
    // 사용자가 이미 지도를 조작(검색/탭)한 경우 현재 위치로 덮어쓰지 않는다
    if (!_userInteracted) {
      _moveCamera(position.latitude, position.longitude);
    }
    setState(() {
      _locationReady = true;
      _isLocatingCurrentPosition = false;
    });
  }

  /// AppBar 버튼: 무조건 현재 위치로 이동 (사용자 조작 여부 무시)
  Future<void> _goToCurrentLocation() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.deniedForever) return;
    late final geo.Position position;
    try {
      position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('Move to current location failed: $e');
      return;
    }
    _currentLat = position.latitude;
    _currentLng = position.longitude;
    if (!mounted) return;
    context.read<MapProviderService>().updateRegionFromCoordinates(
      position.latitude,
      position.longitude,
    );
    _moveCamera(position.latitude, position.longitude);
    setState(() => _locationReady = true);
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
    if (!_geocodingAllowed && !AppConfig.isBetaVersion) {
      if (mounted) {
        setState(() {
          _address =
              '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
        });
      }
      return;
    }

    final mapService = context.read<MapProviderService>();
    GeocodingResult? result;
    if (mapService.isNaver) {
      result = await NaverGeocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
    } else {
      result = await GoogleGeocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
        language: mapService.googleLanguage,
      );
    }

    if (mounted) {
      setState(() {
        _address =
            result?.displayAddress ??
            '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}';
      });
    }
  }

  /// 검색/역지오코딩 허용 여부 갱신
  /// 조건: (1) 글로벌 지오코딩 킬스위치 OFF가 아님
  ///       (2) 무료 + 제공자별 차단 토글에 안 걸림
  ///       (3) 검색 quota cap 도달 안 함 (needsReward는 허용)
  Future<void> _refreshGeocodingAllowed() async {
    bool allowed = true;
    bool addressOnlySearchMode = false;

    if (!AppConfig.isGeocodingEnabled) {
      allowed = false;
    } else if (AppConfig.isBetaVersion) {
      allowed = true;
    } else {
      try {
        final plan = await SubscriptionService.getCurrentPlan();
        final mapService = context.read<MapProviderService>();
        final provider = mapService.isNaver ? 'naver' : 'google';
        if (!SubscriptionService.canUseGeocoding(
          plan: plan,
          provider: provider,
        )) {
          allowed = false;
        } else {
          addressOnlySearchMode = false;
        }
      } catch (e) {
        debugPrint('⚠️ _refreshGeocodingAllowed 실패: $e');
      }
    }

    if (mounted &&
        (_geocodingAllowed != allowed ||
            _addressOnlySearchMode != addressOnlySearchMode)) {
      setState(() {
        _geocodingAllowed = allowed;
        _addressOnlySearchMode = addressOnlySearchMode;
      });
    }
  }

  void _onMapTapped(UnifiedLatLng latLng) {
    _userInteracted = true;
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
        geoResult = null;
      } else {
        // Google: Places Text Search ($32/1K) 와 Geocoding ($5/1K) 모두 유료
        placeResults =
            _addressOnlySearchMode
                ? []
                : await GoogleGeocodingService.searchPlace(
                  query,
                  lat: _currentLat,
                  lng: _currentLng,
                  language: mapService.googleLanguage,
                );
        geoResult = await GoogleGeocodingService.searchAddress(
          query,
          language: mapService.googleLanguage,
        );
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

      // 실제 결과가 나왔거나 API 호출이 실행되었으면 성공으로 간주 → record

      if (mounted) {
        setState(() {
          _searchResults = combinedResults;
          _isSearching = false;
        });

        // 결과가 딱 1개(주소만)이면 바로 이동
        if (combinedResults.length == 1 && geoResult != null) {
          _userInteracted = true;
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
    } finally {
      // 제공자별 차단 상태 변화 반영
      await _refreshGeocodingAllowed();
    }
  }

  void _saveLocation() async {
    debugPrint('🚀 _saveLocation 진입');
    if (_selectedLatLng == null) {
      debugPrint('⚠️ _selectedLatLng is null, 저장 중단됨');
      return;
    }

    final plan = SubscriptionPlan.special;
    final limit = SubscriptionService.placeLimit(plan);
    final currentCount = HiveHelper.getSavedLocations().length;
    debugPrint(
      '🔍 [PlaceLimit] plan=$plan, limit=$limit, currentCount=$currentCount',
    );
    if (limit != null) {
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
    List<Map<String, dynamic>> selectedWifiNetworks = [];
    List<Map<String, dynamic>> selectedBluetoothDevices = [];

    final result = await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(
                  AppLocalizations.of(context).get('save_place_title'),
                ),
                content: SingleChildScrollView(
                  child: Column(
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
                        AppLocalizations.of(context).getWithArgs(
                          'radius_display',
                          {'radius': '$_selectedRadius'},
                        ),
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
                      const SizedBox(height: 16),
                      // ── Wi-Fi 네트워크 선택 ──
                      WifiSelectorWidget(
                        onChanged: (networks) {
                          setDialogState(() {
                            selectedWifiNetworks = networks;
                          });
                        },
                      ),
                      // 블루투스 기기 선택 — 추후 활성화 예정
                      // const SizedBox(height: 8),
                      // BluetoothSelectorWidget(
                      //   onChanged: (devices) {
                      //     setDialogState(() {
                      //       selectedBluetoothDevices = devices;
                      //     });
                      //   },
                      // ),
                    ],
                  ),
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
                          'wifiNetworks': selectedWifiNetworks,
                          'bluetoothDevices':
                              AppConfig.enableBluetoothFeatures
                                  ? selectedBluetoothDevices
                                  : [],
                        });

                        // 🔄 장소 업데이트 → LocationMonitorService에서 자동 반영
                        unawaited(
                          SmartLocationService.updatePlaces().catchError(
                            (e) => debugPrint(
                              'SmartLocationService update failed: $e',
                            ),
                          ),
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLocalizations.of(
                                  context,
                                ).get('place_saved_msg'),
                              ),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          Navigator.pop(context, 'location_saved');
                        }
                      }
                    },
                    child: Text(
                      AppLocalizations.of(context).get('save_place_btn'),
                    ),
                  ),
                ],
              );
            },
          ),
    );

    // 다이얼로그에서 저장 완료 시 맵 페이지도 닫고 내 장소 페이지로 복귀
    if (result == 'location_saved' && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('select_on_map')),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: AppLocalizations.of(context).get('move_to_current'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_geocodingAllowed)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                onSubmitted: (value) {
                  if (!_locationReady) {
                    FocusScope.of(context).unfocus();
                    return;
                  }
                  _performSearch(value);
                },
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
                  hintText: AppLocalizations.of(context).get(
                    _addressOnlySearchMode
                        ? 'search_address_only_hint'
                        : 'search_hint',
                  ),
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
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).get('place_add_no_search_hint'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
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
                  onMapReady: (controller) {
                    _mapController = controller;
                    // 사용량 트래킹
                    MapUsageService.onMapLoaded(controller.provider.name);
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
                if (_isLocatingCurrentPosition)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
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
                                _userInteracted = true;
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
                // 맵 토글 버튼 아래: 현재 위치 버튼 (구글맵 내장 버튼 대체)
                Positioned(
                  top: 60,
                  right: 8,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    elevation: 2,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: _goToCurrentLocation,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.my_location,
                          size: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                // ✅ 현재 위치 확정 전 맵 잠금 오버레이
                if (!_locationReady && _selectedLatLng == null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 16),
                            Text(
                              '현재 위치를 불러오는 중...\n잠시만 기다려주세요',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
                              _buildRadiusChip(50),
                              _buildRadiusChip(100),
                              ChoiceChip(
                                label: Text(
                                  ![30, 50, 100].contains(_selectedRadius)
                                      ? '${_selectedRadius}m'
                                      : AppLocalizations.of(
                                        context,
                                      ).get('custom_input'),
                                ),
                                selected:
                                    ![30, 50, 100].contains(_selectedRadius),
                                onSelected: (_) => _showCustomRadiusDialog(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // 반경 설정 안내 버튼
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () => _showRadiusGuideDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppLocalizations.of(
                                  context,
                                ).get('radius_guide_btn'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.blue.shade700,
                                size: 16,
                              ),
                            ],
                          ),
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

  void _showRadiusGuideDialog() {
    final lang = AppLocalizations.of(context).locale.languageCode;
    final guideBody =
        lang == 'ko'
            ? 'GPS는 대략적인 위치만 파악합니다. 야외에서도 몇 m~수십 m 오차가 생길 수 있어요.\n\n'
                'GPS가 순간적으로 튀어서 한 번 잘못 울린 경우에는 "오발동" 버튼으로 이번 울림만 정리하세요.\n\n'
                '설정 반경 경계 근처에 계속 머무르거나 움직이는 중이면 GPS가 경계 안팎을 반복해서 오가며 인식할 수 있습니다. 이때는 "잠시 멈춤"을 눌러 일정 시간 동안 해당 알람이 다시 울리지 않게 설정하세요.'
            : 'GPS can only estimate your location. Even outdoors, errors of several to tens of meters can happen.\n\n'
                'If the alarm rings once because GPS briefly jumped, tap "False Trigger" to stop that ringing.\n\n'
                'If you are staying near the edge of the radius, GPS may keep moving you in and out of the boundary. In that case, use "Pause" to stop this alarm for a while, then let it resume later.';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              AppLocalizations.of(context).get('radius_guide_btn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Text(
                guideBody,
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('confirm')),
              ),
            ],
          ),
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

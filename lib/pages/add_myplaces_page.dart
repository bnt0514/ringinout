// add_myplaces_page.dart

import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/naver_geocoding_service.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

class AddMyPlacesPage extends StatefulWidget {
  final Future<void> Function(double lat, double lng, String name, int radius)
  onLocationSelected;

  const AddMyPlacesPage({super.key, required this.onLocationSelected});

  @override
  State<AddMyPlacesPage> createState() => _AddMyPlacesPageState();
}

class _AddMyPlacesPageState extends State<AddMyPlacesPage> {
  NaverMapController? _mapController;
  NLatLng? _selectedLatLng;
  String _address = '';
  int _selectedRadius = 100; // ✅ 기본값 100m
  final TextEditingController _searchController = TextEditingController();
  List<LocalSearchResult> _searchResults = [];
  bool _showSearchResults = false;
  bool _isSearching = false;
  double? _currentLat; // ✅ 현재 사용자 위치 (검색 기준)
  double? _currentLng;

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
    final pos = NLatLng(lat, lng);
    setState(() {
      _selectedLatLng = pos;
    });
    _mapController?.updateCamera(
      NCameraUpdate.scrollAndZoomTo(target: pos, zoom: 16),
    );
    _reverseGeocode(pos);
    _updateMarker();
  }

  void _updateMarker() {
    if (_mapController == null || _selectedLatLng == null) return;
    _mapController!.clearOverlays();

    // ✅ 마커 추가
    final marker = NMarker(id: 'selected', position: _selectedLatLng!);
    _mapController!.addOverlay(marker);

    // ✅ 반경 원 추가
    final circle = NCircleOverlay(
      id: 'radius_circle',
      center: _selectedLatLng!,
      radius: _selectedRadius.toDouble(),
      color: AppColors.mapCircleFill,
      outlineColor: AppColors.mapCircleBorder,
      outlineWidth: 2,
    );
    _mapController!.addOverlay(circle);
  }

  Future<void> _reverseGeocode(NLatLng pos) async {
    try {
      final address = await NaverGeocodingService.reverseGeocode(
        pos.latitude,
        pos.longitude,
      );
      if (address != null) {
        setState(() {
          _address = address;
        });
      }
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
    }
  }

  void _onMapTapped(NPoint point, NLatLng latLng) {
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
      // 1️⃣ 장소명 검색 (Local Search API) — 현재 위치 기준
      final placeResults = await NaverGeocodingService.searchPlace(
        query,
        lat: _currentLat,
        lng: _currentLng,
      );

      // 2️⃣ 주소 검색 (Geocoding API) — 결과가 있으면 첫 번째에 추가
      final geoResult = await NaverGeocodingService.searchAddress(query);

      final combinedResults = <LocalSearchResult>[];

      // 주소 결과가 있으면 맨 위에 추가
      if (geoResult != null) {
        combinedResults.add(
          LocalSearchResult(
            title: '📍 ${geoResult.displayAddress}',
            address: geoResult.jibunAddress,
            roadAddress: geoResult.roadAddress,
            category: '주소 검색 결과',
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
            _address = geoResult.displayAddress;
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
            title: const Text('장소 저장'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '장소 이름',
                    hintText: '예: 집, 회사, 헬스장 등',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '반경: ${_selectedRadius}m',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                const Text(
                  '(지도에서 원으로 표시됨)',
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
                child: const Text('취소'),
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
                        const SnackBar(
                          content: Text('✅ 장소가 저장되었습니다'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context, 'location_saved');
                    }
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('지도에서 위치 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _determinePosition,
            tooltip: '현재 위치로 이동',
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
                hintText: '주소 또는 지역+장소명 (예: 시흥 롯데마트)',
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
                NaverMap(
                  options: const NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(37.5665, 126.9780),
                      zoom: 12,
                    ),
                    locationButtonEnable: true,
                    indoorEnable: true,
                    buildingHeight: 1.0,
                    contentPadding: EdgeInsets.only(
                      bottom: 100,
                    ), // 하단 버튼과 겹침 방지
                  ),
                  onMapReady: (controller) {
                    _mapController = controller;
                    if (_selectedLatLng != null) _updateMarker();
                  },
                  onMapTapped: (point, latLng) {
                    _onMapTapped(point, latLng);
                    // 지도 탭하면 검색 결과 닫기
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
                          '검색 결과가 없습니다',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
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
                      '주소: $_address',
                      style: const TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // 반경 선택
                    Row(
                      children: [
                        const Text(
                          '반경: ',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildRadiusChip(50),
                              _buildRadiusChip(100),
                              _buildRadiusChip(200),
                              ChoiceChip(
                                label: Text(
                                  _selectedRadius > 200 ||
                                          ![
                                            50,
                                            100,
                                            200,
                                          ].contains(_selectedRadius)
                                      ? '${_selectedRadius}m'
                                      : '직접입력',
                                ),
                                selected:
                                    ![50, 100, 200].contains(_selectedRadius),
                                onSelected: (_) => _showCustomRadiusDialog(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_selectedRadius <= 50)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '전파 방해 지역(고층빌딩, 아파트, 지하 등)에서는 알람이 울리지 않을 수 있습니다. 100m 이상 권장',
                                  style: TextStyle(
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
                        label: const Text('위치 저장'),
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
                  title: const Text('반경 직접 입력'),
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
                        min: 50,
                        max: 500,
                        divisions: 45, // (500-50)/10 = 45
                        label: '${customRadius}m',
                        onChanged: (value) {
                          setDialogState(() {
                            customRadius = (value / 10).round() * 10; // 10m 단위
                            if (customRadius < 50) customRadius = 50;
                          });
                        },
                      ),
                      const Text(
                        '50m ~ 500m (10m 단위)',
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
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedRadius = customRadius;
                        });
                        _updateMarker();
                        Navigator.pop(context);
                      },
                      child: const Text('확인'),
                    ),
                  ],
                ),
          ),
    );
  }
}

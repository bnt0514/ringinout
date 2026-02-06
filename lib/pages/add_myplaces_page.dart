// add_myplaces_page.dart

import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart' as fence;
import 'package:geofence_service/models/geofence.dart';
import 'package:geofence_service/models/geofence_radius.dart';
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
  int _selectedRadius = 30; // ✅ 기본값 30m

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
      color: Colors.blue.withOpacity(0.2),
      outlineColor: Colors.blue,
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
    });
    _reverseGeocode(latLng);
    _updateMarker();
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
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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

                    fence.GeofenceService.instance.addGeofence(
                      Geofence(
                        id: name,
                        latitude: _selectedLatLng!.latitude,
                        longitude: _selectedLatLng!.longitude,
                        radius: [
                          GeofenceRadius(
                            id: 'default',
                            length: _selectedRadius.toDouble(),
                          ),
                        ],
                      ),
                    );

                    // 🔄 네이티브 지오펜스 실시간 업데이트
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
              onSubmitted: (value) async {
                try {
                  final result = await NaverGeocodingService.searchAddress(
                    value,
                  );
                  if (result != null) {
                    _moveCamera(result.lat, result.lng);
                    setState(() {
                      _address = result.displayAddress;
                    });
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('주소를 찾을 수 없습니다')),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint('주소 검색 실패: $e');
                }
              },
              decoration: const InputDecoration(
                hintText: '주소를 입력하세요',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: NaverMap(
              options: const NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: NLatLng(37.5665, 126.9780),
                  zoom: 12,
                ),
                locationButtonEnable: true,
                indoorEnable: true,
                buildingHeight: 1.0,
                contentPadding: EdgeInsets.only(bottom: 100), // 하단 버튼과 겹침 방지
              ),
              onMapReady: (controller) {
                _mapController = controller;
                if (_selectedLatLng != null) _updateMarker();
              },
              onMapTapped: _onMapTapped,
            ),
          ),
          if (_selectedLatLng != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                              _buildRadiusChip(30),
                              _buildRadiusChip(50),
                              _buildRadiusChip(100),
                              _buildRadiusChip(200),
                              ChoiceChip(
                                label: Text(
                                  _selectedRadius > 200 ||
                                          ![
                                            30,
                                            50,
                                            100,
                                            200,
                                          ].contains(_selectedRadius)
                                      ? '${_selectedRadius}m'
                                      : '직접입력',
                                ),
                                selected:
                                    ![
                                      30,
                                      50,
                                      100,
                                      200,
                                    ].contains(_selectedRadius),
                                onSelected: (_) => _showCustomRadiusDialog(),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      const Text(
                        '30m ~ 500m (10m 단위)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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

// location_picker_page.dart

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';

class LocationPickerPage extends StatefulWidget {
  final void Function(double lat, double lng, String name, int radius)?
  onLocationSelected;

  const LocationPickerPage({super.key, this.onLocationSelected});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  NaverMapController? _mapController;
  NLatLng? _currentLatLng;
  NLatLng? _selectedLatLng;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLatLng = NLatLng(position.latitude, position.longitude);
    });

    if (_mapController != null && _currentLatLng != null) {
      _mapController!.updateCamera(
        NCameraUpdate.scrollAndZoomTo(target: _currentLatLng!, zoom: 16),
      );
    }
  }

  void _onMapTap(NPoint point, NLatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
    _updateMarker();
  }

  void _updateMarker() {
    if (_mapController == null || _selectedLatLng == null) return;

    _mapController!.clearOverlays();
    final marker = NMarker(id: 'selected', position: _selectedLatLng!);
    _mapController!.addOverlay(marker);
  }

  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('장소 이름 입력'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '장소 이름'),
                ),
                const SizedBox(height: 12),
                const Text(
                  '반경: 100m (수정은 나중에 가능)',
                  style: TextStyle(fontSize: 14),
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
                  final name = nameController.text.trim();
                  if (_selectedLatLng != null && name.isNotEmpty) {
                    widget.onLocationSelected?.call(
                      _selectedLatLng!.latitude,
                      _selectedLatLng!.longitude,
                      name,
                      100,
                    );
                    Navigator.pop(context);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📍 위치가 저장되었습니다!')),
                    );
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
        title: const Text('위치 선택'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _selectedLatLng == null ? null : _showSaveDialog,
          ),
        ],
      ),
      body:
          _currentLatLng == null
              ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('현재 위치를 가져오는 중...'),
                  ],
                ),
              )
              : NaverMap(
                options: NaverMapViewOptions(
                  initialCameraPosition: NCameraPosition(
                    target: _currentLatLng!,
                    zoom: 16,
                  ),
                  locationButtonEnable: true,
                  indoorEnable: true,
                  buildingHeight: 1.0,
                ),
                onMapReady: (controller) {
                  setState(() {
                    _mapController = controller;
                    _isMapReady = true;
                  });
                },
                onMapTapped: _onMapTap,
              ),
    );
  }
}

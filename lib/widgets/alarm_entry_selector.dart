// location_picker_page.dart

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationPickerPage extends StatefulWidget {
  final void Function(double lat, double lng, String name, int radius)?
  onLocationSelected;

  const LocationPickerPage({super.key, this.onLocationSelected});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  @override
  void initState() {
    super.initState();
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
      _currentLatLng = LatLng(position.latitude, position.longitude);
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
  }

  void _onTap(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
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
              ? const Center(child: Text('우측 상단의 위치 버튼을 눌러 현재 위치를 가져오세요'))
              : GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(
                  target: _currentLatLng!,
                  zoom: 16,
                ),
                onTap: _onTap,
                markers:
                    _selectedLatLng != null
                        ? {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _selectedLatLng!,
                          ),
                        }
                        : {},
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                mapType: MapType.normal, // ✅ 일반 지도 (건물 표시)
                buildingsEnabled: true, // ✅ 건물 3D 표시 활성화
              ),
    );
  }
}

// location_picker_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPickerPage extends StatefulWidget {
  final void Function(double lat, double lng, String name, int radius)
  onLocationSelected;

  const LocationPickerPage({super.key, required this.onLocationSelected});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  String _address = '';

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _moveCamera(position.latitude, position.longitude);
  }

  void _moveCamera(double lat, double lng) {
    final pos = LatLng(lat, lng);
    setState(() {
      _selectedLatLng = pos;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    _reverseGeocode(pos);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        setState(() {
          _address =
              '${placemarks.first.street ?? ''}, ${placemarks.first.locality ?? ''}';
        });
      }
    } catch (e) {
      debugPrint('주소 변환 실패: $e');
    }
  }

  void _onMapTapped(LatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
    _reverseGeocode(latLng);
  }

  void _saveLocation() async {
    if (_selectedLatLng == null) return;

    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('장소 이름 입력'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: '예: 집, 회사, 헬스장 등'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    widget.onLocationSelected(
                      _selectedLatLng!.latitude,
                      _selectedLatLng!.longitude,
                      name,
                      100,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('위치가 저장되었습니다. (반경 100m, 추후 수정 가능)'),
                      ),
                    );
                    Navigator.pop(context);
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
                  List<Location> locations = await locationFromAddress(value);
                  if (locations.isNotEmpty) {
                    final loc = locations.first;
                    _moveCamera(loc.latitude, loc.longitude);
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
            child: GoogleMap(
              onMapCreated: (controller) => _mapController = controller,
              initialCameraPosition: const CameraPosition(
                target: LatLng(37.5665, 126.9780), // 서울 기준 초기 위치
                zoom: 12,
              ),
              onTap: _onMapTapped,
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
            ),
          ),
          if (_selectedLatLng != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Text('주소: $_address'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _saveLocation,
                    icon: const Icon(Icons.save),
                    label: const Text('위치 저장'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

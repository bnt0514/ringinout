// add_myplaces_page.dart

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geofence_service/geofence_service.dart' as fence;
import 'package:geofence_service/models/geofence.dart';
import 'package:geofence_service/models/geofence_radius.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ringinout/services/hive_helper.dart';

class AddMyPlacesPage extends StatefulWidget {
  final Future<void> Function(double lat, double lng, String name, int radius)
  onLocationSelected;

  const AddMyPlacesPage({super.key, required this.onLocationSelected});

  @override
  State<AddMyPlacesPage> createState() => _AddMyPlacesPageState();
}

class _AddMyPlacesPageState extends State<AddMyPlacesPage> {
  GoogleMapController? _mapController;
  LatLng? _selectedLatLng;
  String _address = '';

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
    debugPrint('🚀 _saveLocation 진입');
    if (_selectedLatLng == null) {
      debugPrint('⚠️ _selectedLatLng is null, 저장 중단됨');
      return;
    }

    final TextEditingController nameController = TextEditingController();

    await showDialog(
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
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    await HiveHelper.addLocation({
                      'name': name,
                      'lat': _selectedLatLng!.latitude,
                      'lng': _selectedLatLng!.longitude,
                      'radius': 100,
                    });

                    fence.GeofenceService.instance.addGeofence(
                      Geofence(
                        id: name,
                        latitude: _selectedLatLng!.latitude,
                        longitude: _selectedLatLng!.longitude,
                        radius: [GeofenceRadius(id: 'default', length: 100)],
                      ),
                    );

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
                target: LatLng(37.5665, 126.9780),
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

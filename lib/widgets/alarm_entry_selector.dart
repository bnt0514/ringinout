// location_picker_page.dart

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/widgets/unified_map_widget.dart';
import 'package:ringinout/widgets/map_toggle_button.dart';

class LocationPickerPage extends StatefulWidget {
  final void Function(double lat, double lng, String name, int radius)?
  onLocationSelected;

  const LocationPickerPage({super.key, this.onLocationSelected});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  UnifiedMapController? _mapController;
  UnifiedLatLng? _currentLatLng;
  UnifiedLatLng? _selectedLatLng;
  bool _isMapReady = false;

  // Google Maps 전용 마커 상태
  Set<gmap.Marker> _googleMarkers = {};

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
      _currentLatLng = UnifiedLatLng(position.latitude, position.longitude);
    });

    if (_mapController != null && _currentLatLng != null) {
      _mapController!.updateCamera(_currentLatLng!, zoom: 16);
    }
  }

  void _onMapTap(UnifiedLatLng latLng) {
    setState(() {
      _selectedLatLng = latLng;
    });
    _updateMarker();
  }

  void _updateMarker() {
    if (_mapController == null || _selectedLatLng == null) return;
    final mapService = context.read<MapProviderService>();

    if (mapService.isNaver) {
      _mapController!.clearOverlays();
      final marker = NMarker(
        id: 'selected',
        position: _selectedLatLng!.toNaver(),
      );
      _mapController!.addNaverOverlay(marker);
    } else {
      setState(() {
        _googleMarkers = {
          gmap.Marker(
            markerId: const gmap.MarkerId('selected'),
            position: _selectedLatLng!.toGoogle(),
          ),
        };
      });
    }
  }

  void _showSaveDialog() {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              AppLocalizations.of(context).get('place_name_input_title'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(
                      context,
                    ).get('place_name_label'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).get('radius_default_info'),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('cancel')),
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
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context).get('location_saved'),
                        ),
                      ),
                    );
                  }
                },
                child: Text(AppLocalizations.of(context).get('save')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('location_select_title')),
        actions: [
          MapToggleButton(
            onToggle: () {
              // 전환 전 현재 위치 보존 (controller만 리셋)
              _mapController = null;
              _googleMarkers = {};
            },
          ),
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
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context).get('fetching_location')),
                  ],
                ),
              )
              : UnifiedMapWidget(
                initialTarget: _selectedLatLng ?? _currentLatLng!,
                initialZoom: 16,
                locationButtonEnable: true,
                googleMarkers: _googleMarkers,
                onMapReady: (controller) {
                  setState(() {
                    _mapController = controller;
                    _isMapReady = true;
                  });
                  // 지도 오픈 카운트 증가 (무료 플랜 월 한도 / 분석)
                  MapUsageService.onMapLoaded(controller.provider.name);
                  // 맵 전환 후 위치 복원
                  final target = _selectedLatLng ?? _currentLatLng;
                  if (target != null) {
                    _mapController?.updateCamera(target, zoom: 16);
                    if (_selectedLatLng != null) _updateMarker();
                  }
                },
                onMapTapped: _onMapTap,
              ),
    );
  }
}

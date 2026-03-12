import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import '../services/hive_helper.dart';
import '../services/app_localizations.dart';
import '../services/smart_location_service.dart';

class EditPlacePage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final int index;

  const EditPlacePage({
    super.key,
    required this.initialData,
    required this.index,
  });

  @override
  State<EditPlacePage> createState() => _EditPlacePageState();
}

class _EditPlacePageState extends State<EditPlacePage> {
  late TextEditingController _nameController;
  int _radius = 100;
  late NLatLng _selectedLatLng;
  NaverMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData['name'] ?? '',
    );
    _radius = (widget.initialData['radius'] as num?)?.toInt() ?? 100;
    _selectedLatLng = NLatLng(
      widget.initialData['lat'] ?? 37.5665,
      widget.initialData['lng'] ?? 126.9780,
    );
  }

  void _updateMarker() {
    if (_mapController == null) return;
    _mapController!.clearOverlays();

    // 마커 추가
    final marker = NMarker(id: 'loc', position: _selectedLatLng);
    _mapController!.addOverlay(marker);

    // 반경 원 추가
    final circle = NCircleOverlay(
      id: 'radius_circle',
      center: _selectedLatLng,
      radius: _radius.toDouble(),
      color: AppColors.mapCircleFill,
      outlineColor: AppColors.mapCircleBorder,
      outlineWidth: 2,
    );
    _mapController!.addOverlay(circle);
  }

  void _saveChanges() async {
    final l10n = AppLocalizations.of(context);
    final updatedLocation = {
      'name': _nameController.text,
      'lat': _selectedLatLng.latitude,
      'lng': _selectedLatLng.longitude,
      'radius': _radius,
    };

    await HiveHelper.updateLocationAt(widget.index, updatedLocation);

    // 🔄 네이티브 지오펜스 실시간 업데이트
    await SmartLocationService.updatePlaces();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('place_updated'))));
    Navigator.pop(context, true);
  }

  void _deletePlace() async {
    final l10n = AppLocalizations.of(context);
    await HiveHelper.deleteLocation(widget.index);

    // 🔄 네이티브 지오펜스 실시간 업데이트
    await SmartLocationService.updatePlaces();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.get('place_deleted'))));
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('edit_place'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.get('place_name')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Text(
                  '${l10n.get('radius')}: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
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
                          ![50, 100, 200].contains(_radius)
                              ? '${_radius}m'
                              : l10n.get('custom'),
                        ),
                        selected: ![50, 100, 200].contains(_radius),
                        onSelected: (_) => _showCustomRadiusDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_radius <= 50)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                        style: TextStyle(fontSize: 11, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition: NCameraPosition(
                  target: _selectedLatLng,
                  zoom: 16,
                ),
                locationButtonEnable: true,
                indoorEnable: true,
                buildingHeight: 1.0,
              ),
              onMapReady: (controller) {
                _mapController = controller;
                _updateMarker();
              },
              onMapTapped: (point, latLng) {
                setState(() => _selectedLatLng = latLng);
                _updateMarker();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _deletePlace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                  ),
                  icon: const Icon(Icons.delete),
                  label: Text(l10n.get('delete')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.save),
                  label: Text(l10n.get('save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusChip(int radius) {
    return ChoiceChip(
      label: Text('${radius}m'),
      selected: _radius == radius,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _radius = radius;
          });
          _updateMarker();
        }
      },
    );
  }

  Future<void> _showCustomRadiusDialog() async {
    final l10n = AppLocalizations.of(context);
    int customRadius = _radius;
    await showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(l10n.get('custom_radius')),
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
                      child: Text(l10n.get('cancel')),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _radius = customRadius;
                        });
                        _updateMarker();
                        Navigator.pop(context);
                      },
                      child: Text(l10n.get('confirm')),
                    ),
                  ],
                ),
          ),
    );
  }
}

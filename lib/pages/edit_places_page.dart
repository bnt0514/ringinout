import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:provider/provider.dart';
import '../services/hive_helper.dart';
import '../services/app_localizations.dart';
import '../services/map_provider_service.dart';
import '../services/map_usage_service.dart';
import '../services/smart_location_service.dart';
import '../widgets/unified_map_widget.dart';
import '../widgets/map_toggle_button.dart';
import '../widgets/wifi_selector_widget.dart';

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
  late UnifiedLatLng _selectedLatLng;
  UnifiedMapController? _mapController;

  // Wi-Fi 네트워크 선택
  List<Map<String, dynamic>> _selectedWifiNetworks = [];

  // Google Maps 전용 마커/서클 상태
  Set<gmap.Marker> _googleMarkers = {};
  Set<gmap.Circle> _googleCircles = {};

  // OSM 전용 마커/서클 상태
  List<fmap.Marker> _osmMarkers = [];
  List<fmap.CircleMarker> _osmCircles = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData['name'] ?? '',
    );
    _radius = (widget.initialData['radius'] as num?)?.toInt() ?? 100;
    _selectedLatLng = UnifiedLatLng(
      widget.initialData['lat'] ?? 37.5665,
      widget.initialData['lng'] ?? 126.9780,
    );

    // Wi-Fi 네트워크 초기화
    final wifi = widget.initialData['wifiNetworks'];
    if (wifi is List) {
      _selectedWifiNetworks =
          wifi.map((w) => Map<String, dynamic>.from(w as Map)).toList();
    }
  }

  void _updateMarker() {
    if (_mapController == null) return;
    final mapService = context.read<MapProviderService>();

    if (mapService.isNaver) {
      _mapController!.clearOverlays();
      final marker = NMarker(id: 'loc', position: _selectedLatLng.toNaver());
      _mapController!.addNaverOverlay(marker);
      final circle = NCircleOverlay(
        id: 'radius_circle',
        center: _selectedLatLng.toNaver(),
        radius: _radius.toDouble(),
        color: AppColors.mapCircleFill,
        outlineColor: AppColors.mapCircleBorder,
        outlineWidth: 2,
      );
      _mapController!.addNaverOverlay(circle);
    } else if (mapService.isOsm) {
      setState(() {
        _osmMarkers = [
          fmap.Marker(
            point: _selectedLatLng.toOsm(),
            width: 40,
            height: 40,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        ];
        _osmCircles = [
          fmap.CircleMarker(
            point: _selectedLatLng.toOsm(),
            radius: _radius.toDouble(),
            useRadiusInMeter: true,
            color: AppColors.mapCircleFill,
            borderColor: AppColors.mapCircleBorder,
            borderStrokeWidth: 2,
          ),
        ];
      });
    } else {
      setState(() {
        _googleMarkers = {
          gmap.Marker(
            markerId: const gmap.MarkerId('loc'),
            position: _selectedLatLng.toGoogle(),
          ),
        };
        _googleCircles = {
          gmap.Circle(
            circleId: const gmap.CircleId('radius_circle'),
            center: _selectedLatLng.toGoogle(),
            radius: _radius.toDouble(),
            fillColor: AppColors.mapCircleFill,
            strokeColor: AppColors.mapCircleBorder,
            strokeWidth: 2,
          ),
        };
      });
    }
  }

  void _saveChanges() async {
    final l10n = AppLocalizations.of(context);
    final updatedLocation = {
      'id': widget.initialData['id'],
      'name': _nameController.text,
      'lat': _selectedLatLng.latitude,
      'lng': _selectedLatLng.longitude,
      'radius': _radius,
      'wifiNetworks': _selectedWifiNetworks,
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

    // 연결된 알람 수 확인
    final linkedCount = HiveHelper.getLinkedAlarmCount(widget.index);
    final msg =
        linkedCount > 0
            ? '${l10n.get('delete_place_msg')}\n\n${l10n.get('linked_alarm_delete_warning').replaceAll('{count}', '$linkedCount')}'
            : l10n.get('delete_place_msg');

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('delete_confirm_title')),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.get('delete')),
              ),
            ],
          ),
    );
    if (confirm != true) return;

    await HiveHelper.deleteLocationWithLinkedAlarms(widget.index);

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
                      _buildRadiusChip(30),
                      _buildRadiusChip(50),
                      _buildRadiusChip(100),
                      ChoiceChip(
                        label: Text(
                          ![30, 50, 100].contains(_radius)
                              ? '${_radius}m'
                              : l10n.get('custom'),
                        ),
                        selected: ![30, 50, 100].contains(_radius),
                        onSelected: (_) => _showCustomRadiusDialog(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_radius <= 30)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                        AppLocalizations.of(context).get('signal_warning'),
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
          // ── Wi-Fi 네트워크 선택 섹션 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: WifiSelectorWidget(
              initialNetworks: _selectedWifiNetworks,
              onChanged: (networks) {
                setState(() {
                  _selectedWifiNetworks = networks;
                });
              },
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                UnifiedMapWidget(
                  initialTarget: _selectedLatLng,
                  initialZoom: 16,
                  locationButtonEnable: true,
                  googleMarkers: _googleMarkers,
                  googleCircles: _googleCircles,
                  osmMarkers: _osmMarkers,
                  osmCircles: _osmCircles,
                  onMapReady: (controller) {
                    _mapController = controller;
                    // 사용량 트래킹
                    MapUsageService.onMapLoaded(controller.provider.name);
                    MapUsageService.incrementFreeUserOpenCount();
                    // 맵 전환 후 위치 및 마커 복원
                    _mapController?.updateCamera(_selectedLatLng, zoom: 16);
                    _updateMarker();
                  },
                  onMapTapped: (latLng) {
                    setState(() => _selectedLatLng = latLng);
                    _updateMarker();
                  },
                ),
                // 오른쪽 상단: 맵 토글 버튼 오버레이
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

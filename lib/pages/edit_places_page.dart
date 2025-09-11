import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/hive_helper.dart';

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
  double _radius = 100;
  late LatLng _selectedLatLng;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialData['name'] ?? '',
    );
    _radius = (widget.initialData['radius'] as num?)?.toDouble() ?? 100;
    _selectedLatLng = LatLng(
      widget.initialData['lat'] ?? 37.5665,
      widget.initialData['lng'] ?? 126.9780,
    );
  }

  void _saveChanges() async {
    final updatedLocation = {
      'name': _nameController.text,
      'lat': _selectedLatLng.latitude,
      'lng': _selectedLatLng.longitude,
      'radius': _radius.toInt(),
    };

    await HiveHelper.updateLocationAt(widget.index, updatedLocation);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ 장소가 수정되었습니다')));
    Navigator.pop(context, true);
  }

  void _deletePlace() async {
    await HiveHelper.deleteLocation(widget.index);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🗑 장소가 삭제되었습니다')));
    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('장소 편집')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '장소 이름'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: DropdownButton<double>(
              value: _radius,
              isExpanded: true,
              items:
                  [100, 150, 200, 250, 300].map((r) {
                    return DropdownMenuItem<double>(
                      value: r.toDouble(),
                      child: Text('${r.toInt()} m'),
                    );
                  }).toList(),
              onChanged: (val) => setState(() => _radius = val ?? 100),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLatLng,
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (latLng) => setState(() => _selectedLatLng = latLng),
              markers: {
                Marker(
                  markerId: const MarkerId('loc'),
                  position: _selectedLatLng,
                ),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _deletePlace,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.delete),
                label: const Text('삭제'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:ringinout/location_picker_page.dart';
import 'package:ringinout/add_alarm_page.dart';
import 'package:ringinout/hive_helper.dart';

class SavedLocationsPage extends StatefulWidget {
  const SavedLocationsPage({super.key});

  @override
  State<SavedLocationsPage> createState() => _SavedLocationsPageState();
}

class _SavedLocationsPageState extends State<SavedLocationsPage> {
  List<Map<String, dynamic>> savedLocations = [];

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  void _loadLocations() {
    setState(() {
      savedLocations = HiveHelper.getSavedLocations();
    });
  }

  void _navigateToLocationPicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => LocationPickerPage(
              onLocationSelected: (lat, lng, name, radius) async {
                await HiveHelper.addLocation({
                  'name': name,
                  'lat': lat,
                  'lng': lng,
                  'radius': radius,
                });
                _loadLocations();
              },
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null, // 🔹 제목 없는 AppBar 유지
      body:
          savedLocations.isEmpty
              ? Center(
                child: ElevatedButton.icon(
                  onPressed: _navigateToLocationPicker,
                  icon: const Icon(Icons.add_location_alt),
                  label: const Text('새 위치 추가'),
                ),
              )
              : ListView.builder(
                itemCount: savedLocations.length,
                itemBuilder: (context, index) {
                  final location = savedLocations[index];
                  return ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(location['name'] ?? '이름 없음'),
                    subtitle: Text('반경: ${location['radius']}m'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'add_alarm') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddAlarmPage(location: location),
                            ),
                          ).then((updatedLocation) {
                            if (updatedLocation != null) {
                              HiveHelper.updateLocation(updatedLocation);
                              _loadLocations();
                            }
                          });
                        } else if (value == 'edit_alarm') {
                          // TODO: 기존 알람 수정
                        } else if (value == 'edit_info') {
                          // TODO: 위치 정보 수정
                        } else if (value == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: const Text('삭제 확인'),
                                  content: const Text('정말로 이 위치를 삭제하시겠습니까?'),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                          );
                          if (confirm == true) {
                            await HiveHelper.deleteLocation(index);
                            _loadLocations();
                          }
                        }
                      },
                      itemBuilder:
                          (context) => const [
                            PopupMenuItem(
                              value: 'add_alarm',
                              child: Text('새 알람 추가'),
                            ),
                            PopupMenuItem(
                              value: 'edit_alarm',
                              child: Text('기존 알람 수정'),
                            ),
                            PopupMenuItem(
                              value: 'edit_info',
                              child: Text('정보 수정'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                '삭제',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                    ),
                  );
                },
              ),
      floatingActionButton:
          savedLocations.isNotEmpty
              ? FloatingActionButton(
                onPressed: _navigateToLocationPicker,
                tooltip: '새 위치 추가',
                child: const Icon(Icons.add),
              )
              : null,
    );
  }
}

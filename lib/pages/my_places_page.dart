import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_places_page.dart';
import 'package:ringinout/pages/add_myplaces_page.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

import 'package:provider/provider.dart';

class MyPlacesPage extends StatefulWidget {
  const MyPlacesPage({super.key});

  @override
  State<MyPlacesPage> createState() => _MyPlacesPageState();
}

class _MyPlacesPageState extends State<MyPlacesPage> {
  Offset fabPosition = const Offset(160, 400);
  String _sortOption = 'custom';
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    HiveHelper.init().then((_) async {
      final pos = await HiveHelper.getFabPosition();
      setState(() => fabPosition = pos);
    });
  }

  void _showSortOptions(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<String>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('sort_options')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l10n.get('sort_by_time')),
                  onTap: () => Navigator.pop(context, 'time'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: Text(l10n.get('sort_custom')),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
    );

    if (selected != null && selected != _sortOption) {
      setState(() {
        _sortOption = selected;
      });
    }
  }

  void _navigateToLocationPicker() async {
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

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => AddMyPlacesPage(
              onLocationSelected: (lat, lng, name, radius) async {
                await HiveHelper.addLocation({
                  'name': name,
                  'lat': lat,
                  'lng': lng,
                  'radius': radius,
                });

                final geofence = Geofence(
                  id: name,
                  latitude: lat,
                  longitude: lng,
                  radius: [
                    GeofenceRadius(id: 'default', length: radius.toDouble()),
                  ],
                );
                GeofenceService.instance.addGeofence(geofence);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ 장소가 저장되었습니다'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context, 'location_saved');
                }
              },
            ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortItems(
    List<Map<String, dynamic>> items,
    String option,
  ) {
    if (option == 'time') {
      return [...items]..sort(
        (a, b) => (a['time'] ?? '').toString().compareTo(
          (b['time'] ?? '').toString(),
        ),
      );
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ringinout 알람'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // 변경
        elevation: 0, // 그림자 제거(선택)
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortOptions(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                if (isSelectionMode)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.fromLTRB(16, 10, 0, 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selectedIndexes.length == items.length) {
                            selectedIndexes.clear();
                            isSelectionMode = false;
                          } else {
                            selectedIndexes = Set.from(
                              List.generate(items.length, (i) => i),
                            );
                          }
                        });
                      },
                      child: const Text(
                        '☑ 전체 선택',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "MyPlaces",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(Icons.place),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: HiveHelper.placeBox.listenable(),
                    builder: (context, Box box, _) {
                      final rawItems =
                          box.values
                              .whereType<Map>()
                              .map((e) => Map<String, dynamic>.from(e))
                              .toList();

                      items = _sortItems(rawItems, _sortOption);

                      if (items.isEmpty) {
                        return Column(
                          children: [
                            const Expanded(
                              child: Center(child: Text('저장된 장소가 없습니다.')),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final location = items[index];
                                return AnimatedPadding(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                    left: isSelectionMode ? 12.0 : 0.0,
                                    top: isSelectionMode ? 6.0 : 0.0,
                                  ),
                                  child: ListTile(
                                    leading:
                                        isSelectionMode
                                            ? Checkbox(
                                              value: selectedIndexes.contains(
                                                index,
                                              ),
                                              onChanged: (_) {
                                                setState(() {
                                                  if (selectedIndexes.contains(
                                                    index,
                                                  )) {
                                                    selectedIndexes.remove(
                                                      index,
                                                    );
                                                    if (selectedIndexes.isEmpty)
                                                      isSelectionMode = false;
                                                  } else {
                                                    selectedIndexes.add(index);
                                                  }
                                                });
                                              },
                                            )
                                            : const Icon(Icons.place),
                                    title: Text(location['name'] ?? '이름 없음'),
                                    subtitle: Text(
                                      '반경: ${location["radius"] ?? '?'}m',
                                    ),
                                    onTap: () async {
                                      if (isSelectionMode) {
                                        setState(() {
                                          if (selectedIndexes.contains(index)) {
                                            selectedIndexes.remove(index);
                                            if (selectedIndexes.isEmpty)
                                              isSelectionMode = false;
                                          } else {
                                            selectedIndexes.add(index);
                                          }
                                        });
                                      } else {
                                        final updated = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => EditPlacePage(
                                                  initialData: location,
                                                  index: index,
                                                ),
                                          ),
                                        );
                                        if (updated == true) setState(() {});
                                      }
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        isSelectionMode = true;
                                        selectedIndexes.add(index);
                                      });
                                    },
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) async {
                                        if (value == 'edit_places') {
                                          final updated = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => EditPlacePage(
                                                    initialData: location,
                                                    index: index,
                                                  ),
                                            ),
                                          );
                                          if (updated == true) setState(() {});
                                        } else if (value == 'add_alarm') {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (_) => AddLocationAlarmPage(
                                                    preSelectedPlace: location,
                                                  ),
                                            ),
                                          );
                                        } else if (value == 'delete') {
                                          final confirm = await showDialog<
                                            bool
                                          >(
                                            context: context,
                                            builder:
                                                (_) => AlertDialog(
                                                  title: const Text('삭제 확인'),
                                                  content: const Text(
                                                    '정말로 이 위치를 삭제하시겠습니까?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            false,
                                                          ),
                                                      child: const Text('취소'),
                                                    ),
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            context,
                                                            true,
                                                          ),
                                                      child: const Text('삭제'),
                                                    ),
                                                  ],
                                                ),
                                          );
                                          if (confirm == true) {
                                            await HiveHelper.deleteLocation(
                                              index,
                                            );
                                            setState(() {});
                                          }
                                        }
                                      },
                                      itemBuilder:
                                          (context) => const [
                                            PopupMenuItem(
                                              value: 'edit_places',
                                              child: Text('MyPlaces 편집'),
                                            ),
                                            PopupMenuItem(
                                              value: 'add_alarm',
                                              child: Text('새 알람 추가'),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(
                                                '삭제',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                    ),
                                  ),
                                );
                              },
                              separatorBuilder:
                                  (context, index) =>
                                      const Divider(height: 1, thickness: 1),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: fabPosition.dx,
            top: fabPosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  fabPosition += details.delta;
                });
              },
              onPanEnd: (_) async {
                await HiveHelper.saveFabPosition(
                  fabPosition.dx,
                  fabPosition.dy,
                );
              },
              child: FloatingActionButton(
                heroTag: 'my_places',
                shape: const CircleBorder(),
                elevation: 4,
                mini: true,
                backgroundColor: const Color.fromARGB(255, 0, 15, 150),
                foregroundColor: Colors.white,
                onPressed: _navigateToLocationPicker,
                tooltip: '새 위치 추가',
                child: const Icon(Icons.add_location_alt),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

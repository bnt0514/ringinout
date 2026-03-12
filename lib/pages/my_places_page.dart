import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_places_page.dart';
import 'package:ringinout/pages/add_myplaces_page.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

import 'package:provider/provider.dart';
import 'package:ringinout/services/billing_service.dart';

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
  SubscriptionPlan _plan = SubscriptionPlan.free;

  @override
  void initState() {
    super.initState();
    HiveHelper.init().then((_) async {
      final pos = await HiveHelper.getFabPosition();
      setState(() => fabPosition = pos);
    });
    SubscriptionService.getCurrentPlan().then((plan) {
      if (mounted) setState(() => _plan = plan);
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

                // 린 하이브리드: Hive에 저장하면 LMS가 자동으로 반영

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
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
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
                const SizedBox(height: 4),
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
                      final placeLimit = SubscriptionService.placeLimit(_plan);

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
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 12,
                                top: 4,
                                bottom: 100,
                              ),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final location = items[index];
                                final isLocked =
                                    SubscriptionService.isIndexLocked(
                                      index,
                                      placeLimit,
                                    );
                                return AnimatedPadding(
                                  duration: const Duration(milliseconds: 200),
                                  padding: EdgeInsets.only(
                                    left: isSelectionMode ? 8.0 : 0.0,
                                    top: isSelectionMode ? 4.0 : 0.0,
                                  ),
                                  child: Opacity(
                                    opacity: isLocked ? 0.5 : 1.0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color:
                                            isLocked
                                                ? AppColors.shimmer
                                                : AppColors.card,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color:
                                              isLocked
                                                  ? AppColors.divider
                                                  : selectedIndexes.contains(
                                                    index,
                                                  )
                                                  ? AppColors.primary
                                                      .withValues(alpha: 0.5)
                                                  : AppColors.divider,
                                          width:
                                              selectedIndexes.contains(index)
                                                  ? 1.5
                                                  : 1,
                                        ),
                                        boxShadow: AppStyle.softShadow,
                                      ),
                                      child: ListTile(
                                        leading:
                                            isLocked
                                                ? const Icon(
                                                  Icons.lock,
                                                  color: AppColors.divider,
                                                )
                                                : isSelectionMode
                                                ? Checkbox(
                                                  value: selectedIndexes
                                                      .contains(index),
                                                  onChanged: (_) {
                                                    setState(() {
                                                      if (selectedIndexes
                                                          .contains(index)) {
                                                        selectedIndexes.remove(
                                                          index,
                                                        );
                                                        if (selectedIndexes
                                                            .isEmpty) {
                                                          isSelectionMode =
                                                              false;
                                                        }
                                                      } else {
                                                        selectedIndexes.add(
                                                          index,
                                                        );
                                                      }
                                                    });
                                                  },
                                                )
                                                : const Icon(
                                                  Icons.place,
                                                  color: AppColors.primary,
                                                ),
                                        title: Text(
                                          location['name'] ?? '이름 없음',
                                          style: TextStyle(
                                            color:
                                                isLocked
                                                    ? AppColors.divider
                                                    : null,
                                          ),
                                        ),
                                        subtitle:
                                            isLocked
                                                ? Text(
                                                  '플랜 업그레이드 필요',
                                                  style: TextStyle(
                                                    color: AppColors.warning,
                                                    fontSize: 12,
                                                  ),
                                                )
                                                : Text(
                                                  '반경: ${location["radius"] ?? '?'}m',
                                                ),
                                        onTap: () async {
                                          if (isLocked) {
                                            await SubscriptionLimitDialog.showPlaceLimit(
                                              context,
                                              plan: _plan,
                                              limit: placeLimit!,
                                            );
                                            return;
                                          }
                                          if (isSelectionMode) {
                                            setState(() {
                                              if (selectedIndexes.contains(
                                                index,
                                              )) {
                                                selectedIndexes.remove(index);
                                                if (selectedIndexes.isEmpty) {
                                                  isSelectionMode = false;
                                                }
                                              } else {
                                                selectedIndexes.add(index);
                                              }
                                            });
                                          } else {
                                            final updated =
                                                await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) => EditPlacePage(
                                                          initialData: location,
                                                          index: index,
                                                        ),
                                                  ),
                                                );
                                            if (updated == true) {
                                              setState(() {});
                                            }
                                          }
                                        },
                                        onLongPress: () {
                                          setState(() {
                                            isSelectionMode = true;
                                            selectedIndexes.add(index);
                                          });
                                        },
                                        trailing:
                                            isLocked
                                                ? PopupMenuButton<String>(
                                                  onSelected: (value) async {
                                                    if (value == 'delete') {
                                                      final confirm = await showDialog<
                                                        bool
                                                      >(
                                                        context: context,
                                                        builder:
                                                            (_) => AlertDialog(
                                                              title: const Text(
                                                                '삭제 확인',
                                                              ),
                                                              content: const Text(
                                                                '잠긴 위치를 삭제하시겠습니까?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        '취소',
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        '삭제',
                                                                      ),
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
                                                      (context) => [
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            '삭제',
                                                            style: TextStyle(
                                                              color:
                                                                  AppColors
                                                                      .danger,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                )
                                                : PopupMenuButton<String>(
                                                  onSelected: (value) async {
                                                    if (value ==
                                                        'edit_places') {
                                                      final updated =
                                                          await Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (
                                                                    _,
                                                                  ) => EditPlacePage(
                                                                    initialData:
                                                                        location,
                                                                    index:
                                                                        index,
                                                                  ),
                                                            ),
                                                          );
                                                      if (updated == true)
                                                        setState(() {});
                                                    } else if (value ==
                                                        'add_alarm') {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                _,
                                                              ) => AddLocationAlarmPage(
                                                                preSelectedPlace:
                                                                    location,
                                                              ),
                                                        ),
                                                      );
                                                    } else if (value ==
                                                        'delete') {
                                                      final confirm = await showDialog<
                                                        bool
                                                      >(
                                                        context: context,
                                                        builder:
                                                            (_) => AlertDialog(
                                                              title: const Text(
                                                                '삭제 확인',
                                                              ),
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
                                                                  child:
                                                                      const Text(
                                                                        '취소',
                                                                      ),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child:
                                                                      const Text(
                                                                        '삭제',
                                                                      ),
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
                                                          child: Text(
                                                            'MyPlaces 편집',
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'add_alarm',
                                                          child: Text(
                                                            '새 알람 추가',
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            '삭제',
                                                            style: TextStyle(
                                                              color:
                                                                  AppColors
                                                                      .danger,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                ),
                                      ),
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
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: AppStyle.fabShadow,
                ),
                child: FloatingActionButton(
                  heroTag: 'my_places',
                  shape: const CircleBorder(),
                  elevation: 0,
                  mini: true,
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.textOnPrimary,
                  onPressed: _navigateToLocationPicker,
                  tooltip: '새 위치 추가',
                  child: const Icon(Icons.add_location_alt),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

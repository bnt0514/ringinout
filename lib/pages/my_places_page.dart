import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_places_page.dart';
import 'package:ringinout/pages/add_myplaces_page.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

class MyPlacesPage extends StatefulWidget {
  const MyPlacesPage({super.key});

  @override
  State<MyPlacesPage> createState() => _MyPlacesPageState();
}

class _MyPlacesPageState extends State<MyPlacesPage> {
  Offset fabPosition = const Offset(160, 400);
  String _sortOption = 'name_asc'; // 기본: 장소명 오름차순
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};
  List<MapEntry<int, Map<String, dynamic>>> items = [];
  SubscriptionPlan _plan = SubscriptionPlan.free;

  @override
  void initState() {
    super.initState();
    HiveHelper.init().then((_) async {
      final pos = await HiveHelper.getFabPosition();
      setState(() => fabPosition = pos);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentPlan();
    });
  }

  Future<void> _loadCurrentPlan() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (!mounted) return;
    setState(() => _plan = plan);
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
                _buildSortTile(
                  l10n.get('sort_place_asc'),
                  'name_asc',
                  Icons.sort_by_alpha,
                ),
                _buildSortTile(
                  l10n.get('sort_place_desc'),
                  'name_desc',
                  Icons.sort_by_alpha,
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

  Widget _buildSortTile(String title, String option, IconData icon) {
    final isSelected = _sortOption == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFFFF6B35) : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFFFF6B35) : null,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: Color(0xFFFF6B35)) : null,
      onTap: () => Navigator.pop(context, option),
    );
  }

  void _navigateToLocationPicker() async {
    final plan = await SubscriptionService.getCurrentPlan();
    final limit = SubscriptionService.placeLimit(plan);
    debugPrint(
      '🔍 [PlaceLimit] plan=$plan, limit=$limit, currentCount=${HiveHelper.placeBox.length}',
    );
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

    // 무료 유저 지도 오픈 제한 체크
    if (!await _checkMapOpenAllowed()) return;

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
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).get('place_saved_msg'),
                      ),
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

  List<MapEntry<int, Map<String, dynamic>>> _sortItems(
    List<MapEntry<int, Map<String, dynamic>>> items,
    String option,
  ) {
    final sorted = [...items];
    switch (option) {
      case 'name_asc':
        sorted.sort(
          (a, b) => (a.value['name'] ?? '').toString().toLowerCase().compareTo(
            (b.value['name'] ?? '').toString().toLowerCase(),
          ),
        );
        break;
      case 'name_desc':
        sorted.sort(
          (a, b) => (b.value['name'] ?? '').toString().toLowerCase().compareTo(
            (a.value['name'] ?? '').toString().toLowerCase(),
          ),
        );
        break;
    }
    return sorted;
  }

  /// 무료 유저 지도 오픈 허용 여부 확인
  /// - OSM이 기본이므로 장소 추가 시 제한 없이 바로 열기
  /// - 유료 플랜: 항상 true
  /// - 무료 플랜 + 한도 초과: false + 다이얼로그 표시 (제공자 전환 시 별도 처리)
  Future<bool> _checkMapOpenAllowed() async {
    // 유료 플랜이면 바로 통과
    final plan = await SubscriptionService.getCurrentPlan();
    if (plan != SubscriptionPlan.free) return true;

    // 무료 플랜: 기본 OSM으로 열리므로 카운트 체크 없이 바로 허용
    // (네이버/구글 전환 시 map_toggle_button에서 별도 안내)
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.get('page_title_places')),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
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
                      child: Text(
                        '☑ ${l10n.get('select_all')}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: HiveHelper.placeBox.listenable(),
                    builder: (context, Box box, _) {
                      final rawItems = List.generate(box.length, (index) {
                        final value = box.getAt(index);
                        return MapEntry(
                          index,
                          Map<String, dynamic>.from(value as Map),
                        );
                      });

                      items = _sortItems(rawItems, _sortOption);
                      final placeLimit = SubscriptionService.placeLimit(_plan);

                      if (items.isEmpty) {
                        return Column(
                          children: [
                            Expanded(
                              child: Center(child: Text(l10n.get('no_places'))),
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
                                final item = items[index];
                                final actualIndex = item.key;
                                final location = item.value;
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
                                                    actualIndex,
                                                  )
                                                  ? AppColors.primary
                                                      .withValues(alpha: 0.5)
                                                  : AppColors.divider,
                                          width:
                                              selectedIndexes.contains(
                                                    actualIndex,
                                                  )
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
                                                      .contains(actualIndex),
                                                  onChanged: (_) {
                                                    setState(() {
                                                      if (selectedIndexes
                                                          .contains(
                                                            actualIndex,
                                                          )) {
                                                        selectedIndexes.remove(
                                                          actualIndex,
                                                        );
                                                        if (selectedIndexes
                                                            .isEmpty) {
                                                          isSelectionMode =
                                                              false;
                                                        }
                                                      } else {
                                                        selectedIndexes.add(
                                                          actualIndex,
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
                                          location['name'] ??
                                              l10n.get('no_name_label'),
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
                                                  l10n.get(
                                                    'plan_upgrade_needed',
                                                  ),
                                                  style: TextStyle(
                                                    color: AppColors.warning,
                                                    fontSize: 12,
                                                  ),
                                                )
                                                : Text(
                                                  l10n.getWithArgs(
                                                    'radius_display',
                                                    {
                                                      'radius':
                                                          '${location["radius"] ?? "?"}',
                                                    },
                                                  ),
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
                                                actualIndex,
                                              )) {
                                                selectedIndexes.remove(
                                                  actualIndex,
                                                );
                                                if (selectedIndexes.isEmpty) {
                                                  isSelectionMode = false;
                                                }
                                              } else {
                                                selectedIndexes.add(
                                                  actualIndex,
                                                );
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
                                                          index: actualIndex,
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
                                            selectedIndexes.add(actualIndex);
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
                                                              title: Text(
                                                                l10n.get(
                                                                  'delete_confirm_title',
                                                                ),
                                                              ),
                                                              content: Text(
                                                                l10n.get(
                                                                  'delete_locked_msg',
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                                  child: Text(
                                                                    l10n.get(
                                                                      'cancel',
                                                                    ),
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child: Text(
                                                                    l10n.get(
                                                                      'delete',
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                      if (confirm == true) {
                                                        await HiveHelper.deleteLocation(
                                                          actualIndex,
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
                                                            l10n.get('delete'),
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
                                                      // 무료 유저 지도 오픈 제한 체크
                                                      if (!await _checkMapOpenAllowed())
                                                        return;
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
                                                                        actualIndex,
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
                                                              title: Text(
                                                                l10n.get(
                                                                  'delete_confirm_title',
                                                                ),
                                                              ),
                                                              content: Text(
                                                                l10n.get(
                                                                  'delete_place_msg',
                                                                ),
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                                  child: Text(
                                                                    l10n.get(
                                                                      'cancel',
                                                                    ),
                                                                  ),
                                                                ),
                                                                TextButton(
                                                                  onPressed:
                                                                      () => Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                                  child: Text(
                                                                    l10n.get(
                                                                      'delete',
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                      );
                                                      if (confirm == true) {
                                                        await HiveHelper.deleteLocation(
                                                          actualIndex,
                                                        );
                                                        setState(() {});
                                                      }
                                                    }
                                                  },
                                                  itemBuilder:
                                                      (context) => [
                                                        PopupMenuItem(
                                                          value: 'edit_places',
                                                          child: Text(
                                                            l10n.get(
                                                              'edit_places_menu',
                                                            ),
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'add_alarm',
                                                          child: Text(
                                                            l10n.get(
                                                              'add_alarm_menu',
                                                            ),
                                                          ),
                                                        ),
                                                        PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text(
                                                            l10n.get('delete'),
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
                  tooltip: l10n.get('add_place_tooltip'),
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

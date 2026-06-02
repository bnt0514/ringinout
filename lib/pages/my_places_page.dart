import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_places_page.dart';
import 'package:ringinout/pages/add_myplaces_page.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';
import 'package:provider/provider.dart';

class MyPlacesPage extends StatefulWidget {
  const MyPlacesPage({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<MyPlacesPage> createState() => MyPlacesPageState();
}

class MyPlacesPageState extends State<MyPlacesPage> {
  String _sortOption = 'name_asc'; // 기본: 장소명 오름차순
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};
  List<MapEntry<int, Map<String, dynamic>>> items = [];
  SubscriptionPlan _plan = SubscriptionPlan.free;
  bool _isOpeningPlacePicker = false;

  /// 장소에 Wi-Fi 네트워크가 등록되어 있는지 확인
  bool _placeHasWifi(Map<String, dynamic> place) {
    final wifi = place['wifiNetworks'];
    return wifi is List && wifi.isNotEmpty;
  }

  /// 장소에 블루투스 기기가 등록되어 있는지 확인
  bool _placeHasBluetooth(Map<String, dynamic> place) {
    final bt = place['bluetoothDevices'];
    return bt is List && bt.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentPlan();
    });
  }

  Future<void> _loadCurrentPlan() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (!mounted) return;
    setState(() => _plan = plan);
  }

  /// 외부(래퍼 페이지)에서 sort 다이얼로그를 호출할 수 있는 public 메서드
  void showSortOptionsFromParent() => _showSortOptions(context);

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
    if (_isOpeningPlacePicker) return;
    setState(() => _isOpeningPlacePicker = true);
    try {
      final plan = await SubscriptionService.getCurrentPlan();
      final limit = SubscriptionService.placeLimit(plan);
      final currentCount = HiveHelper.getSavedLocations().length;
      debugPrint(
        '🔍 [PlaceLimit] plan=$plan, limit=$limit, currentCount=$currentCount',
      );
      if (limit != null) {
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

      if (!mounted) return;
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
    } finally {
      if (mounted) {
        setState(() => _isOpeningPlacePicker = false);
      }
    }
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
  Future<bool> _checkMapOpenAllowed() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (plan != SubscriptionPlan.free) return true;

    final provider = context.read<MapProviderService>().provider.name;
    final allowed = await MapUsageService.canOpenMap(provider: provider);
    if (allowed) return true;
    if (!mounted) return false;

    final l10n = AppLocalizations.of(context);
    await showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('map_free_limit_exceeded_title')),
            content: Text(l10n.get('map_free_limit_exceeded_body')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.get('map_switch_btn_cancel')),
              ),
            ],
          ),
    );
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        AbsorbPointer(
          absorbing: _isOpeningPlacePicker,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar:
                widget.showAppBar
                    ? AppBar(
                      title: Text(l10n.get('page_title_places')),
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      elevation: 0,
                      flexibleSpace: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
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
                              MaterialPageRoute(
                                builder: (context) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    )
                    : null,
            body: Column(
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
                            selectedIndexes =
                                items.map((item) => item.key).toSet();
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
                      items = _sortItems(
                        HiveHelper.getVisiblePlaceEntries(),
                        _sortOption,
                      );
                      final placeLimit = SubscriptionService.placeLimit(_plan);

                      if (items.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.get('no_places'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.get('no_places_desc'),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed:
                                    _isOpeningPlacePicker
                                        ? null
                                        : _navigateToLocationPicker,
                                icon:
                                    _isOpeningPlacePicker
                                        ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(Icons.add_location_alt),
                                label: Text(
                                  _isOpeningPlacePicker
                                      ? l10n.get('place_map_loading_short')
                                      : l10n.get('add_place_btn'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
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
                                bottom: 12,
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
                                                : Row(
                                                  children: [
                                                    Text(
                                                      l10n.getWithArgs(
                                                        'radius_display',
                                                        {
                                                          'radius':
                                                              '${location["radius"] ?? "?"}',
                                                        },
                                                      ),
                                                    ),
                                                    if (_placeHasWifi(
                                                      location,
                                                    )) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.wifi,
                                                        size: 14,
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ),
                                                    ],
                                                    if (_placeHasBluetooth(
                                                      location,
                                                    )) ...[
                                                      const SizedBox(width: 8),
                                                      Icon(
                                                        Icons.bluetooth,
                                                        size: 14,
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                      ),
                                                    ],
                                                  ],
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
                                                      final linkedCount =
                                                          HiveHelper.getLinkedAlarmCount(
                                                            actualIndex,
                                                          );
                                                      final msg =
                                                          linkedCount > 0
                                                              ? '${l10n.get('delete_locked_msg')}\n\n${l10n.get('linked_alarm_delete_warning').replaceAll('{count}', '$linkedCount')}'
                                                              : l10n.get(
                                                                'delete_locked_msg',
                                                              );
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
                                                                msg,
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
                                                        await HiveHelper.deleteLocationWithLinkedAlarms(
                                                          actualIndex,
                                                        );
                                                        await SmartLocationService.updatePlaces();
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
                                                      if (!await _checkMapOpenAllowed()) {
                                                        return;
                                                      }
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
                                                      if (updated == true) {
                                                        setState(() {});
                                                      }
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
                                                      final linkedCount =
                                                          HiveHelper.getLinkedAlarmCount(
                                                            actualIndex,
                                                          );
                                                      final msg =
                                                          linkedCount > 0
                                                              ? '${l10n.get('delete_place_msg')}\n\n${l10n.get('linked_alarm_delete_warning').replaceAll('{count}', '$linkedCount')}'
                                                              : l10n.get(
                                                                'delete_place_msg',
                                                              );
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
                                                                msg,
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
                                                        await HiveHelper.deleteLocationWithLinkedAlarms(
                                                          actualIndex,
                                                        );
                                                        await SmartLocationService.updatePlaces();
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
                          if (!isSelectionMode) _buildFixedAddBar(l10n),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isOpeningPlacePicker)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Container(
                  width: 220,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        l10n.get('place_map_loading'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFixedAddBar(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(
          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isOpeningPlacePicker ? null : _navigateToLocationPicker,
            icon:
                _isOpeningPlacePicker
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.add_location_alt, size: 20),
            label: Text(
              _isOpeningPlacePicker
                  ? l10n.get('place_map_loading_short')
                  : l10n.get('add_place_btn'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

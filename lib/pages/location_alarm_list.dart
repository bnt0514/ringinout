// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/utils/alarm_activation_notice.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

// 컨트롤러
class AlarmListController {
  // ★ 정적 인스턴스 (MainNavigationPage에서 접근 가능)
  static AlarmListController? _instance;
  static AlarmListController? get instance => _instance;

  AlarmListController() {
    _instance = this;
  }

  final ValueNotifier<bool> isSelectionMode = ValueNotifier(false);
  final ValueNotifier<Set<int>> selectedIndexes = ValueNotifier({});

  void toggleSelection(int index) {
    final newSet = Set<int>.from(selectedIndexes.value);
    if (newSet.contains(index)) {
      newSet.remove(index);
    } else {
      newSet.add(index);
    }
    selectedIndexes.value = newSet;
    isSelectionMode.value = newSet.isNotEmpty;
  }

  void toggleAll(Iterable<int> indexes) {
    final allIndexes = indexes.toSet();
    if (selectedIndexes.value.length == allIndexes.length &&
        selectedIndexes.value.containsAll(allIndexes)) {
      selectedIndexes.value = {};
    } else {
      selectedIndexes.value = allIndexes;
    }
  }

  Future<void> deleteSelected() async {
    final box = HiveHelper.alarmBox;

    // ✅ 스누즈 박스와 트리거 카운트 박스 열기
    final snoozeBox = await Hive.openBox('snoozeSchedules');
    final triggerBox = await Hive.openBox('trigger_counts_v2');

    // ✅ 선택된 인덱스를 역순으로 정렬 (뒤에서부터 삭제해야 인덱스가 밀리지 않음)
    final sortedIndexes =
        selectedIndexes.value.toList()..sort((a, b) => b.compareTo(a));

    // ✅ 먼저 삭제할 알람들의 정보를 수집
    final alarmsToDelete = <Map<String, dynamic>>[];
    final keysToDelete = <dynamic>[];

    for (int i in sortedIndexes) {
      final alarm = box.getAt(i);
      if (alarm != null) {
        alarmsToDelete.add(Map<String, dynamic>.from(alarm));
        keysToDelete.add(box.keyAt(i));
      }
    }

    // ✅ 관련 데이터 삭제 (스누즈, 트리거 카운트)
    for (final alarm in alarmsToDelete) {
      final alarmId = alarm['id'];
      if (alarmId != null) {
        await snoozeBox.delete(alarmId);
        await triggerBox.delete(alarmId);
        print('🗑️ 알람 관련 데이터 삭제: $alarmId');
      }
    }

    // ✅ 역순으로 알람 삭제 (인덱스 밀림 방지)
    for (final key in keysToDelete) {
      await box.delete(key);
      print('🗑️ 알람 삭제 완료: $key');
    }

    selectedIndexes.value = {};
    isSelectionMode.value = false;

    // ✅ 삭제 후 heartbeat 전송 (활성 알람 수 동기화)
    await LocationMonitorService.sendWatchdogHeartbeat();
    print('🗑️ 총 ${alarmsToDelete.length}개 알람 삭제 후 Heartbeat 전송 완료');
  }
}

// 알람 아이템 위젯
class AlarmListItem extends StatelessWidget {
  final Map<String, dynamic> alarm;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isLocked;
  final Function(int) onSelect;
  final Function(int) onTap;

  const AlarmListItem({
    super.key,
    required this.alarm,
    required this.index,
    required this.isSelected,
    required this.isSelectionMode,
    this.isLocked = false,
    required this.onSelect,
    required this.onTap,
  });

  String _getSubtitle(AppLocalizations l10n) {
    final repeat = alarm['repeat'];
    final triggerKey =
        alarm['trigger'] == 'entry' ? 'entry_trigger' : 'exit_trigger';
    final trigger = l10n.get(triggerKey);
    final parts = <String>[];

    // ✅ 날짜 조건
    if (repeat is String) {
      final date = DateTime.tryParse(repeat);
      if (date != null) {
        parts.add(
          '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
        );
      }
    }

    // ✅ 요일 조건 — 구 데이터("월" 등) → 코드("mon") → 현재 언어 번역
    if (repeat is List && repeat.isNotEmpty) {
      const weekdayCodeMap = {
        '일': 'sun',
        '월': 'mon',
        '화': 'tue',
        '수': 'wed',
        '목': 'thu',
        '금': 'fri',
        '토': 'sat',
        '日': 'sun',
        '月': 'mon',
        '火': 'tue',
        '水': 'wed',
        '木': 'thu',
        '金': 'fri',
        '土': 'sat',
        '一': 'mon',
        '二': 'tue',
        '三': 'wed',
        '四': 'thu',
        '五': 'fri',
        '六': 'sat',
        'Sun': 'sun',
        'Mon': 'mon',
        'Tue': 'tue',
        'Wed': 'wed',
        'Thu': 'thu',
        'Fri': 'fri',
        'Sat': 'sat',
      };
      final translated = repeat
          .map((d) {
            final raw = d.toString();
            final code = weekdayCodeMap[raw] ?? raw;
            return l10n.get(code);
          })
          .join(', ');
      parts.add(l10n.getWithArgs('weekly_prefix', {'days': translated}));
    }

    // ✅ 시간 조건 (hour/minute 또는 startTimeMs)
    final h = alarm['hour'];
    final m = alarm['minute'];
    if (h != null) {
      final period = l10n.get(h >= 12 ? 'pm_label' : 'am_label');
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      parts.add(
        '$period $hour12${l10n.get('hour_suffix')}${(m ?? 0).toString().padLeft(2, '0')}${l10n.get('min_suffix')}${l10n.get('after_suffix')}',
      );
    } else {
      final startTimeMs = alarm['startTimeMs'];
      if (startTimeMs is int && startTimeMs > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
        final period = l10n.get(dt.hour >= 12 ? 'pm_label' : 'am_label');
        final hour12 =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        parts.add(
          '$period $hour12${l10n.get('hour_suffix')}${dt.minute.toString().padLeft(2, '0')}${l10n.get('min_suffix')}${l10n.get('after_suffix')}',
        );
      }
    }

    if (parts.isEmpty) {
      return l10n.getWithArgs('first_trigger_immediate', {'trigger': trigger});
    }
    return l10n.getWithArgs('first_trigger_condition', {
      'conditions': parts.join(' '),
      'trigger': trigger,
    });
  }

  Widget _buildTriggerIcon() {
    final Color iconColor = isLocked ? AppColors.divider : AppColors.primary;
    final bool isExit = alarm['trigger'] == 'exit';
    final places = HiveHelper.getSavedLocations();
    final place = AlarmDetectionMode.findPlaceForAlarm(alarm, places);
    final mode = AlarmDetectionMode.resolve(
      alarm,
      place: place,
      places: places,
    );

    return SizedBox(
      width: 36,
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 2,
            top: 3,
            child: Container(
              width: 8,
              height: 18,
              decoration: BoxDecoration(
                border: Border.all(color: iconColor, width: 1.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            left: 6,
            top: 10,
            child: Container(
              width: 2.5,
              height: 2.5,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Positioned(
            right: 10,
            child: Icon(
              isExit ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
              color: iconColor,
              size: 16,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Icon(
              mode == AlarmDetectionMode.wifi ? Icons.wifi : Icons.gps_fixed,
              color: iconColor.withValues(alpha: 0.75),
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Opacity(
      opacity: isLocked ? 0.5 : 1.0,
      child: GestureDetector(
        onLongPress: () => onSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform:
              isSelectionMode
                  ? Matrix4.translationValues(10, 0, 0)
                  : Matrix4.identity(),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Container(
            decoration: BoxDecoration(
              color: isLocked ? AppColors.shimmer : AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: AppStyle.softShadow,
            ),
            child: Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (bool? checked) => onSelect(index),
                  ),
                Expanded(
                  child: ListTile(
                    leading: _buildTriggerIcon(),
                    title: Text(
                      alarm['name'] ?? l10n.get('no_name_label'),
                      style: TextStyle(
                        color: isLocked ? AppColors.divider : null,
                      ),
                    ),
                    subtitle:
                        isLocked
                            ? Text(
                              l10n.get('plan_upgrade_needed'),
                              style: const TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                              ),
                            )
                            : Text(_getSubtitle(l10n)),
                    onTap: isLocked ? null : () => onTap(index),
                  ),
                ),
                if (!isSelectionMode && !isLocked) _buildEnableSwitch(context),
                if (!isSelectionMode && isLocked)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(Icons.lock, color: AppColors.divider),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnableSwitch(BuildContext context) {
    return GestureDetector(
      // ✅ opaque: 자식이 paint하지 않는 빈 영역도 터치 인식
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final willEnable = !(alarm['enabled'] ?? false);
        final alarmId = alarm['id'];

        // ✅ 활성화 시 구독 한도 체크 (백그라운드에서 검증 후 롤백)
        if (willEnable) {
          // UI 먼저 낙관적으로 업데이트
          final updatedAlarm = Map<String, dynamic>.from(alarm);
          updatedAlarm['enabled'] = true;
          updatedAlarm['snoozePending'] = false;
          updatedAlarm['triggerCount'] = 0;
          if (alarmId is String) {
            await HiveHelper.updateLocationAlarmById(alarmId, updatedAlarm);
          } else {
            await HiveHelper.updateLocationAlarm(index, updatedAlarm);
          }
          print('🔄 알람 활성화: ${alarm['name']}');

          final place = AlarmDetectionMode.findPlaceForAlarm(
            updatedAlarm,
            HiveHelper.getSavedLocations(),
          );
          if (context.mounted) {
            await AlarmActivationNotice.showIfNeeded(
              context,
              updatedAlarm,
              place,
            );
          }

          // 구독 한도 체크는 백그라운드에서
          Future.microtask(() async {
            final plan = await SubscriptionService.getCurrentPlan();
            final limit = SubscriptionService.alarmLimit(plan);
            if (limit != null) {
              final totalCount = HiveHelper.getLocationAlarms().length;
              if (totalCount > limit) {
                // 한도 초과: 롤백
                final rollback = Map<String, dynamic>.from(alarm);
                rollback['enabled'] = false;
                if (alarmId is String) {
                  await HiveHelper.updateLocationAlarmById(alarmId, rollback);
                } else {
                  await HiveHelper.updateLocationAlarm(index, rollback);
                }
                if (context.mounted) {
                  await SubscriptionLimitDialog.showAlarmLimit(
                    context,
                    plan: plan,
                    limit: limit,
                  );
                }
                return;
              }
            }
            // 트리거 카운트 초기화 + 상태 리셋
            if (alarmId != null) {
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
            }
            await _resetAlarmState(alarm['name'] ?? '');
            await _updateMonitoringService();
          });
        } else {
          // 비활성화: 즉시 처리
          final updatedAlarm = Map<String, dynamic>.from(alarm);
          updatedAlarm['enabled'] = false;
          updatedAlarm['snoozePending'] = false;
          if (alarmId is String) {
            await HiveHelper.updateLocationAlarmById(alarmId, updatedAlarm);
          } else {
            await HiveHelper.updateLocationAlarm(index, updatedAlarm);
          }
          print('🔄 알람 비활성화: ${alarm['name']}');

          Future.microtask(() async {
            if (alarmId != null) {
              final snoozeBox = await Hive.openBox('snoozeSchedules');
              await snoozeBox.delete(alarmId);
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
            }
            await _updateMonitoringService();
          });
        }
      },
      child: Container(
        width: 64,
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.divider)),
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  (alarm['enabled'] ?? false)
                      ? AppColors.active
                      : AppColors.inactive,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: (alarm['enabled'] ?? false) ? 20 : 12,
                height: (alarm['enabled'] ?? false) ? 20 : 12,
                decoration: const BoxDecoration(
                  color: AppColors.toggleThumb,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetAlarmState(String placeName) async {
    try {
      // LocationMonitorService의 상태 초기화 호출
      await SmartLocationMonitor.resetPlaceState(placeName);
      print('🔄 알람 상태 초기화: $placeName');
    } catch (e) {
      print('❌ 알람 상태 초기화 실패: $e');
    }
  }

  // ✅ 올바른 모니터링 서비스 업데이트 메서드
  Future<void> _updateMonitoringService() async {
    try {
      final activeAlarms =
          HiveHelper.getLocationAlarms()
              .where((alarm) => alarm['enabled'] == true)
              .toList();

      if (activeAlarms.isEmpty) {
        await SmartLocationService.stopMonitoring();
      } else {
        await SmartLocationService.updatePlaces();
      }

      // ✅ Watchdog heartbeat 즉시 전송 (활성 알람 수 동기화)
      await LocationMonitorService.sendWatchdogHeartbeat();

      print('🔄 스마트 모니터링 서비스 재시작 + Heartbeat 전송 완료');
    } catch (e) {
      print('❌ 모니터링 서비스 재시작 실패: $e');
    }
  }
}

// 메인 위젯
class LocationAlarmList extends StatefulWidget {
  const LocationAlarmList({super.key});

  /// 외부(AlarmPage)에서 정렬 다이얼로그 호출
  static void showSortDialog() => _LocationAlarmListState.showSortDialog();

  @override
  State<LocationAlarmList> createState() => _LocationAlarmListState();
}

class _LocationAlarmListState extends State<LocationAlarmList> {
  static _LocationAlarmListState? _instance;
  final _controller = AlarmListController();
  final _platform = const MethodChannel('ringinout_channel');
  SubscriptionPlan _plan = SubscriptionPlan.free;
  String _sortOption = 'place_asc'; // 기본: 장소명 오름차순

  /// 외부(AlarmPage)에서 정렬 다이얼로그 호출용
  static void showSortDialog() => _instance?._showSortOptions();

  /// 알람 그룹의 장소가 Wi-Fi 등록되어 있는지 확인
  bool _placeGroupHasWifi(
    List<MapEntry<int, Map<String, dynamic>>> groupAlarms,
  ) {
    if (groupAlarms.isEmpty) return false;
    final alarm = groupAlarms.first.value;

    // 1) placeId로 먼저 조회
    final placeId = alarm['placeId']?.toString();
    if (placeId != null && placeId.isNotEmpty) {
      if (HiveHelper.getWifiNetworksForPlace(placeId).isNotEmpty) return true;
    }

    // 2) 장소명으로 폴백 조회 (placeId가 없거나 매칭 실패 시)
    final placeName =
        (alarm['place'] ?? alarm['locationName'] ?? '').toString();
    if (placeName.isEmpty) return false;
    final places = HiveHelper.getSavedLocations();
    for (final place in places) {
      final pName = (place['name'] ?? '').toString();
      if (pName == placeName) {
        if (HiveHelper.placeHasWifi(place)) return true;
      }
    }
    return false;
  }

  /// ✅ 알람 그룹의 장소가 블루투스 등록되어 있는지 확인
  bool _placeGroupHasBluetooth(
    List<MapEntry<int, Map<String, dynamic>>> groupAlarms,
  ) {
    if (groupAlarms.isEmpty) return false;
    final alarm = groupAlarms.first.value;

    // 1) placeId로 먼저 조회
    final placeId = alarm['placeId']?.toString();
    if (placeId != null && placeId.isNotEmpty) {
      if (HiveHelper.getBluetoothDevicesForPlace(placeId).isNotEmpty) {
        return true;
      }
    }

    // 2) 장소명으로 폴백 조회
    final placeName =
        (alarm['place'] ?? alarm['locationName'] ?? '').toString();
    if (placeName.isEmpty) return false;
    final places = HiveHelper.getSavedLocations();
    for (final place in places) {
      final pName = (place['name'] ?? '').toString();
      if (pName == placeName) {
        if (HiveHelper.placeHasBluetooth(place)) return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentPlan();
      _setupMethodChannel();
    });
  }

  Future<void> _loadCurrentPlan() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (!mounted) return;
    setState(() => _plan = plan);
  }

  List<MapEntry<int, Map<String, dynamic>>> _sortAlarms(
    List<MapEntry<int, Map<String, dynamic>>> alarms,
  ) {
    final indexed = [...alarms];

    switch (_sortOption) {
      case 'place_asc':
        indexed.sort((a, b) {
          final pa =
              (a.value['place'] ?? a.value['locationName'] ?? '')
                  .toString()
                  .toLowerCase();
          final pb =
              (b.value['place'] ?? b.value['locationName'] ?? '')
                  .toString()
                  .toLowerCase();
          return pa.compareTo(pb);
        });
        break;
      case 'place_desc':
        indexed.sort((a, b) {
          final pa =
              (a.value['place'] ?? a.value['locationName'] ?? '')
                  .toString()
                  .toLowerCase();
          final pb =
              (b.value['place'] ?? b.value['locationName'] ?? '')
                  .toString()
                  .toLowerCase();
          return pb.compareTo(pa);
        });
        break;
      case 'name_asc':
        indexed.sort((a, b) {
          final na = (a.value['name'] ?? '').toString().toLowerCase();
          final nb = (b.value['name'] ?? '').toString().toLowerCase();
          return na.compareTo(nb);
        });
        break;
      case 'name_desc':
        indexed.sort((a, b) {
          final na = (a.value['name'] ?? '').toString().toLowerCase();
          final nb = (b.value['name'] ?? '').toString().toLowerCase();
          return nb.compareTo(na);
        });
        break;
    }
    return indexed;
  }

  void _showSortOptions() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('sort_options')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sortTile(l10n.get('sort_place_asc'), 'place_asc', Icons.place),
                _sortTile(
                  l10n.get('sort_place_desc'),
                  'place_desc',
                  Icons.place,
                ),
                const Divider(),
                _sortTile(
                  l10n.get('sort_name_asc'),
                  'name_asc',
                  Icons.sort_by_alpha,
                ),
                _sortTile(
                  l10n.get('sort_name_desc'),
                  'name_desc',
                  Icons.sort_by_alpha,
                ),
              ],
            ),
          ),
    );
  }

  Widget _sortTile(String title, String option, IconData icon) {
    final isSelected = _sortOption == option;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : null),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () {
        setState(() => _sortOption = option);
        Navigator.pop(context);
      },
    );
  }

  void _setupMethodChannel() {
    _platform.setMethodCallHandler((call) async {
      if (call.method == 'navigateToFullScreenAlarm') {
        print('📨 navigateToFullScreenAlarm 수신: ${call.arguments}');

        // ✅ alarmId를 arguments에서 가져오기
        final args = call.arguments as Map?;
        final alarmId = args?['alarmId'] ?? -1;

        print('🔔 전체화면 알람 페이지로 이동 (alarmId: $alarmId)');

        // ✅ alarmId를 포함하여 전달
        Navigator.of(context).pushNamed(
          '/fullScreenAlarm',
          arguments: {
            'alarmTitle': 'Ringinout',
            'id': alarmId,
            'soundPath': 'assets/sounds/thoughtfulringtone.mp3',
          },
        );
      }
    });
  }

  void _handleAlarmTap(int index) {
    if (_controller.isSelectionMode.value) {
      _controller.toggleSelection(index);
    } else {
      final alarmRaw = HiveHelper.alarmBox.getAt(index);
      final alarm = Map<String, dynamic>.from(alarmRaw as Map);
      Navigator.pushNamed(
        context,
        '/edit_location_alarm',
        arguments: {'index': index, 'existingAlarmData': alarm},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveHelper.alarmBox.listenable(),
      builder: (context, Box alarmBox, _) {
        final visibleAlarmIndexes =
            HiveHelper.getVisibleAlarmEntries()
                .map((entry) => entry.key)
                .toSet();
        return ValueListenableBuilder(
          valueListenable: _controller.isSelectionMode,
          builder: (context, isSelectionMode, _) {
            return PopScope(
              canPop: !isSelectionMode,
              onPopInvoked: (didPop) {
                if (!didPop && isSelectionMode) {
                  _controller.isSelectionMode.value = false;
                  _controller.selectedIndexes.value = {};
                }
              },
              child: Column(
                children: [
                  if (isSelectionMode) _buildSelectionHeader(),
                  Expanded(child: _buildAlarmList()),
                  if (!isSelectionMode && visibleAlarmIndexes.isNotEmpty)
                    _buildFixedAddBar(),
                  if (isSelectionMode) _buildDeleteBar(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlarmList() {
    // ★ placeBox도 함께 감시 — 장소 Wi-Fi 변경 시 알람 목록도 즉시 갱신
    return ValueListenableBuilder(
      valueListenable: HiveHelper.placeBox.listenable(),
      builder:
          (context, _, __) => ValueListenableBuilder(
            valueListenable: HiveHelper.alarmBox.listenable(),
            builder: (context, Box box, _) {
              final alarms = HiveHelper.getVisibleAlarmEntries();
              if (alarms.isEmpty) {
                final l10n = AppLocalizations.of(context);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.alarm_off,
                        size: 64,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.get('no_saved_alarms'),
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.get('no_saved_alarms_desc'),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed:
                            () => Navigator.pushNamed(
                              context,
                              '/add_location_alarm',
                            ),
                        icon: const Icon(Icons.add),
                        label: Text(l10n.get('add_alarm_btn')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // ✅ 활성 알람 개수 확인
              final activeCount =
                  alarms.where((a) => a.value['enabled'] == true).length;
              final sorted = _sortAlarms(alarms);

              // ✅ 장소별 그룹핑 (정렬된 순서 유지)
              final groups =
                  <String, List<MapEntry<int, Map<String, dynamic>>>>{};
              for (final entry in sorted) {
                final placeName =
                    (entry.value['place'] ?? entry.value['locationName'] ?? '')
                        .toString();
                final groupKey = placeName.isEmpty ? '__other__' : placeName;
                groups.putIfAbsent(groupKey, () => []).add(entry);
              }

              return ValueListenableBuilder(
                valueListenable: _controller.selectedIndexes,
                builder: (context, selectedIndexes, _) {
                  final groupKeys = groups.keys.toList();
                  // '__other__'를 항상 맨 뒤로
                  if (groupKeys.remove('__other__')) {
                    groupKeys.add('__other__');
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 8, bottom: 12),
                          itemCount: groupKeys.length,
                          itemBuilder: (context, groupIndex) {
                            final groupKey = groupKeys[groupIndex];
                            final groupAlarms = groups[groupKey]!;
                            final l10n = AppLocalizations.of(context);
                            final displayName =
                                groupKey == '__other__'
                                    ? l10n.get('other_places')
                                    : groupKey;
                            final alarmLimit = SubscriptionService.alarmLimit(
                              _plan,
                            );

                            return _PlaceGroupCard(
                              placeName: displayName,
                              alarms: groupAlarms,
                              selectedIndexes: selectedIndexes,
                              isSelectionMode:
                                  _controller.isSelectionMode.value,
                              alarmLimit: alarmLimit,
                              hasWifi: _placeGroupHasWifi(groupAlarms),
                              hasBluetooth: _placeGroupHasBluetooth(
                                groupAlarms,
                              ),
                              onSelect: _controller.toggleSelection,
                              onTap: _handleAlarmTap,
                            );
                          },
                        ),
                      ),
                      // ✅ 활성 알람이 있을 때만 안내 문구 표시
                      if (activeCount > 0)
                        Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppStyle.spacingBase,
                                vertical: AppStyle.spacingMd,
                              ),
                              color: AppColors.shimmer,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: l10n.get(
                                              'battery_info_text_prefix',
                                            ),
                                          ),
                                          WidgetSpan(
                                            alignment:
                                                PlaceholderAlignment.middle,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  onTap: () async {
                                                    await PermissionManager.openBatteryOptimizationSettings();
                                                  },
                                                  child: Ink(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary
                                                          .withValues(
                                                            alpha: 0.10,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.22,
                                                            ),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      l10n.get(
                                                        'battery_info_text_action',
                                                      ),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            AppColors.primary,
                                                        height: 1.2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          TextSpan(
                                            text: l10n.get(
                                              'battery_info_text_suffix',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              );
            },
          ),
    );
  }

  Widget _buildSelectionHeader() {
    final visibleIndexes =
        HiveHelper.getVisibleAlarmEntries().map((entry) => entry.key).toSet();
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(16, 10, 0, 4),
      child: GestureDetector(
        onTap: () => _controller.toggleAll(visibleIndexes),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder(
              valueListenable: _controller.selectedIndexes,
              builder: (context, selectedIndexes, _) {
                final allSelected =
                    visibleIndexes.isNotEmpty &&
                    selectedIndexes.length == visibleIndexes.length &&
                    selectedIndexes.containsAll(visibleIndexes);
                return Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color:
                      allSelected ? AppColors.primary : AppColors.textSecondary,
                );
              },
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context).get('select_all'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteBar() {
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
            onPressed: _controller.deleteSelected,
            icon: const Icon(Icons.delete, size: 20),
            label: Text(AppLocalizations.of(context).get('delete')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
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

  Widget _buildFixedAddBar() {
    final l10n = AppLocalizations.of(context);
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
            onPressed:
                () => Navigator.pushNamed(context, '/add_location_alarm'),
            icon: const Icon(Icons.alarm_add, size: 20),
            label: Text(l10n.get('add_alarm_btn')),
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

// ═══════════════════════════════════════════════════════════
//  장소별 그룹 카드 위젯 (순수 UI — 알람 트리거 로직 무관)
// ═══════════════════════════════════════════════════════════
class _PlaceGroupCard extends StatefulWidget {
  final String placeName;
  final List<MapEntry<int, Map<String, dynamic>>> alarms;
  final Set<int> selectedIndexes;
  final bool isSelectionMode;
  final int? alarmLimit;
  final bool hasWifi;
  final bool hasBluetooth;
  final Function(int) onSelect;
  final Function(int) onTap;

  const _PlaceGroupCard({
    required this.placeName,
    required this.alarms,
    required this.selectedIndexes,
    required this.isSelectionMode,
    required this.alarmLimit,
    this.hasWifi = false,
    this.hasBluetooth = false,
    required this.onSelect,
    required this.onTap,
  });

  @override
  State<_PlaceGroupCard> createState() => _PlaceGroupCardState();
}

class _PlaceGroupCardState extends State<_PlaceGroupCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final alarmCount = widget.alarms.length;
    final activeCount =
        widget.alarms.where((e) => e.value['enabled'] == true).length;
    final countText =
        alarmCount == 1
            ? l10n.get('alarm_count_one')
            : l10n.getWithArgs('alarm_count', {'count': alarmCount.toString()});

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 그룹 헤더
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.place, color: AppColors.primary, size: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.gps_fixed,
                      color: AppColors.primary.withValues(alpha: 0.7),
                      size: 16,
                    ),
                  ),
                  if (widget.hasWifi)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.wifi,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        size: 16,
                      ),
                    ),
                  if (widget.hasBluetooth)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        Icons.bluetooth,
                        color: AppColors.primary.withValues(alpha: 0.7),
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.placeName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$countText · $activeCount ${l10n.get('alarm_enabled').toLowerCase()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 선택 모드에서 그룹 전체 선택/해제
                  if (widget.isSelectionMode)
                    GestureDetector(
                      onTap: () {
                        final groupIndexes =
                            widget.alarms.map((e) => e.key).toSet();
                        final allSelected = groupIndexes.every(
                          widget.selectedIndexes.contains,
                        );
                        for (final idx in groupIndexes) {
                          if (allSelected) {
                            // 전체 해제: 선택된 것만 토글
                            if (widget.selectedIndexes.contains(idx)) {
                              widget.onSelect(idx);
                            }
                          } else {
                            // 전체 선택: 선택 안 된 것만 토글
                            if (!widget.selectedIndexes.contains(idx)) {
                              widget.onSelect(idx);
                            }
                          }
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          widget.alarms
                                  .map((e) => e.key)
                                  .every(widget.selectedIndexes.contains)
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (!widget.isSelectionMode)
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 자식 알람 목록 (접기/펼치기)
          AnimatedCrossFade(
            firstChild: Column(
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                ...widget.alarms.map((entry) {
                  final originalIndex = entry.key;
                  final alarm = entry.value;
                  return AlarmListItem(
                    alarm: alarm,
                    index: originalIndex,
                    isSelected: widget.selectedIndexes.contains(originalIndex),
                    isSelectionMode: widget.isSelectionMode,
                    isLocked: SubscriptionService.isIndexLocked(
                      originalIndex,
                      widget.alarmLimit,
                    ),
                    onSelect: widget.onSelect,
                    onTap: widget.onTap,
                  );
                }),
              ],
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState:
                _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

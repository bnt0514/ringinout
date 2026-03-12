// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';

// 컨트롤러
class AlarmListController {
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

  void toggleAll(int totalCount) {
    if (selectedIndexes.value.length == totalCount) {
      selectedIndexes.value = {};
    } else {
      selectedIndexes.value = Set<int>.from(
        List.generate(totalCount, (index) => index),
      );
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

  String _getSubtitle() {
    final repeat = alarm['repeat'];
    final trigger = alarm['trigger'] == 'entry' ? '진입' : '진출';
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

    // ✅ 요일 조건
    if (repeat is List && repeat.isNotEmpty) {
      parts.add('매주 ${repeat.join(', ')}');
    }

    // ✅ 시간 조건 (hour/minute 또는 startTimeMs)
    final h = alarm['hour'];
    final m = alarm['minute'];
    if (h != null) {
      final period = h >= 12 ? '오후' : '오전';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      parts.add('$period ${hour12}시${(m ?? 0).toString().padLeft(2, '0')}분 이후');
    } else {
      final startTimeMs = alarm['startTimeMs'];
      if (startTimeMs is int && startTimeMs > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
        final period = dt.hour >= 12 ? '오후' : '오전';
        final hour12 =
            dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
        parts.add(
          '$period ${hour12}시${dt.minute.toString().padLeft(2, '0')}분 이후',
        );
      }
    }

    if (parts.isEmpty) {
      return '알람 설정 후 최초 $trigger 시';
    }
    return '${parts.join(' ')} 최초 $trigger 시';
  }

  @override
  Widget build(BuildContext context) {
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
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: isLocked ? AppColors.shimmer : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.divider,
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
                    leading: Icon(
                      Icons.place,
                      color: isLocked ? AppColors.divider : AppColors.primary,
                    ),
                    title: Text(
                      alarm['name'] ?? '이름 없음',
                      style: TextStyle(
                        color: isLocked ? AppColors.divider : null,
                      ),
                    ),
                    subtitle:
                        isLocked
                            ? const Text(
                              '플랜 업그레이드 필요',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 12,
                              ),
                            )
                            : Text(_getSubtitle()),
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

          // 구독 한도 체크는 백그라운드에서
          Future.microtask(() async {
            final plan = await SubscriptionService.getCurrentPlan();
            final limit = SubscriptionService.activeAlarmLimit(plan);
            if (limit != null) {
              final activeCount =
                  HiveHelper.alarmBox.values
                      .where((item) => item is Map && item['enabled'] == true)
                      .length;
              if (activeCount > limit) {
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

  @override
  State<LocationAlarmList> createState() => _LocationAlarmListState();
}

class _LocationAlarmListState extends State<LocationAlarmList> {
  final _controller = AlarmListController();
  final _platform = const MethodChannel('ringinout_channel');
  Offset fabPosition = const Offset(160, 400);
  SubscriptionPlan _plan = SubscriptionPlan.free;

  @override
  void initState() {
    super.initState();
    SubscriptionService.getCurrentPlan().then((plan) {
      if (mounted) setState(() => _plan = plan);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupMethodChannel();
      _loadFabPosition();
    });
  }

  Future<void> _loadFabPosition() async {
    try {
      final position = await HiveHelper.getFabPosition();
      setState(() {
        fabPosition = position;
      });
    } catch (e) {
      print('FAB 위치 로드 실패: $e');
    }
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
            'alarmTitle': 'Ringinout 알람',
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
          child: Stack(
            children: [
              _buildAlarmList(),
              if (isSelectionMode) _buildSelectionHeader(),
              if (isSelectionMode) _buildDeleteButton(),
              if (!isSelectionMode) _buildDraggableFAB(fabPosition),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlarmList() {
    return ValueListenableBuilder(
      valueListenable: HiveHelper.alarmBox.listenable(),
      builder: (context, Box box, _) {
        final alarms = box.values.toList();
        if (alarms.isEmpty) {
          return const Center(child: Text('저장된 알람이 없습니다.'));
        }

        // ✅ 활성 알람 개수 확인
        final activeCount = alarms.where((a) => a['enabled'] == true).length;

        return ValueListenableBuilder(
          valueListenable: _controller.selectedIndexes,
          builder: (context, selectedIndexes, _) {
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    itemCount: alarms.length,
                    itemBuilder: (context, index) {
                      final alarmLimit = SubscriptionService.activeAlarmLimit(
                        _plan,
                      );
                      return AlarmListItem(
                        alarm: Map<String, dynamic>.from(alarms[index]),
                        index: index,
                        isSelected: selectedIndexes.contains(index),
                        isSelectionMode: _controller.isSelectionMode.value,
                        isLocked: SubscriptionService.isIndexLocked(
                          index,
                          alarmLimit,
                        ),
                        onSelect: _controller.toggleSelection,
                        onTap: _handleAlarmTap,
                      );
                    },
                  ),
                ),
                // ✅ 활성 알람이 있을 때만 안내 문구 표시
                if (activeCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppStyle.spacingBase,
                      vertical: AppStyle.spacingMd,
                    ),
                    color: AppColors.shimmer,
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '활성 알람이 있으면 앱 종료 시 자동으로 재시작됩니다.\n안정적인 알람 작동을 위해 배터리 최적화 제외를 권장합니다.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionHeader() {
    return Positioned(
      top: 0,
      left: -10,
      child: TextButton(
        onPressed: () => _controller.toggleAll(HiveHelper.alarmBox.length),
        child: Row(
          children: [
            ValueListenableBuilder(
              valueListenable: _controller.selectedIndexes,
              builder: (context, selectedIndexes, _) {
                return Checkbox(
                  value: selectedIndexes.length == HiveHelper.alarmBox.length,
                  onChanged:
                      (value) =>
                          _controller.toggleAll(HiveHelper.alarmBox.length),
                );
              },
            ),
            const Text('전체'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Positioned(
      bottom: 20,
      right: 20,
      child: FloatingActionButton(
        heroTag: 'delete_button',
        backgroundColor: AppColors.danger,
        foregroundColor: AppColors.textOnPrimary,
        onPressed: _controller.deleteSelected,
        child: const Icon(Icons.delete),
      ),
    );
  }

  Widget _buildDraggableFAB(Offset position) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            fabPosition += details.delta;
          });
        },
        onPanEnd: (_) async {
          await HiveHelper.saveFabPosition(fabPosition.dx, fabPosition.dy);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: AppStyle.fabShadow,
          ),
          child: FloatingActionButton(
            heroTag: 'location_alarm',
            shape: const CircleBorder(),
            elevation: 0,
            mini: true,
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.textOnPrimary,
            onPressed:
                () => Navigator.pushNamed(context, '/add_location_alarm'),
            tooltip: '알람 추가',
            child: const Icon(Icons.alarm_add),
          ),
        ),
      ),
    );
  }
}

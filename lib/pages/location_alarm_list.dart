// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/smart_location_monitor.dart';

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
    final keys = box.keys.toList();

    // ✅ 스누즈 박스와 트리거 카운트 박스 열기
    final snoozeBox = await Hive.openBox('snoozeSchedules');
    final triggerBox = await Hive.openBox('trigger_counts_v2');

    for (int i in selectedIndexes.value) {
      final alarm = box.getAt(i);
      if (alarm != null) {
        final alarmId = alarm['id'];

        // ✅ 알람 ID로 스누즈 스케줄과 트리거 카운트 삭제
        if (alarmId != null) {
          await snoozeBox.delete(alarmId);
          await triggerBox.delete(alarmId);
          print('🗑️ 알람 관련 데이터 삭제: $alarmId');
        }
      }

      // ✅ 알람 삭제
      await HiveHelper.deleteAlarmById(keys[i]);
    }

    selectedIndexes.value = {};
    isSelectionMode.value = false;
  }
}

// 알람 아이템 위젯
class AlarmListItem extends StatelessWidget {
  final Map<String, dynamic> alarm;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final Function(int) onSelect;
  final Function(int) onTap;

  const AlarmListItem({
    super.key,
    required this.alarm,
    required this.index,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onSelect,
    required this.onTap,
  });

  String _getSubtitle() {
    final repeat = alarm['repeat'];
    if (repeat is String) return repeat;
    if (repeat is List && repeat.isNotEmpty) return '매주 ${repeat.join(', ')}';
    return alarm['trigger'] == 'entry' ? '알람 설정 후 최초 진입 시' : '알람 설정 후 최초 진출 시';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => onSelect(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform:
            isSelectionMode
                ? Matrix4.translationValues(20, 0, 0)
                : Matrix4.identity(),
        margin:
            isSelectionMode ? const EdgeInsets.only(top: 30) : EdgeInsets.zero,
        child: Column(
          children: [
            Row(
              children: [
                if (isSelectionMode)
                  Checkbox(
                    value: isSelected,
                    onChanged: (bool? checked) => onSelect(index),
                  ),
                Expanded(
                  child: ListTile(
                    leading: const Icon(Icons.place),
                    title: Text(alarm['name'] ?? '이름 없음'),
                    subtitle: Text(_getSubtitle()),
                    onTap: () => onTap(index),
                  ),
                ),
                if (!isSelectionMode) _buildEnableSwitch(),
              ],
            ),
            Divider(color: Colors.grey.shade300, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildEnableSwitch() {
    return Container(
      width: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey)),
      ),
      child: GestureDetector(
        onTap: () async {
          final updatedAlarm = Map<String, dynamic>.from(alarm);
          final willEnable = !(alarm['enabled'] ?? false);
          updatedAlarm['enabled'] = willEnable;

          final alarmId = alarm['id'];

          if (willEnable) {
            // ✅ 알람 활성화 시: 트리거 카운트 초기화 + 상태 초기화
            updatedAlarm['triggerCount'] = 0;

            // ✅ trigger_counts_v2 박스도 초기화
            if (alarmId != null) {
              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
              print('🗑️ 트리거 카운트 초기화: $alarmId');
            }

            // ✅ LocationMonitorService에 상태 초기화 요청
            await _resetAlarmState(alarm['name'] ?? '');
          } else {
            // ✅ 알람 비활성화 시: 스누즈 스케줄과 트리거 카운트 삭제
            if (alarmId != null) {
              final snoozeBox = await Hive.openBox('snoozeSchedules');
              await snoozeBox.delete(alarmId);
              print('🗑️ 스누즈 스케줄 삭제 (비활성화): $alarmId');

              final triggerBox = await Hive.openBox('trigger_counts_v2');
              await triggerBox.delete(alarmId);
              print('🗑️ 트리거 카운트 삭제 (비활성화): $alarmId');
            }
          }

          await HiveHelper.updateLocationAlarm(index, updatedAlarm);

          // ✅ 알람 상태 변경 시 모니터링 재시작
          await _updateMonitoringService();

          print('🔄 알람 ${willEnable ? '활성화' : '비활성화'}: ${alarm['name']}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (alarm['enabled'] ?? false) ? Colors.blue : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: (alarm['enabled'] ?? false) ? 20 : 12,
              height: (alarm['enabled'] ?? false) ? 20 : 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ 알람 상태 초기화 메서드 추가
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
      // 스마트 모니터링 재시작
      await SmartLocationMonitor.startSmartMonitoring();
      print('🔄 스마트 모니터링 서비스 재시작 완료');
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

  @override
  void initState() {
    super.initState();
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

        return ValueListenableBuilder(
          valueListenable: _controller.selectedIndexes,
          builder: (context, selectedIndexes, _) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: alarms.length,
              itemBuilder:
                  (context, index) => AlarmListItem(
                    alarm: Map<String, dynamic>.from(alarms[index]),
                    index: index,
                    isSelected: selectedIndexes.contains(index),
                    isSelectionMode: _controller.isSelectionMode.value,
                    onSelect: _controller.toggleSelection,
                    onTap: _handleAlarmTap,
                  ),
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
        backgroundColor: Colors.grey[500],
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
        child: FloatingActionButton(
          heroTag: 'location_alarm', // MyPlaces와 다른 heroTag
          shape: const CircleBorder(),
          elevation: 4,
          mini: true, // MyPlaces와 동일한 크기
          backgroundColor: const Color.fromARGB(255, 0, 15, 150), // 동일한 색상
          foregroundColor: Colors.white, // 동일한 색상
          onPressed:
              () =>
                  Navigator.pushNamed(context, '/add_location_alarm'), // 다른 페이지
          tooltip: '알람 추가', // 다른 툴팁
          child: const Icon(Icons.alarm_add), // 다른 아이콘
        ),
      ),
    );
  }
}

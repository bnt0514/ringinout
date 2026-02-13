// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';

// Package imports:
import 'package:hive/hive.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart'; // ✅ Heartbeat 전송용
import 'package:ringinout/services/smart_location_service.dart'; // ✅ 네이티브 서비스 연동

class EditLocationAlarmPage extends StatefulWidget {
  final int? alarmIndex;
  final Map<String, dynamic> existingAlarmData;

  const EditLocationAlarmPage({
    super.key,
    this.alarmIndex,
    required this.existingAlarmData,
  });

  @override
  State<EditLocationAlarmPage> createState() => _EditLocationAlarmPageState();
}

class _EditLocationAlarmPageState extends State<EditLocationAlarmPage> {
  String alarmName = '';
  bool triggerOnEntry = false;
  bool triggerOnExit = false;
  Set<String> selectedWeekdays = {};
  DateTime? selectedDate;
  bool excludeHolidays = false;
  String holidayBehavior = 'on';
  String alarmSound = '기본 벨소리';
  bool alarmSoundEnabled = true;

  final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? selectedPlace;

  @override
  void initState() {
    super.initState();
    final alarmData = widget.existingAlarmData; // ✅ alarm 대신 alarmData 사용
    alarmName = alarmData['name'] ?? '';
    triggerOnEntry = alarmData['trigger'] == 'entry';
    triggerOnExit = alarmData['trigger'] == 'exit';

    final repeat = alarmData['repeat'];
    if (repeat is String) {
      selectedDate = DateTime.tryParse(repeat);
    } else if (repeat is List) {
      selectedWeekdays = Set<String>.from(repeat);
    }

    // 장소 목록 로드
    _loadPlaces(alarmData['place']); // ✅ alarm 대신 alarmData 사용
  }

  void _loadPlaces(String? currentPlace) {
    try {
      final box = HiveHelper.placeBox;
      places = box.values.map((e) => Map<String, dynamic>.from(e)).toList();

      print('📍 로드된 장소 목록: ${places.map((p) => p['name']).toList()}');
      print('🎯 현재 알람의 장소: $currentPlace');

      // 현재 장소 찾기
      if (currentPlace != null) {
        selectedPlace =
            places
                .where((e) => e['name'] == currentPlace)
                .firstOrNull; // ✅ alarm 대신 currentPlace 사용
      }

      // 장소를 못 찾았거나 없으면 첫 번째 장소 선택
      if (selectedPlace == null && places.isNotEmpty) {
        selectedPlace = places.first;
        print('⚠️ 현재 장소를 찾을 수 없어 첫 번째 장소로 설정: ${selectedPlace!['name']}');
      }

      print('✅ 선택된 장소: ${selectedPlace?['name']}');
    } catch (e) {
      print('❌ 장소 로드 실패: $e');
      places = [];
      selectedPlace = null;
    }
  }

  void _toggleExclusive(bool isEntry) {
    setState(() {
      if (isEntry) {
        triggerOnEntry = !triggerOnEntry;
        if (triggerOnEntry) triggerOnExit = false;
      } else {
        triggerOnExit = !triggerOnExit;
        if (triggerOnExit) triggerOnEntry = false;
      }
    });
  }

  String getSelectedDaySummary() {
    if (selectedDate != null) {
      final weekday = weekdays[selectedDate!.weekday % 7];
      return '${selectedDate!.month}월 ${selectedDate!.day}일 ($weekday)';
    } else if (selectedWeekdays.isNotEmpty) {
      final sorted =
          weekdays.where((d) => selectedWeekdays.contains(d)).toList();
      return '매주 ${sorted.join(', ')}';
    } else {
      if (triggerOnEntry) return '알람 설정 후 최초 진입 시';
      if (triggerOnExit) return '알람 설정 후 최초 진출 시';
    }
    return '선택 없음';
  }

  void _navigateToHolidaySettings() {
    if (!excludeHolidays) return;
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('대체/임시 공휴일 설정'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('대체 및 임시 공휴일에도 끄기'),
                  value: 'off',
                  groupValue: holidayBehavior,
                  onChanged: (value) {
                    setState(() => holidayBehavior = value!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: const Text('대체 및 임시 공휴일에는 켜기'),
                  value: 'on',
                  groupValue: holidayBehavior,
                  onChanged: (value) {
                    setState(() => holidayBehavior = value!);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _customToggleButton(bool value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: value ? AppColors.active : AppColors.inactive,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: value ? 20 : 12,
          height: value ? 20 : 12,
          decoration: BoxDecoration(
            color: AppColors.toggleThumb,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    bool value,
    Function() onToggle, {
    VoidCallback? onTapOutside,
  }) {
    return GestureDetector(
      onTap: onTapOutside,
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Container(
            width: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: GestureDetector(
              onTap: onToggle,
              child: _customToggleButton(value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required bool enabled,
    required Function(bool) onToggle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: ListTile(title: Text(title), subtitle: Text(subtitle)),
          ),
          Container(
            width: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: GestureDetector(
              onTap: () => onToggle(!enabled),
              child: _customToggleButton(enabled),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('위치알람 수정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: TextEditingController(text: alarmName),
              decoration: const InputDecoration(labelText: '알람 이름'),
              minLines: 1,
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              onChanged: (val) => alarmName = val,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedPlace,
              hint: const Text('장소를 선택하세요'), // ✅ hint 추가
              items:
                  places.map((place) {
                    return DropdownMenuItem(
                      value: place,
                      child: Text(place['name'] ?? '이름 없음'),
                    );
                  }).toList(),
              onChanged: (place) {
                setState(() {
                  selectedPlace = place;
                });
                print('📍 장소 변경: ${place?['name']}');
              },
              decoration: const InputDecoration(labelText: '장소 선택'),
              validator: (value) {
                if (value == null) {
                  return '장소를 선택해주세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              '진입 시 알람',
              triggerOnEntry,
              () => _toggleExclusive(true),
            ),
            const SizedBox(height: 10),
            _buildToggleRow(
              '진출 시 알람',
              triggerOnExit,
              () => _toggleExclusive(false),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  getSelectedDaySummary(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      locale: const Locale('ko', 'KR'),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                        selectedWeekdays.clear();
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children:
                  weekdays.map((day) {
                    final selected = selectedWeekdays.contains(day);
                    final color =
                        day == '일'
                            ? AppColors.sunday
                            : day == '토'
                            ? AppColors.saturday
                            : AppColors.textPrimary;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selected) {
                            selectedWeekdays.remove(day);
                          } else {
                            selectedWeekdays.add(day);
                            selectedDate = null;
                          }
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration:
                            selected
                                ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                )
                                : null,
                        child: Text(
                          day,
                          style: TextStyle(fontSize: 14, color: color),
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              '공휴일에는 끄기',
              excludeHolidays,
              () => setState(() => excludeHolidays = !excludeHolidays),
              onTapOutside: _navigateToHolidaySettings,
            ),
            if (excludeHolidays)
              GestureDetector(
                onTap: _navigateToHolidaySettings,
                child: const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    '대체 및 임시 공휴일에는 켜기',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildOptionTile(
              title: '알람음',
              subtitle: alarmSound,
              enabled: alarmSoundEnabled,
              onToggle: (val) => setState(() => alarmSoundEnabled = val),
              onTap: () {},
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final id = widget.existingAlarmData['id']; // ✅ 고유 ID 확보
                      await HiveHelper.deleteAlarmById(id); // ✅ ID 기반 통합 삭제

                      // ✅ Watchdog heartbeat 전송 (활성 알람 수 동기화)
                      await LocationMonitorService.sendWatchdogHeartbeat();
                      print('🗑️ 알람 삭제 후 Heartbeat 전송');

                      Navigator.pop(context); // ✅ 뒤로 가기
                    },
                    child: const Text('삭제'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (alarmName.trim().isEmpty ||
                                (!triggerOnEntry && !triggerOnExit))
                            ? null
                            : () async {
                              try {
                                final alarmId = widget.existingAlarmData['id'];
                                final sortedWeekdays =
                                    weekdays
                                        .where(
                                          (d) => selectedWeekdays.contains(d),
                                        )
                                        .toList();

                                final updatedAlarm = {
                                  'id': alarmId, // 기존 ID 유지
                                  'name': alarmName.trim(),
                                  'place': selectedPlace?['name'] ?? '',
                                  'trigger': triggerOnEntry ? 'entry' : 'exit',
                                  'repeat':
                                      selectedDate != null
                                          ? selectedDate!.toIso8601String()
                                          : (sortedWeekdays.isNotEmpty
                                              ? sortedWeekdays
                                              : null),
                                  'enabled':
                                      widget.existingAlarmData['enabled'] ??
                                      true, // 기존 enabled 상태 유지
                                  'triggerCount':
                                      widget
                                          .existingAlarmData['triggerCount'] ??
                                      0, // 기존 카운트 유지
                                  'createdAt':
                                      widget.existingAlarmData['createdAt'] ??
                                      DateTime.now().millisecondsSinceEpoch,
                                  'updatedAt':
                                      DateTime.now()
                                          .millisecondsSinceEpoch, // 수정 시간 추가
                                };

                                // ✅ ID 기반 업데이트 메서드 사용
                                await HiveHelper.updateLocationAlarmById(
                                  alarmId,
                                  updatedAlarm,
                                );
                                print('✅ 알람 업데이트 완료: ${updatedAlarm['name']}');

                                // ✅ 네이티브 SmartLocationService 즉시 업데이트
                                await SmartLocationService.updatePlaces();
                                print('🎯 SmartLocationService 장소 업데이트 완료');

                                // ✅ Watchdog heartbeat 전송 (활성 알람 수 동기화)
                                await LocationMonitorService.sendWatchdogHeartbeat();
                                print('💓 알람 수정 후 Heartbeat 전송');

                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                print('❌ 알람 저장 실패: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('알람 저장에 실패했습니다: $e'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              }
                            },
                    child: const Text('저장'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

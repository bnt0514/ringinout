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
  late TextEditingController _nameController;
  bool triggerOnEntry = false;
  bool triggerOnExit = false;
  Set<String> selectedWeekdays = {};
  DateTime? selectedDate;
  TimeOfDay? conditionTime; // ✅ 시간 조건
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
    final alarmData = widget.existingAlarmData;
    alarmName = alarmData['name'] ?? '';
    _nameController = TextEditingController(text: alarmName);
    triggerOnEntry = alarmData['trigger'] == 'entry';
    triggerOnExit = alarmData['trigger'] == 'exit';

    final repeat = alarmData['repeat'];
    if (repeat is String) {
      selectedDate = DateTime.tryParse(repeat);
    } else if (repeat is List) {
      selectedWeekdays = Set<String>.from(repeat);
    }

    // ✅ 시간 조건 로드
    final h = alarmData['hour'];
    final m = alarmData['minute'];
    if (h != null) {
      conditionTime = TimeOfDay(hour: h as int, minute: (m ?? 0) as int);
    } else {
      // startTimeMs에서 시간 추출 (날짜/요일 없는 시간만 알람)
      final startTimeMs = alarmData['startTimeMs'];
      if (startTimeMs is int && startTimeMs > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(startTimeMs);
        conditionTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    }

    // 장소 목록 로드
    _loadPlaces(alarmData['place']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    final trigger = triggerOnEntry ? '진입' : (triggerOnExit ? '진출' : '진입/진출');
    final parts = <String>[];

    if (selectedDate != null) {
      final weekday = weekdays[selectedDate!.weekday % 7];
      parts.add('${selectedDate!.month}월 ${selectedDate!.day}일($weekday)');
    } else if (selectedWeekdays.isNotEmpty) {
      final sorted =
          weekdays.where((d) => selectedWeekdays.contains(d)).toList();
      parts.add('매주 ${sorted.join(', ')}');
    }

    if (conditionTime != null) {
      final h = conditionTime!.hour;
      final m = conditionTime!.minute;
      final period = h >= 12 ? '오후' : '오전';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      parts.add('$period ${hour12}시${m.toString().padLeft(2, '0')}분 이후');
    }

    if (parts.isEmpty) {
      return '최초 $trigger 시 즉시 알람';
    }
    return '${parts.join(' ')} 최초 $trigger 시';
  }

  // ✅ TimePicker 표시
  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: conditionTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => conditionTime = picked);
    }
  }

  void _showCalendar() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
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
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '반경 경계 근처에서 머무르거나 왔다갔다 하면 알람이 여러 번 울릴 수 있습니다. '
                      '"다시 울림" 버튼으로 알람을 잠시 뒤로 미룰 수 있습니다.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ✅ 조건 설정 (선택사항)
            const Text(
              '조건 설정 (선택사항)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '조건 없이 저장하면 즉시 최초 진입/진출 시 알람이 울립니다.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // 📅 날짜 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDate != null
                      ? '📅 ${selectedDate!.year}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.day.toString().padLeft(2, '0')}'
                      : '날짜 지정 없음',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color:
                        selectedDate != null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _showCalendar,
                    ),
                    if (selectedDate != null)
                      GestureDetector(
                        onTap: () => setState(() => selectedDate = null),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 📆 요일 선택 (날짜와 배타적)
            if (selectedDate == null) ...[
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
                          width: 40,
                          height: 40,
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
              const SizedBox(height: 12),
            ],

            // ⏰ 시간 조건 설정
            GestureDetector(
              onTap: _showTimePicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                      conditionTime != null
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        conditionTime != null
                            ? AppColors.primary
                            : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color:
                          conditionTime != null
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      conditionTime != null
                          ? '⏰ ${conditionTime!.format(context)} 이후'
                          : '시간 조건 설정 (선택사항)',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            conditionTime != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (conditionTime != null)
                      GestureDetector(
                        onTap: () => setState(() => conditionTime = null),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ✅ 설정 요약
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      getSelectedDaySummary(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
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

                                // ✅ startTimeMs 계산
                                int startTimeMs = 0;
                                if (conditionTime != null &&
                                    selectedDate == null &&
                                    sortedWeekdays.isEmpty) {
                                  final now = DateTime.now();
                                  final scheduledTime = DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    conditionTime!.hour,
                                    conditionTime!.minute,
                                  );
                                  startTimeMs =
                                      scheduledTime.millisecondsSinceEpoch;
                                }

                                final updatedAlarm = {
                                  'id': alarmId,
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
                                      true,
                                  'triggerCount':
                                      widget
                                          .existingAlarmData['triggerCount'] ??
                                      0,
                                  'startTimeMs': startTimeMs,
                                  // ✅ 날짜/요일 + 시간 조건
                                  if (conditionTime != null &&
                                      (selectedDate != null ||
                                          sortedWeekdays.isNotEmpty)) ...{
                                    'hour': conditionTime!.hour,
                                    'minute': conditionTime!.minute,
                                  },
                                  'createdAt':
                                      widget.existingAlarmData['createdAt'] ??
                                      DateTime.now().millisecondsSinceEpoch,
                                  'updatedAt':
                                      DateTime.now().millisecondsSinceEpoch,
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

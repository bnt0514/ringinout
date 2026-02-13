import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/utils/trigger_keywords.dart';
import 'package:uuid/uuid.dart';

class AddAlarmPage extends StatefulWidget {
  final Map<String, dynamic> location;
  final Map<String, dynamic>? alarm;

  const AddAlarmPage({super.key, required this.location, this.alarm});

  @override
  State<AddAlarmPage> createState() => _AddAlarmPageState();
}

class _AddAlarmPageState extends State<AddAlarmPage> {
  final TextEditingController _nameController = TextEditingController();

  bool triggerOnEntry = false;
  bool triggerOnExit = false;
  Set<String> selectedWeekdays = {};
  DateTime? selectedDate;
  bool excludeHolidays = false;
  String holidayBehavior = 'on';
  String alarmSound = '기본 벨소리';
  String vibration = '짧은 진동';
  String snooze = '3분, 1회';
  bool alarmSoundEnabled = true;
  bool vibrationEnabled = true;
  bool snoozeEnabled = true;

  final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  void initState() {
    super.initState();

    if (widget.alarm != null) {
      final alarm = widget.alarm!;
      _nameController.text = alarm['name'] ?? '';
      triggerOnEntry = alarm['triggerOnEntry'] ?? false;
      triggerOnExit = alarm['triggerOnExit'] ?? false;
      selectedWeekdays = Set<String>.from(alarm['repeat'] ?? []);
      selectedDate =
          alarm['date'] != null ? DateTime.tryParse(alarm['date']) : null;
      excludeHolidays = alarm['excludeHolidays'] ?? false;
      holidayBehavior = alarm['holidayBehavior'] ?? 'on';
      alarmSound = alarm['alarmSound'] ?? '기본 벨소리';
      vibration = alarm['vibration'] ?? '짧은 진동';
      snooze = alarm['snooze'] ?? '3분, 1회';
      alarmSoundEnabled = alarm['alarmSoundEnabled'] ?? true;
      vibrationEnabled = alarm['vibrationEnabled'] ?? true;
      snoozeEnabled = alarm['snoozeEnabled'] ?? true;
    }
  }

  void _checkAlarmConditionFromName(String input) {
    // 다국어 키워드 매칭 (띄어쓰기 자동 정규화 포함)
    final triggerType = TriggerKeywords.detectTriggerType(input);

    if (triggerType == 'entry') {
      setState(() {
        triggerOnEntry = true;
        triggerOnExit = false;
      });
    } else if (triggerType == 'exit') {
      setState(() {
        triggerOnEntry = false;
        triggerOnExit = true;
      });
    } else if (triggerType == 'both') {
      // 둘 다 매칭되면 진입으로 설정
      setState(() {
        triggerOnEntry = true;
        triggerOnExit = false;
      });
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
      return '매주 ${selectedWeekdays.join(', ')}';
    } else if (triggerOnEntry) {
      return '진입 시';
    } else if (triggerOnExit) {
      return '진출 시';
    }
    return '선택 없음';
  }

  void _showCalendar() async {
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
          decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
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

  bool _validateFields() {
    if (_nameController.text.trim().isEmpty) return false;
    if (!triggerOnEntry && !triggerOnExit) return false;
    if (!alarmSoundEnabled && !vibrationEnabled) return false;
    if (!snoozeEnabled) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.alarm != null ? '위치알람 수정' : '새 알람 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '알람 이름'),
              onChanged: (val) {
                _checkAlarmConditionFromName(val);
              },
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.place),
              title: Text(widget.location['name'] ?? '장소 없음'),
              subtitle: const Text('이 알람은 해당 장소에 고정됩니다'),
              tileColor: AppColors.shimmer,
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
                  onPressed: _showCalendar,
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
            _buildOptionTile(
              title: '진동',
              subtitle: vibration,
              enabled: vibrationEnabled,
              onToggle: (val) => setState(() => vibrationEnabled = val),
              onTap: () {},
            ),
            _buildOptionTile(
              title: '다시 울림',
              subtitle: snooze,
              enabled: snoozeEnabled,
              onToggle: (_) {},
              onTap: () {},
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                if (!_validateFields()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('필수 항목을 모두 설정해주세요.')),
                  );
                  return;
                }

                final newAlarm = {
                  'name': _nameController.text.trim(),
                  'triggerOnEntry': triggerOnEntry,
                  'triggerOnExit': triggerOnExit,
                  'repeat': selectedWeekdays.toList(),
                  'date': selectedDate?.toIso8601String(),
                  'excludeHolidays': excludeHolidays,
                  'holidayBehavior': holidayBehavior,
                  'alarmSound': alarmSound,
                  'vibration': vibration,
                  'snooze': snooze,
                  'alarmSoundEnabled': alarmSoundEnabled,
                  'vibrationEnabled': vibrationEnabled,
                  'snoozeEnabled': snoozeEnabled,
                  'enabled': true,
                  'location': widget.location,
                };

                if (widget.alarm != null) {
                  final alarmId = widget.alarm?['id'];
                  if (alarmId is String) {
                    newAlarm['id'] = alarmId;
                    await HiveHelper.updateLocationAlarmById(alarmId, newAlarm);
                  } else {
                    final index = HiveHelper.getLocationAlarms().indexOf(
                      widget.alarm!,
                    );
                    await HiveHelper.updateLocationAlarm(index, newAlarm);
                  }
                } else {
                  final alarmId = await HiveHelper.saveLocationAlarm(newAlarm);

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(
                    'alarm_name_$alarmId',
                    (newAlarm['name'] ?? '') as String,
                  );
                }

                // ✅ 네이티브 SmartLocationService 즉시 업데이트
                await SmartLocationService.updatePlaces();
                print('🎯 SmartLocationService 장소 업데이트 완료');

                await SmartLocationMonitor.startSmartMonitoring();

                Navigator.pop(context);
              },
              child: const Center(child: Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}

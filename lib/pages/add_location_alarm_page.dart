import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ringinout/alarm_sound_setting_page.dart';
import 'package:ringinout/snooze_setting_page.dart';
import 'package:ringinout/vibration_setting_page.dart';
import 'package:ringinout/alarm_sound_player.dart';

class AddLocationAlarmPage extends StatefulWidget {
  final Map<String, dynamic>? existingAlarm;
  final int? alarmIndex;

  final dynamic editingAlarmKey;

  const AddLocationAlarmPage({
    super.key,
    this.existingAlarm,
    this.alarmIndex,
    this.editingAlarmKey, // ✅ 여기도 꼭 추가!
  });

  @override
  State<AddLocationAlarmPage> createState() => _AddLocationAlarmPageState();
}

class _AddLocationAlarmPageState extends State<AddLocationAlarmPage> {
  String alarmName = '';
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

  final List<String> entryKeywords = [
    '들어가',
    '들어오',
    '도착',
    '입장',
    '도달',
    '가까워지',
    '접근',
    '안에 들어',
    '안으로 들어',
    '안쪽으로',
    '안으로',
  ];

  final List<String> exitKeywords = [
    '나가',
    '나오',
    '출발',
    '나서',
    '떠나',
    '퇴장',
    '벗어나',
    '빠져나가',
    '밖으로',
    '빠져나오',
    '이탈',
  ];

  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? selectedPlace;

  @override
  void initState() {
    super.initState();
    final box = Hive.box('locations');
    places = box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _checkAlarmConditionFromName(String input) {
    final lower = input.toLowerCase();
    bool matchedEntry = entryKeywords.any((kw) => lower.contains(kw));
    bool matchedExit = exitKeywords.any((kw) => lower.contains(kw));

    if (matchedEntry && !matchedExit) {
      setState(() {
        triggerOnEntry = true;
        triggerOnExit = false;
      });
    } else if (matchedExit && !matchedEntry) {
      setState(() {
        triggerOnEntry = false;
        triggerOnExit = true;
      });
    }

    for (final place in places) {
      final name = place['name']?.toString() ?? '';
      if (lower.contains(name.toLowerCase())) {
        setState(() => selectedPlace = place);
        break;
      }
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
        color: value ? Colors.blue : Colors.grey[300],
        shape: BoxShape.circle,
      ),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: value ? 20 : 12,
          height: value ? 20 : 12,
          decoration: const BoxDecoration(
            color: Colors.white,
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
              border: Border(left: BorderSide(color: Colors.grey)),
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
              border: Border(left: BorderSide(color: Colors.grey)),
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
      appBar: AppBar(title: const Text('새 위치알람 추가')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '알람 이름'),
              onChanged: (val) {
                setState(() => alarmName = val);
                _checkAlarmConditionFromName(val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedPlace,
              items:
                  places.map((place) {
                    return DropdownMenuItem(
                      value: place,
                      child: Text(place['name'] ?? '이름 없음'),
                    );
                  }).toList(),
              onChanged: (place) => setState(() => selectedPlace = place),
              decoration: const InputDecoration(labelText: '장소 선택'),
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
                            ? Colors.red
                            : day == '토'
                            ? Colors.blue
                            : Colors.black;
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
                                  color: Colors.blue.withOpacity(0.3),
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
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildOptionTile(
              title: '알람음',
              subtitle: alarmSound ?? '기본 알람음',
              enabled: alarmSoundEnabled,
              onToggle: (val) => setState(() => alarmSoundEnabled = val),
              onTap: () async {
                if (!alarmSoundEnabled) return;

                setState(() => alarmSound = 'assets/sounds/1.mp3'); // 초기 설정

                // 🔊 미리듣기
                final player = AudioPlayer();
                try {
                  await player.setAsset('assets/sounds/1.mp3');
                  await player.play();
                } catch (e) {
                  print('🔕 알람음 재생 실패: $e');
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => AlarmSoundSettingPage(
                          currentPath: alarmSound,
                          onSelected: (path) async {
                            setState(() => alarmSound = path);

                            // 🔊 새 소리도 미리듣기
                            try {
                              await player.setAsset(path);
                              await player.play();
                            } catch (e) {
                              print('🔕 알람음 재생 실패: $e');
                            }

                            // Hive 저장
                            final box = Hive.box('locationAlarms');
                            if (widget.existingAlarm != null) {
                              final key = widget.existingAlarm!['key'];
                              final alarm = box.get(key);
                              if (alarm != null) {
                                alarm['sound'] = path;
                                box.put(key, alarm);
                              }
                            }
                          },
                        ),
                  ),
                );
              },
            ),

            _buildOptionTile(
              title: '진동',
              subtitle: vibration,
              enabled: vibrationEnabled,
              onToggle: (val) => setState(() => vibrationEnabled = val),
              onTap: () {
                if (!vibrationEnabled) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => VibrationSettingPage(
                          currentVibration: vibration,
                          onSelected: (pattern) {
                            setState(() => vibration = pattern);
                          },
                        ),
                  ),
                );
              },
            ),

            _buildOptionTile(
              title: '다시 울림',
              subtitle: snooze,
              enabled: snoozeEnabled,
              onToggle: (val) => setState(() => snoozeEnabled = val),
              onTap: () {
                if (!snoozeEnabled) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => SnoozeSettingPage(
                          currentSnooze: snooze,
                          onSelected: (selected) {
                            setState(() => snooze = selected);
                          },
                        ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed:
                  (alarmName.trim().isEmpty ||
                          (!triggerOnEntry && !triggerOnExit))
                      ? null
                      : () async {
                        final sortedWeekdays =
                            weekdays
                                .where((d) => selectedWeekdays.contains(d))
                                .toList();
                        final alarm = {
                          'name': alarmName,
                          'place': selectedPlace?['name'] ?? '',
                          'trigger': triggerOnEntry ? 'entry' : 'exit',
                          'repeat':
                              selectedDate != null
                                  ? selectedDate!.toIso8601String()
                                  : (sortedWeekdays.isNotEmpty
                                      ? sortedWeekdays
                                      : null),
                          'enabled': true,
                        };

                        await Hive.box('locationAlarms').add(alarm);
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

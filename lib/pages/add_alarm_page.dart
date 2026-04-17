import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/utils/trigger_keywords.dart';
import 'package:ringinout/widgets/false_trigger_info_tile.dart';

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
  String alarmSound = 'thoughtfulringtone';
  String vibration = 'short';
  String snooze = '3min_1x';
  bool alarmSoundEnabled = true;
  bool vibrationEnabled = true;
  bool snoozeEnabled = true;

  List<String> _getWeekdays(AppLocalizations l10n) {
    return [
      l10n.get('sun'),
      l10n.get('mon'),
      l10n.get('tue'),
      l10n.get('wed'),
      l10n.get('thu'),
      l10n.get('fri'),
      l10n.get('sat'),
    ];
  }

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
      alarmSound = alarm['alarmSound'] ?? 'thoughtfulringtone';
      vibration = alarm['vibration'] ?? 'short';
      snooze = alarm['snooze'] ?? '3min_1x';
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
    final l10n = AppLocalizations.of(context);
    final weekdays = _getWeekdays(l10n);
    if (selectedDate != null) {
      final weekday = weekdays[selectedDate!.weekday % 7];
      return l10n.getWithArgs('date_format', {
        'month': '${selectedDate!.month}',
        'day': '${selectedDate!.day}',
        'weekday': weekday,
      });
    } else if (selectedWeekdays.isNotEmpty) {
      return '${l10n.get('every_week_prefix')} ${selectedWeekdays.join(', ')}';
    } else if (triggerOnEntry) {
      return l10n.get('entry');
    } else if (triggerOnExit) {
      return l10n.get('exit');
    }
    return l10n.get('no_selection');
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(l10n.get('holidays_dialog_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text(l10n.get('holidays_sub_off')),
                  value: 'off',
                  groupValue: holidayBehavior,
                  onChanged: (value) {
                    setState(() => holidayBehavior = value!);
                    Navigator.pop(context);
                  },
                ),
                RadioListTile<String>(
                  title: Text(l10n.get('holidays_sub_on')),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.alarm != null
              ? l10n.get('edit_alarm_modify_title')
              : l10n.get('add_alarm_new_title'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.get('alarm_name')),
              onChanged: (val) {
                _checkAlarmConditionFromName(val);
              },
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.place),
              title: Text(
                widget.location['name'] ?? l10n.get('no_place_label'),
              ),
              subtitle: Text(l10n.get('location_fixed_text')),
              tileColor: AppColors.shimmer,
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              l10n.get('alarm_on_entry'),
              triggerOnEntry,
              () => _toggleExclusive(true),
            ),
            const SizedBox(height: 10),
            _buildToggleRow(
              l10n.get('alarm_on_exit'),
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
            Builder(
              builder: (context) {
                final weekdays = _getWeekdays(l10n);
                final sunLabel = l10n.get('sun');
                final satLabel = l10n.get('sat');
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:
                      weekdays.map((day) {
                        final selected = selectedWeekdays.contains(day);
                        final color =
                            day == sunLabel
                                ? AppColors.sunday
                                : day == satLabel
                                ? AppColors.saturday
                                : AppColors.textPrimary;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
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
                );
              },
            ),
            const SizedBox(height: 20),
            _buildToggleRow(
              l10n.get('holidays_off'),
              excludeHolidays,
              () => setState(() => excludeHolidays = !excludeHolidays),
              onTapOutside: _navigateToHolidaySettings,
            ),
            if (excludeHolidays)
              GestureDetector(
                onTap: _navigateToHolidaySettings,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.get('holidays_sub_on'),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildOptionTile(
              title: l10n.get('alarm_sound_label'),
              subtitle: l10n.get('alarm_sound_default'),
              enabled: true,
              onToggle: (val) {},
              onTap: () {},
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Text(
                l10n.get('alarm_sound_unchangeable'),
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            _buildOptionTile(
              title: l10n.get('vibration'),
              subtitle: vibration,
              enabled: vibrationEnabled,
              onToggle: (val) => setState(() => vibrationEnabled = val),
              onTap: () {},
            ),
            _buildOptionTile(
              title: l10n.get('snooze'),
              subtitle: snooze,
              enabled: snoozeEnabled,
              onToggle: (_) {},
              onTap: () {},
            ),
            const SizedBox(height: 16),
            const FalseTriggerInfoTile(),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () async {
                if (!_validateFields()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.get('required_fields_msg'))),
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
              child: Center(child: Text(l10n.get('save_btn'))),
            ),
          ],
        ),
      ),
    );
  }
}

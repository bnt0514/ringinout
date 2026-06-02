// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/app_localizations.dart';

// Package imports:
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart'; // ✅ Heartbeat 전송용
import 'package:ringinout/services/smart_location_monitor.dart'; // ✅ Flutter LMS + 네이티브 동시 갱신
import 'package:ringinout/widgets/false_trigger_info_tile.dart';
import 'package:ringinout/utils/alarm_activation_notice.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';

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
  String alarmSound = 'default';
  bool alarmSoundEnabled = true;
  bool vibrationEnabled = true;
  String detectionMode = AlarmDetectionMode.gps;

  List<String> _getWeekdays(AppLocalizations l10n) => [
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  ];

  /// 구 데이터("월"/"Mon" 등) → 언어 중립 코드로 변환 (마이그레이션 지원)
  static const Map<String, String> _weekdayCodeMap = {
    // Korean
    '일': 'sun',
    '월': 'mon',
    '화': 'tue',
    '수': 'wed',
    '목': 'thu',
    '금': 'fri',
    '토': 'sat',
    // Japanese
    '日': 'sun',
    '月': 'mon',
    '火': 'tue',
    '水': 'wed',
    '木': 'thu',
    '金': 'fri',
    '土': 'sat',
    // Chinese
    '一': 'mon', '二': 'tue', '三': 'wed', '四': 'thu', '五': 'fri', '六': 'sat',
    // English abbreviated
    'Sun': 'sun',
    'Mon': 'mon',
    'Tue': 'tue',
    'Wed': 'wed',
    'Thu': 'thu',
    'Fri': 'fri',
    'Sat': 'sat',
  };

  String _toWeekdayCode(String val) => _weekdayCodeMap[val] ?? val;

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
      selectedWeekdays = Set<String>.from(
        repeat.map((v) => _toWeekdayCode(v.toString())),
      );
    }
    excludeHolidays = alarmData['excludeHolidays'] ?? false;
    holidayBehavior = alarmData['holidayBehavior'] ?? 'on';
    alarmSoundEnabled = alarmData['soundEnabled'] ?? true;
    vibrationEnabled = alarmData['vibrationEnabled'] ?? true;

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
    detectionMode = AlarmDetectionMode.resolve(
      alarmData,
      place: selectedPlace,
      places: places,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _loadPlaces(String? currentPlace) {
    try {
      places = HiveHelper.getSavedLocations();

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

  bool get _selectedPlaceHasWifi =>
      AlarmDetectionMode.placeHasWifi(selectedPlace);

  void _selectDetectionMode(String mode) {
    if (mode == AlarmDetectionMode.wifi && !_selectedPlaceHasWifi) return;
    setState(() => detectionMode = mode);
  }

  Widget _buildDetectionModeSelector() {
    final l10n = AppLocalizations.of(context);
    final wifiEnabled = _selectedPlaceHasWifi;
    if (!wifiEnabled && detectionMode == AlarmDetectionMode.wifi) {
      detectionMode = AlarmDetectionMode.gps;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.get('detection_mode_title'),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDetectionModeTile(
                title: l10n.get('detection_mode_gps'),
                subtitle: l10n.get('detection_mode_gps_desc'),
                icon: Icons.gps_fixed,
                selected: detectionMode == AlarmDetectionMode.gps,
                enabled: true,
                onTap: () => _selectDetectionMode(AlarmDetectionMode.gps),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDetectionModeTile(
                title: l10n.get('detection_mode_wifi'),
                subtitle:
                    wifiEnabled
                        ? l10n.get('detection_mode_wifi_desc')
                        : l10n.get('detection_mode_wifi_disabled'),
                icon: Icons.wifi,
                selected: detectionMode == AlarmDetectionMode.wifi,
                enabled: wifiEnabled,
                onTap: () => _selectDetectionMode(AlarmDetectionMode.wifi),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetectionModeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color =
        !enabled
            ? AppColors.divider
            : selected
            ? AppColors.primary
            : AppColors.textSecondary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: color, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }

  String getSelectedDaySummary() {
    final l10n = AppLocalizations.of(context);
    final trigger =
        triggerOnEntry
            ? l10n.get('entry_trigger')
            : (triggerOnExit
                ? l10n.get('exit_trigger')
                : l10n.get('entry_exit_trigger'));
    final parts = <String>[];

    if (selectedDate != null) {
      final codes = _getWeekdays(l10n);
      final weekday = l10n.get(codes[selectedDate!.weekday % 7]);
      parts.add(
        l10n.getWithArgs('monthly_date', {
          'month': '${selectedDate!.month}',
          'day': '${selectedDate!.day}',
          'weekday': weekday,
        }),
      );
    } else if (selectedWeekdays.isNotEmpty) {
      final sorted =
          _getWeekdays(
            l10n,
          ).where((d) => selectedWeekdays.contains(d)).toList();
      final translated = sorted.map((c) => l10n.get(c)).join(', ');
      parts.add(l10n.getWithArgs('weekly_prefix', {'days': translated}));
    }

    if (conditionTime != null) {
      final h = conditionTime!.hour;
      final m = conditionTime!.minute;
      final period = l10n.get(h >= 12 ? 'pm_label' : 'am_label');
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      parts.add(
        '$period $hour12${l10n.get('hour_suffix')}${m.toString().padLeft(2, '0')}${l10n.get('min_suffix')}${l10n.get('after_suffix')}',
      );
    }

    if (parts.isEmpty) {
      return l10n.getWithArgs('first_trigger_immediate', {'trigger': trigger});
    }
    return l10n.getWithArgs('first_trigger_condition', {
      'conditions': parts.join(' '),
      'trigger': trigger,
    });
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
      builder: (_) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.get('holiday_settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(l10n.get('turn_off_on_holidays')),
                value: 'off',
                groupValue: holidayBehavior,
                onChanged: (value) {
                  setState(() => holidayBehavior = value!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: Text(l10n.get('turn_on_on_holidays')),
                value: 'on',
                groupValue: holidayBehavior,
                onChanged: (value) {
                  setState(() => holidayBehavior = value!);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
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
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('edit_alarm_title')),
      ),
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).get('alarm_name_label'),
              ),
              minLines: 1,
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              onChanged: (val) => alarmName = val,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: selectedPlace,
              hint: Text(AppLocalizations.of(context).get('select_place_hint')),
              items:
                  places.map((place) {
                    return DropdownMenuItem(
                      value: place,
                      child: Text(
                        place['name'] ??
                            AppLocalizations.of(context).get('no_name_label'),
                      ),
                    );
                  }).toList(),
              onChanged: (place) {
                setState(() {
                  selectedPlace = place;
                  if (!AlarmDetectionMode.placeHasWifi(place)) {
                    detectionMode = AlarmDetectionMode.gps;
                  }
                });
                print('📍 장소 변경: ${place?['name']}');
              },
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).get('select_place_label'),
              ),
              validator: (value) {
                if (value == null) {
                  return AppLocalizations.of(
                    context,
                  ).get('select_place_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildDetectionModeSelector(),
            const SizedBox(height: 20),
            _buildToggleRow(
              AppLocalizations.of(context).get('alarm_on_entry_label'),
              triggerOnEntry,
              () => _toggleExclusive(true),
            ),
            const SizedBox(height: 10),
            _buildToggleRow(
              AppLocalizations.of(context).get('alarm_on_exit_label'),
              triggerOnExit,
              () => _toggleExclusive(false),
            ),
            const SizedBox(height: 24),

            // ✅ 조건 설정 (선택사항)
            Text(
              AppLocalizations.of(context).get('condition_settings'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).get('condition_hint'),
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
                      : AppLocalizations.of(context).get('no_date_set'),
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
              Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context);
                  final weekdays = _getWeekdays(l10n);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        weekdays.map((day) {
                          final selected = selectedWeekdays.contains(day);
                          final color =
                              day == 'sun'
                                  ? AppColors.sunday
                                  : day == 'sat'
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
                                l10n.get(day),
                                style: TextStyle(fontSize: 14, color: color),
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
              const SizedBox(height: 12),
            ], // ⏰ 시간 조건 설정
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
                          ? AppLocalizations.of(context).getWithArgs(
                            'time_after',
                            {'time': conditionTime!.format(context)},
                          )
                          : AppLocalizations.of(
                            context,
                          ).get('time_condition_hint'),
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
              AppLocalizations.of(context).get('holidays_off'),
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
                    holidayBehavior == 'on'
                        ? AppLocalizations.of(context).get('holidays_sub_on')
                        : AppLocalizations.of(context).get('holidays_sub_off'),
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppStyle.radiusCard),
                border: Border.all(color: AppColors.border),
                boxShadow: AppStyle.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                                context,
                              ).get('alarm_sound_label') +
                              ' / ' +
                              AppLocalizations.of(
                                context,
                              ).get('vibration_label'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).get('sound_vibration_hint'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 12,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  _buildOptionTile(
                    title: AppLocalizations.of(
                      context,
                    ).get('alarm_sound_label'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).get('alarm_sound_default'),
                    enabled: alarmSoundEnabled,
                    onToggle: (val) {
                      if (!val && !vibrationEnabled) return;
                      setState(() => alarmSoundEnabled = val);
                    },
                    onTap: () {},
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 6),
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).get('alarm_sound_unchangeable'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border,
                  ),
                  _buildOptionTile(
                    title: AppLocalizations.of(context).get('vibration_label'),
                    subtitle: AppLocalizations.of(
                      context,
                    ).get('vibration_default_phone'),
                    enabled: vibrationEnabled,
                    onToggle: (val) {
                      if (!val && !alarmSoundEnabled) return;
                      setState(() => vibrationEnabled = val);
                    },
                    onTap: () {},
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const FalseTriggerInfoTile(),
            const SizedBox(height: 14),
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
                    child: Text(AppLocalizations.of(context).get('delete_btn')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (alarmName.trim().isEmpty ||
                                (!triggerOnEntry && !triggerOnExit) ||
                                (!alarmSoundEnabled && !vibrationEnabled))
                            ? null
                            : () async {
                              try {
                                final alarmId = widget.existingAlarmData['id'];
                                final sortedWeekdays =
                                    _getWeekdays(AppLocalizations.of(context))
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
                                  'placeId': selectedPlace?['id']?.toString(),
                                  'trigger': triggerOnEntry ? 'entry' : 'exit',
                                  'detectionMode': AlarmDetectionMode.forSave(
                                    detectionMode,
                                    selectedPlace,
                                  ),
                                  'repeat':
                                      selectedDate != null
                                          ? selectedDate!.toIso8601String()
                                          : (sortedWeekdays.isNotEmpty
                                              ? sortedWeekdays
                                              : null),
                                  'enabled': true, // ✅ 저장 시 항상 활성화
                                  'triggerCount':
                                      widget
                                          .existingAlarmData['triggerCount'] ??
                                      0,
                                  'excludeHolidays': excludeHolidays,
                                  'holidayBehavior': holidayBehavior,
                                  'startTimeMs': startTimeMs,
                                  // ✅ 날짜/요일 + 시간 조건
                                  if (conditionTime != null &&
                                      (selectedDate != null ||
                                          sortedWeekdays.isNotEmpty)) ...{
                                    'hour': conditionTime!.hour,
                                    'minute': conditionTime!.minute,
                                  },
                                  'soundEnabled': alarmSoundEnabled,
                                  'vibrationEnabled': vibrationEnabled,
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

                                if (!context.mounted) return;
                                await AlarmActivationNotice.showIfNeeded(
                                  context,
                                  updatedAlarm,
                                  selectedPlace,
                                );

                                // ✅ 저장 즉시 화면 이탈 (UX 개선)
                                if (!context.mounted) return;
                                Navigator.pop(context);

                                // ✅ 백그라운드에서 서비스 업데이트 (화면 이탈 후 처리)
                                // Flutter LMS + 네이티브 지오펜스 동시 갱신
                                SmartLocationMonitor.updatePlaces()
                                    .then((_) {
                                      print(
                                        '🎯 알람 수정 후 장소 업데이트 완료 (Flutter LMS + 네이티브)',
                                      );
                                    })
                                    .catchError((e) {
                                      print('⚠️ 장소 업데이트 실패: $e');
                                    });
                                LocationMonitorService.sendWatchdogHeartbeat()
                                    .then((_) {
                                      print('💓 알람 수정 후 Heartbeat 전송');
                                    })
                                    .catchError((e) {
                                      print('⚠️ Heartbeat 전송 실패: $e');
                                    });
                              } catch (e) {
                                print('❌ 알람 저장 실패: $e');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(
                                          context,
                                        ).getWithArgs('alarm_save_failed', {
                                          'error': '$e',
                                        }),
                                      ),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              }
                            },
                    child: Text(AppLocalizations.of(context).get('save_btn')),
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

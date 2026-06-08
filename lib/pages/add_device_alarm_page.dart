// lib/pages/add_device_alarm_page.dart
//
// 새 기기알람 추가 페이지 — 위치 알람 추가 페이지와 동일한 UI 형식
// - 기기 선택 (페어링된 BT 드롭다운 — 사용자 지정 이름 표시)
// - 알람명 + 음성인식
// - 연결 시 / 해제 시 토글
// - 날짜 / 요일 / 시간 조건
// - 공휴일 설정
// - 알람 사운드 + 오발동 안내

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/app_theme.dart';
import '../services/app_localizations.dart';
import '../services/hive_helper.dart';
import '../services/locale_provider.dart';
import '../utils/device_trigger_keywords.dart';
import '../utils/phonetic_matcher.dart';
import '../utils/voice_datetime_parser.dart';
import '../widgets/false_trigger_info_tile.dart';

class AddDeviceAlarmPage extends StatefulWidget {
  final Map<String, dynamic>? existingAlarm;
  final Map<String, dynamic>? preSelectedDevice;
  final bool startWithVoice; // ✅ 페이지 열릴 때 바로 음성인식 시작

  const AddDeviceAlarmPage({
    super.key,
    this.existingAlarm,
    this.preSelectedDevice,
    this.startWithVoice = false,
  });

  @override
  State<AddDeviceAlarmPage> createState() => _AddDeviceAlarmPageState();
}

class _AddDeviceAlarmPageState extends State<AddDeviceAlarmPage> {
  // ── 알람 데이터 ────────────────────────────────────────────
  late TextEditingController _alarmNameController;
  String alarmName = '';
  bool triggerOnConnect = false;
  bool triggerOnDisconnect = false;
  Set<String> selectedWeekdays = {};
  DateTime? selectedDate;
  bool excludeHolidays = false;
  String holidayBehavior = 'on';
  TimeOfDay? conditionTime;

  // ── 기기 ──────────────────────────────────────────────────
  Map<String, dynamic>? _selectedDevice;
  List<Map<String, dynamic>> _bondedDevices = [];
  bool _isLoadingDevices = true;

  // ── 음성인식 ────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceTarget = '';

  bool get _isEditing => widget.existingAlarm != null;
  bool _isSaving = false; // ✅ 중복 저장 방지 가드

  final List<String> _weekdayCodes = [
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadBondedDevices();

    _alarmNameController = TextEditingController();

    if (_isEditing) {
      final alarm = widget.existingAlarm!;
      alarmName = alarm['name'] ?? '';
      _alarmNameController.text = alarmName;
      excludeHolidays = alarm['excludeHolidays'] == true;
      holidayBehavior = alarm['holidayBehavior'] ?? 'on';

      final trigger = alarm['triggerType'] ?? 'connect';
      triggerOnConnect = trigger == 'connect';
      triggerOnDisconnect = trigger == 'disconnect';

      final mac = alarm['macAddress'] ?? '';
      final name = alarm['deviceName'] ?? '';
      if (mac.isNotEmpty) {
        // displayName은 _loadBondedDevices에서 myDevicesBox와 매칭 후 업데이트
        _selectedDevice = {
          'macAddress': mac,
          'name': name,
          'displayName': name,
        };
      }

      final repeat = alarm['repeat'];
      if (repeat is List) {
        selectedWeekdays = Set<String>.from(repeat.map((e) => e.toString()));
      } else if (repeat is String && repeat.isNotEmpty) {
        try {
          selectedDate = DateTime.parse(repeat);
        } catch (_) {}
      }

      if (alarm['hour'] != null && alarm['minute'] != null) {
        conditionTime = TimeOfDay(hour: alarm['hour'], minute: alarm['minute']);
      } else if (alarm['startTimeMs'] != null &&
          alarm['startTimeMs'] != 0 &&
          selectedDate == null &&
          selectedWeekdays.isEmpty) {
        final dt = DateTime.fromMillisecondsSinceEpoch(alarm['startTimeMs']);
        conditionTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    } else if (widget.preSelectedDevice != null) {
      // 내 기기 페이지에서 '새 알람 추가'로 진입 시 기기만 프리셋 (알람명은 사용자 입력)
      final dev = widget.preSelectedDevice!;
      final displayName =
          dev['customName'] ?? dev['originalName'] ?? dev['name'] ?? '';
      _selectedDevice = {
        'macAddress': dev['macAddress'] ?? '',
        'name': dev['originalName'] ?? dev['name'] ?? '',
        'displayName': displayName,
      };
    }
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isListening = false);
      },
    );
    if (mounted) setState(() {});

    // ✅ startWithVoice가 true면 바로 음성인식 시작
    if (widget.startWithVoice && _speechAvailable) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _startListening('name');
      });
    }
  }

  String _getSpeechLocaleId() {
    final localeProvider = context.read<LocaleProvider>();
    switch (localeProvider.currentLanguage) {
      case AppLanguage.korean:
        return 'ko_KR';
      case AppLanguage.japanese:
        return 'ja_JP';
      case AppLanguage.chinese:
        return 'zh_CN';
      case AppLanguage.english:
        return 'en_US';
      case AppLanguage.german:
        return 'de_DE';
      case AppLanguage.french:
        return 'fr_FR';
      case AppLanguage.spanish:
        return 'es_ES';
      case AppLanguage.system:
        final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
        return '${sysLocale.languageCode}_${sysLocale.countryCode ?? sysLocale.languageCode.toUpperCase()}';
    }
  }

  void _startListening(String target) async {
    if (!_speechAvailable) return;
    setState(() {
      _isListening = true;
      _voiceTarget = target;
    });

    final localeId = _getSpeechLocaleId();

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
      onResult: (result) {
        final fullText = result.recognizedWords;
        // 요일·날짜·시간 키워드를 제거한 정제 텍스트
        final strippedText = VoiceDateTimeParser.stripDateTimeKeywords(
          fullText,
          localeId: localeId,
        );
        setState(() {
          _alarmNameController.text = strippedText;
          _alarmNameController.selection = TextSelection.fromPosition(
            TextPosition(offset: _alarmNameController.text.length),
          );
          alarmName = strippedText;
        });
        // 원문 전체로 기기·트리거·날짜·시간 파싱
        _parseVoiceInput(fullText, localeId);
      },
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    // 음성인식 종료 후 기기 자동 매칭
    _autoMatchDevice();
  }

  /// 음성인식 텍스트에서 기기·연결/해제·요일·날짜·시간을 자동 파싱
  void _parseVoiceInput(String input, String localeId) {
    // 1. 연결/해제 트리거 감지
    final triggerType = DeviceTriggerKeywords.detectTriggerType(
      input,
      locale: localeId.split('_').first,
    );
    if (triggerType == 'connect') {
      setState(() {
        triggerOnConnect = true;
        triggerOnDisconnect = false;
      });
    } else if (triggerType == 'disconnect') {
      setState(() {
        triggerOnConnect = false;
        triggerOnDisconnect = true;
      });
    }

    // 2. 기기 이름 자동 매칭
    _autoMatchDevice();

    // 3. 요일 자동 감지
    final detectedWeekdays = VoiceDateTimeParser.extractWeekdays(
      input,
      localeId: localeId,
    );
    if (detectedWeekdays.isNotEmpty) {
      setState(() {
        selectedWeekdays = detectedWeekdays;
        selectedDate = null;
      });
    }

    // 4. 날짜 자동 감지 (요일이 없을 때만)
    if (detectedWeekdays.isEmpty) {
      final detectedDate = VoiceDateTimeParser.extractDate(
        input,
        localeId: localeId,
      );
      if (detectedDate != null) {
        setState(() {
          selectedDate = detectedDate;
          selectedWeekdays = {};
        });
      }
    }

    // 5. 시간 조건 자동 감지
    final detectedTime = VoiceDateTimeParser.extractTime(
      input,
      localeId: localeId,
    );
    if (detectedTime != null) {
      setState(() => conditionTime = detectedTime);
    }
  }

  /// 음성인식 텍스트에서 기기 이름 자동 매칭 (음성학적 유사도 포함)
  void _autoMatchDevice() {
    if (_bondedDevices.isEmpty) return;
    if (alarmName.trim().isEmpty) return;

    // displayName 후보 리스트 구성
    final displayNames =
        _bondedDevices.map((d) => d['displayName']?.toString() ?? '').toList();

    // 1차: displayName으로 음성학적 매칭
    final idx = PhoneticMatcher.findBestMatch(
      input: alarmName,
      candidates: displayNames,
    );
    if (idx >= 0) {
      setState(() => _selectedDevice = _bondedDevices[idx]);
      return;
    }

    // 2차: originalName으로 음성학적 매칭
    final originalNames =
        _bondedDevices.map((d) => d['name']?.toString() ?? '').toList();
    final idx2 = PhoneticMatcher.findBestMatch(
      input: alarmName,
      candidates: originalNames,
    );
    if (idx2 >= 0) {
      setState(() => _selectedDevice = _bondedDevices[idx2]);
    }
  }

  Future<void> _loadBondedDevices() async {
    try {
      const channel = MethodChannel('ringinout_channel');
      final result = await channel.invokeMethod('getBondedBluetoothDevices');
      final devices =
          (result as List<dynamic>? ?? [])
              .map((d) => Map<String, dynamic>.from(d as Map))
              .toList();

      // myDevicesBox에서 사용자 지정 이름 가져와 displayName에 반영
      final myDevices = HiveHelper.getMyDevices();
      for (final device in devices) {
        final mac = device['macAddress'] ?? '';
        final saved = myDevices.firstWhere(
          (d) => d['macAddress'] == mac,
          orElse: () => <String, dynamic>{},
        );
        if (saved.isNotEmpty &&
            (saved['customName'] ?? '').toString().isNotEmpty) {
          device['displayName'] = saved['customName'];
        } else {
          device['displayName'] = device['name'] ?? mac;
        }
      }

      setState(() {
        _bondedDevices = devices;
        _isLoadingDevices = false;
        if (_isEditing && _selectedDevice != null) {
          final mac = _selectedDevice!['macAddress'];
          final matched = devices.where((d) => d['macAddress'] == mac).toList();
          if (matched.isNotEmpty) _selectedDevice = matched.first;
        } else if (!_isEditing && _selectedDevice != null) {
          // preSelectedDevice로 진입한 경우에도 displayName 반영
          final mac = _selectedDevice!['macAddress'];
          final matched = devices.where((d) => d['macAddress'] == mac).toList();
          if (matched.isNotEmpty) _selectedDevice = matched.first;
        }
      });
    } catch (e) {
      debugPrint('❌ getBondedBluetoothDevices 실패: $e');
      setState(() => _isLoadingDevices = false);
    }
  }

  void _toggleExclusive(bool isConnect) {
    setState(() {
      if (isConnect) {
        triggerOnConnect = !triggerOnConnect;
        if (triggerOnConnect) triggerOnDisconnect = false;
      } else {
        triggerOnDisconnect = !triggerOnDisconnect;
        if (triggerOnDisconnect) triggerOnConnect = false;
      }
    });
  }

  String _getSelectedDaySummary() {
    final l10n = AppLocalizations.of(context);
    final trigger =
        triggerOnConnect
            ? l10n.get('alarm_on_connect_label')
            : l10n.get('alarm_on_disconnect_label');
    final parts = <String>[];

    if (selectedDate != null) {
      final weekday = l10n.get(_weekdayCodes[selectedDate!.weekday % 7]);
      parts.add(
        l10n.getWithArgs('monthly_date', {
          'month': '${selectedDate!.month}',
          'day': '${selectedDate!.day}',
          'weekday': weekday,
        }),
      );
    } else if (selectedWeekdays.isNotEmpty) {
      final sorted =
          _weekdayCodes.where((d) => selectedWeekdays.contains(d)).toList();
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

  void _showCalendar() async {
    final picked = await showDatePicker(
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

  void _showTimePicker() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: conditionTime ?? TimeOfDay.now(),
      builder:
          (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
    );
    if (picked != null) setState(() => conditionTime = picked);
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
                onChanged: (v) {
                  setState(() => holidayBehavior = v!);
                  Navigator.pop(context);
                },
              ),
              RadioListTile<String>(
                title: Text(l10n.get('turn_on_on_holidays')),
                value: 'on',
                groupValue: holidayBehavior,
                onChanged: (v) {
                  setState(() => holidayBehavior = v!);
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
    VoidCallback onToggle, {
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

  Future<void> _save() async {
    if (_isSaving) return; // ✅ 중복 저장 방지
    if (_selectedDevice == null) return;
    if (!triggerOnConnect && !triggerOnDisconnect) return;

    setState(() => _isSaving = true);

    final l10n = AppLocalizations.of(context);
    final sortedWeekdays =
        _weekdayCodes.where((d) => selectedWeekdays.contains(d)).toList();

    int startTimeMs = 0;
    if (conditionTime != null &&
        selectedDate == null &&
        sortedWeekdays.isEmpty) {
      final now = DateTime.now();
      startTimeMs =
          DateTime(
            now.year,
            now.month,
            now.day,
            conditionTime!.hour,
            conditionTime!.minute,
          ).millisecondsSinceEpoch;
    }

    final id =
        _isEditing
            ? widget.existingAlarm!['id']
            : DateTime.now().millisecondsSinceEpoch.toString();

    final alarmData = {
      'id': id,
      'name':
          _alarmNameController.text.trim().isNotEmpty
              ? _alarmNameController.text.trim()
              : (_selectedDevice!['displayName'] ??
                  _selectedDevice!['name'] ??
                  ''),
      'deviceName': _selectedDevice!['name'] ?? '',
      'macAddress': _selectedDevice!['macAddress'] ?? '',
      'triggerType': triggerOnConnect ? 'connect' : 'disconnect',
      'enabled': true,
      'excludeHolidays': excludeHolidays,
      'holidayBehavior': holidayBehavior,
      'repeat':
          selectedDate != null
              ? selectedDate!.toIso8601String()
              : (sortedWeekdays.isNotEmpty ? sortedWeekdays : null),
      'startTimeMs': startTimeMs,
      if (conditionTime != null &&
          (selectedDate != null || sortedWeekdays.isNotEmpty)) ...{
        'hour': conditionTime!.hour,
        'minute': conditionTime!.minute,
      },
      'createdAt':
          _isEditing
              ? widget.existingAlarm!['createdAt']
              : DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await HiveHelper.saveDeviceAlarm(alarmData);
    } catch (e) {
      print('❌ 기기 알람 저장 실패: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('device_alarm_save_success'))),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    _alarmNameController.dispose();
    _speech.stop();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave =
        _selectedDevice != null &&
        (triggerOnConnect || triggerOnDisconnect) &&
        alarmName.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.get(
            _isEditing ? 'device_alarm_edit_title' : 'add_new_device_alarm',
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 음성인식 중 배너 ──────────────────────────
                  if (_isListening)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.mic, color: AppColors.primary, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            l10n.get('listening_prompt'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _stopListening,
                            child: Text(l10n.get('done_btn')),
                          ),
                        ],
                      ),
                    ),

                  // ── 알람 이름 ─────────────────────────────────
                  TextField(
                    controller: _alarmNameController,
                    decoration: InputDecoration(
                      labelText: l10n.get('alarm_name_label'),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isListening && _voiceTarget == 'name'
                              ? Icons.stop
                              : Icons.mic,
                          color:
                              _isListening && _voiceTarget == 'name'
                                  ? AppColors.danger
                                  : AppColors.primary,
                        ),
                        onPressed: () {
                          if (_isListening) {
                            _stopListening();
                          } else {
                            _startListening('name');
                          }
                        },
                      ),
                    ),
                    minLines: 1,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (val) => setState(() => alarmName = val),
                  ),
                  const SizedBox(height: 16),

                  // ── 기기 선택 드롭다운 ─────────────────────────
                  _isLoadingDevices
                      ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                      : _bondedDevices.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          l10n.get('bt_no_bonded_devices'),
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                      : DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue:
                            _bondedDevices.any(
                                  (d) =>
                                      d['macAddress'] ==
                                      _selectedDevice?['macAddress'],
                                )
                                ? _bondedDevices.firstWhere(
                                  (d) =>
                                      d['macAddress'] ==
                                      _selectedDevice?['macAddress'],
                                )
                                : null,
                        items:
                            _bondedDevices.map((device) {
                              return DropdownMenuItem(
                                value: device,
                                child: Text(
                                  device['displayName'] ??
                                      device['name'] ??
                                      device['macAddress'] ??
                                      '',
                                ),
                              );
                            }).toList(),
                        onChanged: (device) {
                          setState(() {
                            _selectedDevice = device;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: l10n.get('select_device_label'),
                        ),
                      ),
                  const SizedBox(height: 20),

                  // ── 연결 시 / 해제 시 토글 ────────────────────
                  _buildToggleRow(
                    l10n.get('alarm_on_connect_label'),
                    triggerOnConnect,
                    () => _toggleExclusive(true),
                  ),
                  const SizedBox(height: 10),
                  _buildToggleRow(
                    l10n.get('alarm_on_disconnect_label'),
                    triggerOnDisconnect,
                    () => _toggleExclusive(false),
                  ),
                  const SizedBox(height: 24),

                  // ── 조건 설정 ─────────────────────────────────
                  Text(
                    l10n.get('condition_settings'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.get('device_condition_hint'),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 📅 날짜 선택
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        selectedDate != null
                            ? '📅 ${selectedDate!.year}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.day.toString().padLeft(2, '0')}'
                            : l10n.get('no_date_set'),
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

                  // 📆 요일 선택
                  if (selectedDate == null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children:
                          _weekdayCodes.map((day) {
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
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ⏰ 시간 조건
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
                                ? l10n.getWithArgs('time_after', {
                                  'time': conditionTime!.format(context),
                                })
                                : l10n.get('time_condition_hint'),
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

                  // ── 설정 요약 ─────────────────────────────────
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
                            _getSelectedDaySummary(),
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

                  // ── 공휴일 설정 ────────────────────────────────
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
                          holidayBehavior == 'on'
                              ? l10n.get('holidays_sub_on')
                              : l10n.get('holidays_sub_off'),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // ── 알람 사운드 ────────────────────────────────
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── 오발동 안내 ────────────────────────────────
                  const FalseTriggerInfoTile(mode: 'device'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // ── 하단 저장 바 ──────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border(
                top: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: (canSave && !_isSaving) ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.divider,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isSaving
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : Text(
                            l10n.get('save'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/app_localizations.dart';

// Package imports:
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Project imports:
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/widgets/false_trigger_info_tile.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/locale_provider.dart';
import 'package:ringinout/utils/phonetic_matcher.dart';
import 'package:ringinout/utils/alarm_activation_notice.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';
import 'package:ringinout/utils/wifi_alarm_settings.dart';
import 'package:ringinout/utils/trigger_keywords.dart';
import 'package:ringinout/utils/voice_datetime_parser.dart';

class AddLocationAlarmPage extends StatefulWidget {
  final Map<String, dynamic>? existingAlarmData; // ✅ 이름 통일
  final String? editingAlarmId; // ✅ id 기반 수정용 (nullable)

  // ✅ 음성인식에서 전달받는 매개변수
  final Map<String, dynamic>? preSelectedPlace;
  final String? prefilledMessage;
  final String? preSelectedTrigger; // 'entry' or 'exit'
  final bool startWithVoice; // ✅ 페이지 열릴 때 바로 음성인식 시작

  const AddLocationAlarmPage({
    super.key,
    this.existingAlarmData,
    this.editingAlarmId,
    this.preSelectedPlace,
    this.prefilledMessage,
    this.preSelectedTrigger,
    this.startWithVoice = false,
  });

  @override
  State<AddLocationAlarmPage> createState() => _AddLocationAlarmPageState();
}

class _AddLocationAlarmPageState extends State<AddLocationAlarmPage> {
  String alarmName = '';
  late TextEditingController _alarmNameController; // ✅ 컨트롤러 추가
  bool triggerOnEntry = false;
  bool triggerOnExit = false;
  Set<String> selectedWeekdays = {};
  DateTime? selectedDate;
  bool excludeHolidays = false;
  String holidayBehavior = 'on';
  String alarmSound = 'thoughtfulringtone';
  bool alarmSoundEnabled = true;
  bool vibrationEnabled = true;
  String detectionMode = AlarmDetectionMode.gps;
  int wifiWaitTimeoutMinutes = WifiAlarmSettings.defaultWaitMinutes;

  // ✅ 조건 설정 (선택사항) - 모든 알람은 "최초 1회"
  TimeOfDay? conditionTime; // 시간 조건 (선택적)

  // ✅ 음성인식 관련
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  List<String> _getWeekdays(AppLocalizations l10n) => [
    'sun',
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
  ];

  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? selectedPlace;
  int? _placeLimit; // null = unlimited
  bool _lockSelectedPlaceFromAutoMatch = false;
  bool _isSaving = false; // ✅ 중복 저장 방지 가드

  @override
  void initState() {
    super.initState();

    // ✅ 음성인식 초기화
    _speech = stt.SpeechToText();
    _initSpeech();

    // ✅ 컨트롤러 초기화 (음성인식 텍스트로 초기값 설정)
    _alarmNameController = TextEditingController(
      text: widget.prefilledMessage ?? '',
    );
    alarmName = widget.prefilledMessage ?? '';

    places = HiveHelper.getSavedLocations();

    // 잠긴 장소 파악용 플랜 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlaceLimit();
    });

    // ✅ 음성인식에서 전달받은 데이터 초기화
    if (widget.preSelectedPlace != null) {
      final matchedPlace = _findMatchingPlace(widget.preSelectedPlace);
      if (matchedPlace != null) {
        selectedPlace = matchedPlace;
        _lockSelectedPlaceFromAutoMatch = true;
      }
    }

    if (widget.preSelectedTrigger != null) {
      if (widget.preSelectedTrigger == 'entry') {
        triggerOnEntry = true;
        triggerOnExit = false;
      } else if (widget.preSelectedTrigger == 'exit') {
        triggerOnEntry = false;
        triggerOnExit = true;
      }
    }
  }

  Future<void> _loadPlaceLimit() async {
    final plan = await SubscriptionService.getCurrentPlan();
    if (!mounted) return;
    setState(() {
      _placeLimit = SubscriptionService.placeLimit(plan);
    });
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
          // 음성인식 종료 후 장소 자동 매칭
          _autoMatchPlace();
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
      },
    );

    // ✅ startWithVoice가 true면 바로 음성인식 시작
    if (widget.startWithVoice && _speechAvailable) {
      // 약간의 딜레이 후 시작 (UI가 완전히 로드된 후)
      Future.delayed(const Duration(milliseconds: 300), () {
        _startListening();
      });
    }
  }

  /// 앱 언어 설정을 기반으로 STT localeId를 결정
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
        // 기기 시스템 언어 그대로 사용 (speech_to_text 기본값)
        final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
        return '${sysLocale.languageCode}_${sysLocale.countryCode ?? sysLocale.languageCode.toUpperCase()}';
    }
  }

  void _startListening() async {
    if (!_speechAvailable) return;

    setState(() => _isListening = true);

    final localeId = _getSpeechLocaleId();

    await _speech.listen(
      onResult: (result) {
        final fullText = result.recognizedWords;
        // 요일·날짜·시간 표현은 파싱해서 UI에 자동 설정되므로
        // 텍스트 필드에는 해당 키워드를 제거한 정제 텍스트만 표시
        final strippedText = VoiceDateTimeParser.stripDateTimeKeywords(
          fullText,
          localeId: localeId,
        );
        setState(() {
          _alarmNameController.text = strippedText;
          alarmName = strippedText;
        });
        // 파싱은 원문 전체로 수행 (요일/날짜/시간 감지 위해)
        _checkAlarmConditionFromName(fullText);
      },
      localeId: localeId,
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    _autoMatchPlace();
  }

  // ✅ 음성인식 완료 후 장소 자동 매칭 (음성학적 유사도 포함)
  void _autoMatchPlace() {
    if (_lockSelectedPlaceFromAutoMatch && selectedPlace != null) {
      return;
    }
    if (alarmName.trim().isEmpty) return;

    final placeNames = places.map((p) => p['name']?.toString() ?? '').toList();

    final idx = PhoneticMatcher.findBestMatch(
      input: alarmName,
      candidates: placeNames,
    );
    if (idx >= 0) {
      setState(() => selectedPlace = places[idx]);
    }
  }

  @override
  void dispose() {
    _alarmNameController.dispose();
    _speech.stop();
    super.dispose();
  }

  void _checkAlarmConditionFromName(String input) {
    // 1. 다국어 키워드 매칭: 진입/진출 트리거 감지
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
      // 둘 다 매칭되면 마지막 입력 우선 - 진입으로 설정
      setState(() {
        triggerOnEntry = true;
        triggerOnExit = false;
      });
    }

    // 2. 장소 매칭 개선: 공백 제거 후 비교, 긴 이름 우선
    _matchPlaceFromInput(input);

    // 3. 요일 자동 감지
    final localeId = _getSpeechLocaleId();
    final detectedWeekdays = VoiceDateTimeParser.extractWeekdays(
      input,
      localeId: localeId,
    );
    if (detectedWeekdays.isNotEmpty) {
      setState(() {
        // 새로 감지된 요일로 교체 (기존 선택 초기화 후 설정)
        selectedWeekdays = detectedWeekdays;
        // 날짜 지정과 요일은 동시에 사용할 수 없으므로 날짜 초기화
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
          selectedWeekdays = {}; // 날짜 지정 시 요일 초기화
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

  /// 음성 인식 텍스트에서 장소를 매칭하는 함수
  /// - 공백을 제거하여 비교 (음성인식에서 "시흥집" -> "시흥 집" 문제 해결)
  /// - 더 긴 이름을 먼저 매칭하여 정확도 향상 ("집" vs "시흥집")
  void _matchPlaceFromInput(String input) {
    if (_lockSelectedPlaceFromAutoMatch && selectedPlace != null) {
      return;
    }

    final normalizedInput = input.replaceAll(' ', '').toLowerCase();

    // 장소를 이름 길이 기준 내림차순 정렬 (긴 이름 우선)
    final sortedPlaces = List<Map<String, dynamic>>.from(places);
    sortedPlaces.sort((a, b) {
      final nameA = (a['name']?.toString() ?? '').length;
      final nameB = (b['name']?.toString() ?? '').length;
      return nameB.compareTo(nameA); // 내림차순
    });

    // 1차: 공백 제거 후 완전 포함 매칭
    for (final place in sortedPlaces) {
      final name = place['name']?.toString() ?? '';
      final normalizedName = name.replaceAll(' ', '').toLowerCase();

      if (normalizedInput.contains(normalizedName)) {
        setState(() => selectedPlace = place);
        return;
      }
    }

    // 2차: 원본 텍스트에서 공백 포함 매칭 (fallback)
    final lowerInput = input.toLowerCase();
    for (final place in sortedPlaces) {
      final name = place['name']?.toString() ?? '';
      if (lowerInput.contains(name.toLowerCase())) {
        setState(() => selectedPlace = place);
        return;
      }
    }
  }

  Map<String, dynamic>? _findMatchingPlace(Map<String, dynamic>? candidate) {
    if (candidate == null) return null;

    final candidateId = candidate['id']?.toString().trim();
    if (candidateId != null && candidateId.isNotEmpty) {
      for (final place in places) {
        final placeId = place['id']?.toString().trim();
        if (placeId != null && placeId.isNotEmpty && placeId == candidateId) {
          return place;
        }
      }
    }

    final candidateName = _normalizePlaceName(candidate['name']);
    final candidateLat = _toDouble(candidate['lat']);
    final candidateLng = _toDouble(candidate['lng']);

    for (final place in places) {
      if (_normalizePlaceName(place['name']) != candidateName) {
        continue;
      }

      final placeLat = _toDouble(place['lat']);
      final placeLng = _toDouble(place['lng']);
      if (_sameCoordinate(placeLat, candidateLat) &&
          _sameCoordinate(placeLng, candidateLng)) {
        return place;
      }
    }

    return null;
  }

  String _normalizePlaceName(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '');
  }

  bool _sameCoordinate(double? first, double? second) {
    if (first == null || second == null) {
      return false;
    }

    return (first - second).abs() < 0.000001;
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
    if (mode == AlarmDetectionMode.wifi &&
        !(triggerOnExit && !triggerOnEntry)) {
      _showWifiWaitTimeoutDialog();
    }
  }

  Future<void> _showWifiWaitTimeoutDialog() async {
    final l10n = AppLocalizations.of(context);
    final selected = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(l10n.get('wifi_wait_dialog_title')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.get('wifi_wait_dialog_message'),
                  style: const TextStyle(fontSize: 13, height: 1.35),
                ),
                const SizedBox(height: 12),
                for (final minutes in const [5, 15, 30])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$minutes${l10n.get('min_suffix')}'),
                    trailing:
                        wifiWaitTimeoutMinutes == minutes
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                    onTap: () => Navigator.pop(dialogContext, minutes),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.get('wifi_wait_custom')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(dialogContext, -1),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.get('cancel')),
              ),
            ],
          ),
    );

    if (!mounted || selected == null) return;
    if (selected == -1) {
      final custom = await _showCustomWifiWaitDialog();
      if (!mounted || custom == null) return;
      setState(() => wifiWaitTimeoutMinutes = custom);
      return;
    }
    setState(() {
      wifiWaitTimeoutMinutes = WifiAlarmSettings.normalizeWaitMinutes(selected);
    });
  }

  Future<int?> _showCustomWifiWaitDialog() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: wifiWaitTimeoutMinutes.toString(),
    );
    String? errorText;
    final result = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(l10n.get('wifi_wait_custom_title')),
                  content: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: l10n.get('wifi_wait_custom_hint'),
                      errorText: errorText,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(l10n.get('cancel')),
                    ),
                    TextButton(
                      onPressed: () {
                        final value = int.tryParse(controller.text.trim());
                        if (value == null ||
                            value < WifiAlarmSettings.minWaitMinutes ||
                            value > WifiAlarmSettings.maxWaitMinutes) {
                          setDialogState(() {
                            errorText = l10n.get('wifi_wait_invalid');
                          });
                          return;
                        }
                        Navigator.pop(dialogContext, value);
                      },
                      child: Text(l10n.get('confirm')),
                    ),
                  ],
                ),
          ),
    );
    controller.dispose();
    return result;
  }

  Widget _buildWifiWaitTimeoutTile() {
    final l10n = AppLocalizations.of(context);
    if (detectionMode != AlarmDetectionMode.wifi || !_selectedPlaceHasWifi) {
      return const SizedBox.shrink();
    }
    if (triggerOnExit && !triggerOnEntry) {
      return _buildWifiExitInfoTile();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: InkWell(
        onTap: _showWifiWaitTimeoutDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.get('wifi_wait_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.getWithArgs('wifi_wait_subtitle', {
                        'minutes': wifiWaitTimeoutMinutes.toString(),
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWifiExitInfoTile() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('wifi_exit_behavior_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    l10n.get('wifi_exit_behavior_message'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
      final weekdayCodes = _getWeekdays(l10n);
      final weekday = l10n.get(weekdayCodes[selectedDate!.weekday % 7]);
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

  // ✅ TimePicker 표시 (시간 조건 선택용)
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
      setState(() {
        conditionTime = picked;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('add_new_location_alarm')),
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
            // ✅ 음성인식 중 표시
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
                      AppLocalizations.of(context).get('listening_prompt'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _stopListening,
                      child: Text(AppLocalizations.of(context).get('done_btn')),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _alarmNameController, // ✅ 컨트롤러 연결
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).get('alarm_name_label'),
                // ✅ 마이크 버튼 추가
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: _isListening ? AppColors.danger : AppColors.primary,
                  ),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),
              ),
              minLines: 1,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              onChanged: (val) {
                setState(() => alarmName = val);
                _checkAlarmConditionFromName(val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              initialValue: selectedPlace,
              items:
                  places.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final place = entry.value;
                    final isLocked = SubscriptionService.isIndexLocked(
                      idx,
                      _placeLimit,
                    );
                    return DropdownMenuItem(
                      value: place,
                      enabled: !isLocked,
                      child: Row(
                        children: [
                          if (isLocked)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(
                                Icons.lock,
                                size: 14,
                                color: AppColors.divider,
                              ),
                            ),
                          Text(
                            place['name'] ??
                                AppLocalizations.of(
                                  context,
                                ).get('no_name_label'),
                            style: TextStyle(
                              color: isLocked ? AppColors.divider : null,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (place) {
                setState(() {
                  selectedPlace = place;
                  _lockSelectedPlaceFromAutoMatch = false;
                  if (!AlarmDetectionMode.placeHasWifi(place)) {
                    detectionMode = AlarmDetectionMode.gps;
                  }
                });
              },
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).get('select_place_label'),
              ),
            ),
            const SizedBox(height: 20),
            _buildDetectionModeSelector(),
            _buildWifiWaitTimeoutTile(),
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

            // ✅ 조건 설정 (선택사항) - 통합 UI
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
                      onPressed: () {
                        _showCalendar();
                        // 날짜 선택하면 요일 해제
                      },
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
            ElevatedButton(
              onPressed:
                  (_isSaving ||
                          alarmName.trim().isEmpty ||
                          (!triggerOnEntry && !triggerOnExit) ||
                          (!alarmSoundEnabled && !vibrationEnabled))
                      ? null
                      : () async {
                        // ✅ 중복 저장 방지 — 즉시 버튼 비활성화(재진입 차단)
                        if (_isSaving) return;
                        setState(() => _isSaving = true);

                        try {
                          final l10n = AppLocalizations.of(context);
                          final sortedWeekdays =
                              _getWeekdays(l10n)
                                  .where((d) => selectedWeekdays.contains(d))
                                  .toList();

                          // ✅ startTimeMs 계산 (시간 조건이 있고 날짜/요일 없을 때)
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
                            startTimeMs = scheduledTime.millisecondsSinceEpoch;
                          }

                          final id = const Uuid().v4();
                          final savedDetectionMode = AlarmDetectionMode.forSave(
                            detectionMode,
                            selectedPlace,
                          );
                          final alarm = {
                            'id': id,
                            'name': alarmName,
                            'place': selectedPlace?['name'] ?? '',
                            'placeId': selectedPlace?['id']?.toString(),
                            'trigger': triggerOnEntry ? 'entry' : 'exit',
                            'detectionMode': savedDetectionMode,
                            if (savedDetectionMode == AlarmDetectionMode.wifi &&
                                triggerOnEntry)
                              'wifiWaitTimeoutMinutes':
                                  WifiAlarmSettings.normalizeWaitMinutes(
                                    wifiWaitTimeoutMinutes,
                                  ),
                            'repeat':
                                selectedDate != null
                                    ? selectedDate!.toIso8601String()
                                    : (sortedWeekdays.isNotEmpty
                                        ? sortedWeekdays
                                        : null),
                            'enabled': true,
                            'triggerCount': 0,
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
                          };

                          // ✅ 1) 로컬 저장 먼저 — 가장 빠르고 핵심
                          await HiveHelper.saveLocationAlarm(alarm);

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                            'alarm_name_$id',
                            alarm['name'] as String,
                          );

                          // ✅ 2) 활성화 안내 (필요 시)
                          if (!context.mounted) return;
                          await AlarmActivationNotice.showIfNeeded(
                            context,
                            alarm,
                            selectedPlace,
                          );

                          // ✅ 3) 즉시 화면 이탈
                          if (!context.mounted) return;
                          Navigator.pop(context);

                          // ✅ 4) 백그라운드 작업 (pop 후, UI 비차단)
                          //    광고/하트비트/모니터링은 저장 응답을 막지 않도록 분리
                          SubscriptionService.getCurrentPlan()
                              .then(
                                (plan) =>
                                    SubscriptionService.requestAdIfNeeded(plan),
                              )
                              .catchError((e) => print('⚠️ 광고 요청 실패: $e'));
                          LocationMonitorService.sendWatchdogHeartbeat()
                              .catchError(
                                (e) => print('⚠️ Heartbeat 전송 실패: $e'),
                              );
                          SmartLocationService.updatePlaces()
                              .then(
                                (_) =>
                                    SmartLocationMonitor.startSmartMonitoring(),
                              )
                              .catchError((e) => print('⚠️ 모니터링 갱신 실패: $e'));
                        } catch (e) {
                          print('❌ 알람 저장 실패: $e');
                          if (mounted) {
                            setState(() => _isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppLocalizations.of(context).getWithArgs(
                                    'alarm_save_failed',
                                    {'error': '$e'},
                                  ),
                                ),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
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
                      : Center(
                        child: Text(
                          AppLocalizations.of(context).get('save_btn'),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

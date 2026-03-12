// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';

// Package imports:
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// Project imports:
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/widgets/subscription_limit_dialog.dart';
import 'package:ringinout/utils/trigger_keywords.dart';

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

  // ✅ 조건 설정 (선택사항) - 모든 알람은 "최초 1회"
  TimeOfDay? conditionTime; // 시간 조건 (선택적)

  // ✅ 음성인식 관련
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;

  final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  List<Map<String, dynamic>> places = [];
  Map<String, dynamic>? selectedPlace;
  int? _placeLimit; // null = unlimited

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

    final box = HiveHelper.placeBox;
    places = box.values.map((e) => Map<String, dynamic>.from(e)).toList();

    // 잠긴 장소 파악용 플랜 로드
    SubscriptionService.getCurrentPlan().then((plan) {
      if (mounted) {
        setState(() {
          _placeLimit = SubscriptionService.placeLimit(plan);
        });
      }
    });

    // ✅ 음성인식에서 전달받은 데이터 초기화
    if (widget.preSelectedPlace != null) {
      // 전달받은 장소와 매칭되는 places 찾기
      final matchedPlace = places.firstWhere(
        (p) => p['id'] == widget.preSelectedPlace!['id'],
        orElse: () => widget.preSelectedPlace!,
      );
      selectedPlace = matchedPlace;
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

  void _startListening() async {
    if (!_speechAvailable) return;

    setState(() => _isListening = true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _alarmNameController.text = result.recognizedWords;
          alarmName = result.recognizedWords;
        });
        // 실시간으로 장소 매칭 시도
        _checkAlarmConditionFromName(result.recognizedWords);
      },
      localeId: 'ko_KR',
      listenMode: stt.ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    _autoMatchPlace();
  }

  // ✅ 띄어쓰기 제거 함수
  String _removeSpaces(String text) {
    return text.replaceAll(' ', '').replaceAll('\u00A0', '');
  }

  // ✅ 음성인식 완료 후 장소 자동 매칭
  void _autoMatchPlace() {
    final text = alarmName.toLowerCase();
    final textNoSpace = _removeSpaces(text);

    for (final place in places) {
      final placeName = place['name']?.toString().toLowerCase() ?? '';
      final placeNameNoSpace = _removeSpaces(placeName);

      if (placeNameNoSpace.isNotEmpty &&
          textNoSpace.contains(placeNameNoSpace)) {
        setState(() => selectedPlace = place);
        break;
      }
    }
  }

  @override
  void dispose() {
    _alarmNameController.dispose();
    _speech.stop();
    super.dispose();
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
      // 둘 다 매칭되면 마지막 입력 우선 - 진입으로 설정
      setState(() {
        triggerOnEntry = true;
        triggerOnExit = false;
      });
    }

    // 장소 매칭 개선: 공백 제거 후 비교, 긴 이름 우선
    _matchPlaceFromInput(input);
  }

  /// 음성 인식 텍스트에서 장소를 매칭하는 함수
  /// - 공백을 제거하여 비교 (음성인식에서 "시흥집" -> "시흥 집" 문제 해결)
  /// - 더 긴 이름을 먼저 매칭하여 정확도 향상 ("집" vs "시흥집")
  void _matchPlaceFromInput(String input) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 위치알람 추가')),
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
                    const Text(
                      '🎙️ 듣는 중... 말씀해 주세요!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _stopListening,
                      child: const Text('완료'),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _alarmNameController, // ✅ 컨트롤러 연결
              decoration: InputDecoration(
                labelText: '알람 이름',
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
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              onChanged: (val) {
                setState(() => alarmName = val);
                _checkAlarmConditionFromName(val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: selectedPlace,
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
                            place['name'] ?? '이름 없음',
                            style: TextStyle(
                              color: isLocked ? AppColors.divider : null,
                            ),
                          ),
                        ],
                      ),
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

            // ✅ 조건 설정 (선택사항) - 통합 UI
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
              subtitle: '각 사용자 폰 기본 벨소리',
              enabled: false,
              onToggle: (val) {},
              onTap: () {},
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed:
                  (alarmName.trim().isEmpty ||
                          (!triggerOnEntry && !triggerOnExit))
                      ? null
                      : () {
                        if (mounted) {
                          Navigator.pop(context); // ✅ 먼저 pop
                        }

                        () async {
                          final plan =
                              await SubscriptionService.getCurrentPlan();
                          final limit = SubscriptionService.activeAlarmLimit(
                            plan,
                          );
                          if (limit != null) {
                            final activeCount =
                                HiveHelper.alarmBox.values
                                    .where(
                                      (alarm) =>
                                          alarm is Map &&
                                          alarm['enabled'] == true,
                                    )
                                    .length;
                            if (activeCount >= limit && mounted) {
                              await SubscriptionLimitDialog.showAlarmLimit(
                                context,
                                plan: plan,
                                limit: limit,
                              );
                              return;
                            }
                          }

                          await SubscriptionService.requestAdIfNeeded(plan);
                          final sortedWeekdays =
                              weekdays
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
                          final alarm = {
                            'id': id,
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
                            'triggerCount': 0,
                            'startTimeMs': startTimeMs,
                            // ✅ 날짜/요일 + 시간 조건
                            if (conditionTime != null &&
                                (selectedDate != null ||
                                    sortedWeekdays.isNotEmpty)) ...{
                              'hour': conditionTime!.hour,
                              'minute': conditionTime!.minute,
                            },
                          };

                          await HiveHelper.alarmBox.put(
                            id,
                            alarm,
                          ); // ✅ put 사용! (id가 key 역할)

                          // ✅ Watchdog heartbeat 전송 (활성 알람 수 동기화)
                          await LocationMonitorService.sendWatchdogHeartbeat();
                          print('🔔 알람 추가 후 Heartbeat 전송');

                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString(
                            'alarm_name_$id',
                            alarm['name'],
                          );

                          // ✅ 네이티브 SmartLocationService 즉시 업데이트 (최초 진입/진출 알람 대응)
                          await SmartLocationService.updatePlaces();
                          print('🎯 SmartLocationService 장소 업데이트 완료');

                          await SmartLocationMonitor.startSmartMonitoring();
                        }();
                      },
              child: const Center(child: Text('저장')),
            ),
          ],
        ),
      ),
    );
  }
}

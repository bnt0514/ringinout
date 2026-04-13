import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project imports
import 'package:ringinout/features/alarm/alarm_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';
import 'package:ringinout/pages/testpage.dart';
import 'package:ringinout/pages/server_subscription_page.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/location_alarm_list.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/active_alarm_state.dart';
import 'package:ringinout/services/map_usage_service.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool isSelectionMode = false;
  bool _isRestoringAlarm = false; // 알람 화면 복원 중복 방지

  // 🎤 음성 알람 채널
  static const _voiceAlarmChannel = MethodChannel(
    'com.bnt0514.ringinout/voice_alarm',
  );

  // ✅ 앱 백그라운드 전환 채널
  static const _appLifecycleChannel = MethodChannel(
    'com.bnt0514.ringinout/app_lifecycle',
  );

  final List<Widget> _pages = [
    const KeepAliveWidget(child: AlarmPage()),
    const KeepAliveWidget(child: MyPlacesPage()),
    const KeepAliveWidget(child: TestPage()),
    const KeepAliveWidget(child: ServerSubscriptionPage()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱 시작 시 음성 알람 모드 체크 + 복구 사유 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVoiceAlarmMode();
      _checkRecoveryReason();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ✅ 포그라운드 복귀 시 활성 알람 화면 복원
      _restoreAlarmScreenIfNeeded();
      // 앱이 포그라운드로 돌아올 때마다 체크
      _checkVoiceAlarmMode();
      // ★ 네이티브에서 알람 종료 시 설정한 disabled 플래그 즉시 반영
      LocationMonitorService.processNativeDisabledFlagsNow();
      // 🗺️ Admin 강제 업로드 명령 확인
      MapUsageService.checkForceUploadCommand();
    }
  }

  /// ✅ 활성 알람이 있으면 전체화면 알람 페이지로 복귀
  Future<void> _restoreAlarmScreenIfNeeded() async {
    if (!mounted || _isRestoringAlarm) return;
    _isRestoringAlarm = true;

    try {
      await _doRestoreAlarm();
    } finally {
      _isRestoringAlarm = false;
    }
  }

  Future<void> _doRestoreAlarm() async {
    if (!mounted) return;

    // 1) Flutter 측 ActiveAlarmState 체크
    if (ActiveAlarmState.isActive) {
      debugPrint('🔔 포그라운드 복귀: Flutter 활성 알람 감지 → 알람 화면 복원');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !ActiveAlarmState.isActive) return;
        Navigator.of(context).pushNamed(
          '/fullScreenAlarm',
          arguments: {
            'alarmTitle': ActiveAlarmState.alarmTitle ?? 'Ringinout',
            'id': ActiveAlarmState.alarmData?['id'],
            'soundPath':
                ActiveAlarmState.soundPath ??
                'assets/sounds/thoughtfulringtone.mp3',
          },
        );
      });
      return;
    }

    // 2) 네이티브 알람 화면에서 홈 버튼으로 나간 경우 체크
    // ※ Flutter SharedPreferences 플러그인이 자동으로 'flutter.' 접두사를 붙이므로
    //    Kotlin에서 'flutter.native_alarm_active'로 저장한 값은
    //    Flutter에서 'native_alarm_active'로 읽어야 함
    // ※ SharedPreferences.getInstance()는 캐시를 사용하므로
    //    Kotlin에서 직접 쓴 값을 읽으려면 reload() 필수!
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // ✅ 코틀린에서 직접 쓴 값을 반영하기 위해 캐시 리로드
      final nativeAlarmActive = prefs.getBool('native_alarm_active') ?? false;
      debugPrint('🔔 네이티브 알람 플래그 체크: $nativeAlarmActive');
      if (nativeAlarmActive && mounted) {
        // ★ 먼저 정보를 읽은 뒤 플래그 클리어 — resume 중복 호출 시 재진입 방지
        final title = prefs.getString('native_alarm_title') ?? 'Ringinout';
        final placeId = prefs.getString('native_alarm_place_id');
        final alarmId = prefs.getString('native_alarm_id');

        // 즉시 플래그 제거
        await prefs.remove('native_alarm_active');
        await prefs.remove('native_alarm_title');
        await prefs.remove('native_alarm_place_id');
        await prefs.remove('native_alarm_id');

        debugPrint(
          '🔔 네이티브 알람 정보: title=$title, placeId=$placeId, alarmId=$alarmId',
        );

        debugPrint('🔔 포그라운드 복귀: 네이티브 활성 알람 감지 → 알람 화면 복원');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushNamed(
            '/fullScreenAlarm',
            arguments: {
              'alarmTitle': title,
              'id': alarmId ?? placeId,
              'soundPath': 'assets/sounds/thoughtfulringtone.mp3',
            },
          );
        });
      }
    } catch (e) {
      debugPrint('🔔 네이티브 알람 상태 체크 실패: $e');
    }
  }

  // 🎤 위젯에서 음성 알람 모드로 실행되었는지 체크
  Future<void> _checkVoiceAlarmMode() async {
    try {
      final bool shouldStartVoice = await _voiceAlarmChannel.invokeMethod(
        'checkVoiceAlarmMode',
      );
      if (shouldStartVoice && mounted) {
        debugPrint('🎤 위젯에서 음성 알람 모드 시작!');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => const AddLocationAlarmPage(startWithVoice: true),
          ),
        );
      }
    } catch (e) {
      debugPrint('🎤 음성 알람 모드 체크 실패: $e');
    }
  }

  // 🔄 앱 복구 사유 확인 → SnackBar로 사용자에게 안내
  static const _watchdogChannel = MethodChannel(
    'com.bnt0514.ringinout/watchdog',
  );

  Future<void> _checkRecoveryReason() async {
    try {
      final String? reason = await _watchdogChannel.invokeMethod(
        'getRecoveryReason',
      );
      if (reason != null && reason.isNotEmpty && mounted) {
        debugPrint('🔄 앱 복구 사유: $reason');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(reason, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            backgroundColor: Colors.blueGrey[700],
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('🔄 복구 사유 확인 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // ★ 알람 탭에서 선택 모드 활성 시: 선택 모드 해제
        if (_selectedIndex == 0) {
          final controller = AlarmListController.instance;
          if (controller != null && controller.isSelectionMode.value) {
            controller.isSelectionMode.value = false;
            controller.selectedIndexes.value = {};
            return;
          }
        }

        // 기본 페이지(알람)가 아니면 기본 페이지로 이동
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        } else {
          // ✅ 앱을 백그라운드로 보냄 (SystemNavigator.pop()은 앱을 종료시키므로 사용 금지)
          _appLifecycleChannel.invokeMethod('moveTaskToBack');
        }
      },
      child: Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          firstChild: _buildBottomNav(),
          secondChild: _buildSelectionBar(),
          crossFadeState:
              isSelectionMode
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context); // 👈 테마 색상 자동 적용
    return BottomNavigationBar(
      key: const ValueKey('default_nav'),
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: theme.colorScheme.primary,
      unselectedItemColor: theme.bottomNavigationBarTheme.unselectedItemColor,
      selectedFontSize: 14,
      unselectedFontSize: 12,
      selectedIconTheme: const IconThemeData(size: 28),
      unselectedIconTheme: const IconThemeData(size: 22),
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.alarm),
          label: l10n.get('nav_alarm'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.place),
          label: l10n.get('nav_my_places'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.mic),
          label: l10n.get('nav_voice'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.gps_fixed),
          label: l10n.get('nav_gps'),
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    final l10n = AppLocalizations.of(context);
    return BottomAppBar(
      key: const ValueKey('selection_bar'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.select_all),
            label: Text(l10n.get('select_all')),
            onPressed: () {
              // TODO: Implement selection logic
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete),
            label: Text(l10n.get('delete_selected')),
            onPressed: () {
              // TODO: Implement delete logic
            },
          ),
        ],
      ),
    );
  }
}

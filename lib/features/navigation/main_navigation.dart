import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/features/alarm/alarm_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';
import 'package:ringinout/pages/testpage.dart';
import 'package:ringinout/pages/server_subscription_page.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/location_monitor_service.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool isSelectionMode = false;

  // 🎤 음성 알람 채널
  static const _voiceAlarmChannel = MethodChannel(
    'com.example.ringinout/voice_alarm',
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
    // 앱 시작 시 음성 알람 모드 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVoiceAlarmMode();
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
      // 앱이 포그라운드로 돌아올 때마다 체크
      _checkVoiceAlarmMode();
      // ★ 네이티브에서 알람 종료 시 설정한 disabled 플래그 즉시 반영
      LocationMonitorService.processNativeDisabledFlagsNow();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // 기본 페이지(알람)가 아니면 기본 페이지로 이동
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
        } else {
          // 기본 페이지에서 뒤로가기하면 로그인 페이지로
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/login', (route) => false);
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
        const BottomNavigationBarItem(icon: Icon(Icons.mic), label: '음성'),
        const BottomNavigationBarItem(
          icon: Icon(Icons.subscriptions),
          label: '구독 관리',
        ),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return BottomAppBar(
      key: const ValueKey('selection_bar'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.select_all),
            label: const Text('전체 선택'),
            onPressed: () {
              // TODO: Implement selection logic
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
            onPressed: () {
              // TODO: Implement delete logic
            },
          ),
        ],
      ),
    );
  }
}

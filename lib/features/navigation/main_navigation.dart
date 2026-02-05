import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/features/alarm/alarm_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';
import 'package:ringinout/pages/testpage.dart';
import 'package:ringinout/pages/gps_page.dart';
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/services/app_localizations.dart';

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
    const KeepAliveWidget(child: GpsPage()),
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
    return Scaffold(
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
    );
  }

  Widget _buildBottomNav() {
    final l10n = AppLocalizations.of(context);
    return BottomNavigationBar(
      key: const ValueKey('default_nav'),
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey,
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
          icon: Icon(Icons.gps_fixed),
          label: 'GPS',
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

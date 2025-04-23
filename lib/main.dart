// main.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ringinout/add_location_alarm_page.dart';
import 'package:ringinout/alarm_notification_helper.dart';
import 'package:ringinout/edit_location_alarm_page.dart';
import 'package:ringinout/hive_helper.dart';
import 'package:ringinout/location_monitor_service.dart';
import 'package:ringinout/saved_locations_page.dart';
import 'package:ringinout/location_alarm_list.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final geolocator = GeolocatorPlatform.instance;

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    final position = await geolocator.getCurrentPosition();
    print('🛰 [백그라운드 위치] ${position.latitude}, ${position.longitude}');

    // TODO: 여기서 거리 계산하고 알람 발생
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// 강제 우회용 열거형 정의
enum AndroidForegroundServiceType {
  dataSync,
  mediaPlayback,
  location,
  phoneCall,
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      foregroundServiceNotificationId: 888,
      notificationChannelId: 'ringinout_channel',
      initialNotificationTitle: 'Ringinout 실행 중',
      initialNotificationContent: '위치 기반 알람 감시 중',
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  await service.startService();
}

late String alarmSound;
late String vibration;
late String snooze;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔓 위치 권한 먼저 요청
  await Permission.location.request();
  await Permission.locationAlways.request();
  await Permission.notification.request(); // 🔔 알림 권한 추가!

  // 🗃️ Hive 초기화
  await Hive.initFlutter();
  await Hive.openBox('locations');
  await Hive.openBox('locationAlarms');

  alarmSound = await HiveHelper.getAlarmSound();
  vibration = await HiveHelper.getVibration();
  snooze = await HiveHelper.getSnooze();

  await initializeNotifications(); // ✅ 알림 초기화 추가
  await initializeService();

  // 🚀 앱 실행
  runApp(const RinginoutApp());
}

Future<void> _initLocationPermission() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    debugPrint("📍 위치 서비스 꺼져 있음");
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      debugPrint("📍 위치 권한 거부됨");
      return;
    }
  }
}

class RinginoutApp extends StatelessWidget {
  const RinginoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ringinout',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const MainNavigationPage(),
      routes: {
        '/add_location_alarm': (context) => const AddLocationAlarmPage(),
        '/edit_location_alarm': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map;
          return EditLocationAlarmPage(
            existingAlarm: args['alarm'],
            alarmIndex: args['index'],
          );
        },
      },

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      builder: (context, child) {
        return Stack(
          children: [
            child!,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<String?>(
                valueListenable: AlarmPopupManager.instance.message,
                builder: (context, value, _) {
                  if (value == null) return const SizedBox.shrink();
                  return Material(
                    color: Colors.redAccent,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => AlarmPopupManager.instance.clear(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class AlarmPopupManager {
  AlarmPopupManager._internal();
  static final instance = AlarmPopupManager._internal();

  final ValueNotifier<String?> message = ValueNotifier(null);
  final player = AudioPlayer();

  Future<void> show(String msg) async {
    message.value = msg;
    try {
      await player.setAsset('assets/sounds/beep.mp3');
      player.play();
    } catch (e) {
      debugPrint('효과음 재생 오류: $e');
    }
  }

  void clear() {
    message.value = null;
  }
}

// ✅ 나머지 AlarmPage, MyPlacesPage 등은 그대로 유지됩니다.

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  bool isSelectionMode = false; // 선택모드 상태 변수 추가

  final List<Widget> _pages = [
    const AlarmPage(),
    const MyPlacesPage(),
    const TimerPage(),
    const StopwatchPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: AnimatedCrossFade(
        duration: const Duration(milliseconds: 1000),
        firstChild: BottomNavigationBar(
          key: const ValueKey('default'),
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Colors.indigo,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 14,
          unselectedFontSize: 12,
          selectedIconTheme: const IconThemeData(size: 28),
          unselectedIconTheme: const IconThemeData(size: 22),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.alarm), label: '알람'),
            BottomNavigationBarItem(icon: Icon(Icons.place), label: 'MyPlaces'),
            BottomNavigationBarItem(icon: Icon(Icons.timer), label: '타이머'),
            BottomNavigationBarItem(
              icon: Icon(Icons.watch_later),
              label: '스톱워치',
            ),
          ],
        ),
        secondChild: BottomAppBar(
          key: const ValueKey('selection'),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.select_all),
                label: const Text('전체 선택'),
                onPressed: () {
                  // 전체 선택 로직
                },
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('삭제'),
                onPressed: () {
                  // 삭제 로직
                },
              ),
            ],
          ),
        ),
        crossFadeState:
            isSelectionMode
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
      ),
    );
  }
}

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 🚀 위치 기반 알람 감시 시작
      LocationMonitorService().startMonitoring((type, alarm) async {
        // ✅ Snackbar은 앱이 포그라운드 상태일 때만 보임
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🔔 ${alarm['name']} - $type 알람 발생!')),
          );
        }

        // ✅ 이제 context 넘길 필요 없이 그냥 호출하면 됨
        await showAlarmNotification(
          alarm['name'],
          alarm['message'],
          id: alarm['id'] ?? 0,
        );
      });
    });
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('정렬 방식 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('알람 시간 순서'),
                  onTap: () => Navigator.pop(context, 'time'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('사용자 지정 순서'),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 40,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          color: Colors.indigo,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '알람',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                onPressed: _showSortOptions,
              ),
            ],
          ),
        ),
        Container(
          color: Colors.indigo.shade200,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [Tab(text: '위치알람'), Tab(text: '기본알람')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              KeepAliveWidget(child: LocationAlarmList()),
              Center(child: Text('위치알람 리스트')),
              Center(child: Text('기본알람 리스트')),
            ],
          ),
        ),
      ],
    );
  }
}

class KeepAliveWidget extends StatefulWidget {
  final Widget child;
  const KeepAliveWidget({super.key, required this.child});

  @override
  State<KeepAliveWidget> createState() => _KeepAliveWidgetState();
}

class _KeepAliveWidgetState extends State<KeepAliveWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class MyPlacesPage extends StatelessWidget {
  const MyPlacesPage({super.key});

  void _showSortOptions(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('정렬 방식 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('알람 시간 순서'),
                  onTap: () => Navigator.pop(context, 'time'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('사용자 지정 순서'),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(
            top: 40,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          color: Colors.indigo,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MyPlaces',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sort, color: Colors.white),
                onPressed: () => _showSortOptions(context),
              ),
            ],
          ),
        ),
        const Expanded(child: SavedLocationsPage()),
      ],
    );
  }
}

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('타이머'));
  }
}

class StopwatchPage extends StatelessWidget {
  const StopwatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('스톱워치'));
  }
}

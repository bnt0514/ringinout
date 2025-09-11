import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Project imports
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_location_alarm_page.dart';
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/features/navigation/main_navigation.dart';
import 'package:ringinout/app/routes.dart';

class RinginoutApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Map<String, dynamic>? pendingLaunchAlarm;

  const RinginoutApp({
    super.key,
    required this.navigatorKey,
    this.pendingLaunchAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Ringinout',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handlePendingAlarm(context);
          });
          return const MainNavigationPage();
        },
      ),
      routes: _buildRoutes(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    );
  }

  void _handlePendingAlarm(BuildContext context) {
    if (pendingLaunchAlarm != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder:
              (_) => FullScreenAlarmPage(
                alarmTitle: pendingLaunchAlarm!['title'] ?? 'Ringinout 알람',
                alarmData: {'id': pendingLaunchAlarm!['id']},
                soundPath: pendingLaunchAlarm!['soundPath'],
                onDismiss: _stopAlarmSound,
              ),
        ),
      );
    }
  }

  Future<void> _stopAlarmSound() async {
    const platform = MethodChannel('com.example.ringinout/audio');
    try {
      await platform.invokeMethod('stopRingtone');
    } catch (e) {
      print('🔕 알람 정지 실패: $e');
    }
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      '/add_location_alarm': (context) => const AddLocationAlarmPage(),
      '/fullScreenAlarm': (context) {
        final args =
            ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        return FullScreenAlarmPage(
          alarmTitle: args['alarmTitle'] ?? 'Ringinout 알람',
          alarmData: {'id': args['id']},
          soundPath:
              args['soundPath'] ?? 'assets/sounds/thoughtfulringtone.mp3',
          onDismiss: _stopAlarmSound,
        );
      },
      '/edit_location_alarm': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map?;
        return EditLocationAlarmPage(
          alarmIndex: args?['index'],
          existingAlarmData: args?['existingAlarmData'] ?? {},
        );
      },
      '/my_places': (context) => const MyPlacesPage(),
    };
  }
}
//앱의 기본 설정(테마, 로케일 등)//
//라우팅 설정
///보류 중인 알람 처리
//알람 소리 제어
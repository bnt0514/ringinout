import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/pages/add_location_alarm_page.dart';
import 'package:ringinout/pages/edit_location_alarm_page.dart';
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/pages/login_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/pages/permission_guide_page.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/features/navigation/main_navigation.dart';

class AppRoutes {
  static Future<void> _stopAlarmSound() async {
    const platform = MethodChannel('com.example.ringinout/audio');
    try {
      await platform.invokeMethod('stopRingtone');
    } catch (e) {
      print('🔕 알람 정지 실패: $e');
    }
  }

  static Map<String, WidgetBuilder> routes = {
    '/login': (context) => const LoginPage(),
    '/home': (context) => const MainNavigationPage(),
    '/permission_guide': (context) => const PermissionGuidePage(),
    '/add_location_alarm': (context) => const AddLocationAlarmPage(),
    '/fullScreenAlarm': (context) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return FullScreenAlarmPage(
        alarmTitle: args['alarmTitle'] ?? 'Ringinout 알람',
        alarmData: {'id': args['id']},
        soundPath: args['soundPath'] ?? 'assets/sounds/thoughtfulringtone.mp3',
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
    '/settings': (context) => const SettingsPage(),
  };
}

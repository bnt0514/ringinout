/// Method channel names
class ChannelNames {
  static const String audio = 'com.example.ringinout/audio';
  static const String notification = 'ringinout_channel';
  static const String fullscreenNative =
      'com.example.ringinout/fullscreen_native';
  static const String permissions = 'ringinout/permissions';
}

/// Route names
class RouteNames {
  static const String addLocationAlarm = '/add_location_alarm';
  static const String fullScreenAlarm = '/fullScreenAlarm';
  static const String editLocationAlarm = '/edit_location_alarm';
  static const String myPlaces = '/my_places';
}

/// Background service constants
class ServiceConstants {
  static const int notificationId = 888;
  static const String channelId = 'ringinout_channel';
  static const String notificationTitle = 'Ringinout 실행 중';
  static const String notificationContent = '위치 기반 알람 감시 중';
}

/// Asset paths
class AssetPaths {
  static const String defaultAlarmSound =
      'assets/sounds/thoughtfulringtone.mp3';
}

/// Default values
class Defaults {
  static const String alarmTitle = 'Ringinout 알람';
  static const String untitledAlarm = '이름 없음';
}
// 상수정의 채널명 등

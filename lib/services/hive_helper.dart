// hive_helper.dart

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:hive/hive.dart';

class HiveHelper {
  // 📦 MyPlaces 저장용 box
  static final _placeBox = Hive.box('locations');

  // ✅ MyPlaces 관련
  static List<Map<String, dynamic>> getSavedLocations() {
    return _placeBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> addLocation(Map<String, dynamic> location) async {
    await _placeBox.add(location);
  }

  static void updateLocation(Map<String, dynamic> updated) {
    final index = _placeBox.values.toList().indexWhere(
      (loc) => loc['name'] == updated['name'],
    );
    if (index != -1) {
      _placeBox.putAt(index, updated);
    }
  }

  static Future<void> deleteLocation(int index) async {
    await _placeBox.deleteAt(index);
  }

  static Map<String, dynamic> getLocation(int index) {
    return Map<String, dynamic>.from(_placeBox.getAt(index));
  }

  static int getLength() {
    return _placeBox.length;
  }

  // ✅ 알람 저장용 box
  static Future<void> saveLocationAlarm(Map<String, dynamic> alarm) async {
    final box = Hive.box('locationAlarms');
    await box.add(alarm);
  }

  static List<Map<String, dynamic>> getLocationAlarms() {
    final box = Hive.box('locationAlarms');
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> deleteLocationAlarm(int index) async {
    final box = Hive.box('locationAlarms');
    await box.deleteAt(index);
  }

  static Future<void> updateLocationAlarm(
    int index,
    Map<String, dynamic> updatedAlarm,
  ) async {
    final box = Hive.box('locationAlarms');
    await box.putAt(index, updatedAlarm);
  }

  // ✅ FAB 위치 저장
  static Future<void> saveFabPosition(double x, double y) async {
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('fabX', x);
    await settingsBox.put('fabY', y);
  }

  static Future<Offset> getFabPosition() async {
    final settingsBox = await Hive.openBox('settings');
    final x = settingsBox.get('fabX', defaultValue: 300.0);
    final y = settingsBox.get('fabY', defaultValue: 600.0);
    return Offset(x, y);
  }

  // ✅ 알람 설정값 (벨소리, 진동, 다시 울림) 저장/불러오기
  static Future<void> saveAlarmSound(String path) async {
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('alarmSound', path);
  }

  static Future<String> getAlarmSound() async {
    final settingsBox = await Hive.openBox('settings');
    return settingsBox.get('alarmSound', defaultValue: '기본 벨소리');
  }

  static Future<void> saveVibration(String vibration) async {
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('vibration', vibration);
  }

  static Future<String> getVibration() async {
    final settingsBox = await Hive.openBox('settings');
    return settingsBox.get('vibration', defaultValue: '짧은 진동');
  }

  static Future<void> saveSnooze(String snooze) async {
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('snooze', snooze);
  }

  static Future<String> getSnooze() async {
    final settingsBox = await Hive.openBox('settings');
    return settingsBox.get('snooze', defaultValue: '5분 후 1회');
  }
}

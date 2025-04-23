import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ringinout/alarm_notification_helper.dart';

class LocationMonitorService {
  final Map<String, bool> alarmStates = {}; // 각 알람별 진입 상태 저장
  StreamSubscription<Position>? _positionStream;

  void startMonitoring(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) {
    print('🚀 위치 감지 시작됨!');

    _positionStream = Geolocator.getPositionStream().listen((position) async {
      print('🛰 현재 위치: ${position.latitude}, ${position.longitude}');

      final alarms = Hive.box('locationAlarms').values.toList();

      for (int i = 0; i < alarms.length; i++) {
        final alarm = Map<String, dynamic>.from(alarms[i]);
        print('🔍 감지 중인 알람: ${alarm['name']}');

        final place = Hive.box('locations').values.firstWhere(
          (p) => p['name'] == alarm['place'],
          orElse: () => null,
        );

        if (place == null) {
          print('⚠ 장소 정보를 찾을 수 없음: ${alarm['place']}');
          continue;
        }

        final double lat = place['lat'];
        final double lng = place['lng'];
        const double radius = 100.0;

        final distance = Geolocator.distanceBetween(
          lat,
          lng,
          position.latitude,
          position.longitude,
        );

        print('📍 장소 위치: $lat, $lng');
        print('📍 현재 위치: ${position.latitude}, ${position.longitude}');
        print('📏 거리: $distance / 반경: $radius');

        final alarmKey = alarm['name'];
        final wasInside = alarmStates[alarmKey] ?? false;
        final isInside = distance <= radius;

        print('📌 wasInside: $wasInside, isInside: $isInside');

        // ignore: unused_local_variable
        final soundPath = alarm['sound'] ?? 'assets/sounds/1.mp3';

        if (!wasInside && isInside && alarm['trigger'] == 'entry') {
          print('✅ 진입 감지됨: ${alarm['name']}');

          await _playAlarmSound(alarm['sound']);
          await showAlarmNotification(
            alarm['name'],
            alarm['message'],
            id: alarm['id'] ?? 0,
          );
          onTrigger('entry', alarm);
        } else if (wasInside && !isInside && alarm['trigger'] == 'exit') {
          print('✅ 진출 감지됨: ${alarm['name']}');

          await _playAlarmSound(alarm['sound']);
          await showAlarmNotification(
            alarm['name'],
            alarm['message'],
            id: alarm['id'] ?? 1,
          );
          onTrigger('exit', alarm);
        }

        // 상태 갱신
        alarmStates[alarmKey] = isInside;
      }
    });
  }

  void stopMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  final AudioPlayer _player = AudioPlayer();

  Future<void> _playAlarmSound(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) return;

    try {
      await _player.setAsset(soundPath);
      await _player.play();
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }
}

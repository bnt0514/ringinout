// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 네이티브 호출용

// Package imports:
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';

// Project imports:
import 'package:ringinout/services/alarm_notification_helper.dart';
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/main.dart'; // navigatorKey 접근용

class LocationMonitorService {
  final Map<String, bool> alarmStates = {}; // 각 알람별 진입 상태 저장
  StreamSubscription<Position>? _positionStream;
  final AudioPlayer _player = AudioPlayer();

  // 위치 감지 시작
  void startMonitoring(
    void Function(String type, Map<String, dynamic> alarm) onTrigger,
  ) async {
    print('🚀 위치 감지 시작됨!');

    // 위치 스트림을 비동기적으로 실행하여 UI 차단 방지
    _positionStream = Geolocator.getPositionStream().listen((position) async {
      print('🛰 현재 위치: ${position.latitude}, ${position.longitude}');

      final alarms = Hive.box('locationAlarms').values.toList();

      // 알람을 순차적으로 처리 (비동기 작업 처리)
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

        final soundPath =
            alarm['sound'] ?? 'assets/sounds/thoughtfulringtone.mp3';
        final alarmName = alarm['name'] ?? '알람';
        final alarmMessage = alarm['message'] ?? '알람이 감지되었습니다.';
        final placeName = alarm['place'] ?? 'unknown';
        final trigger = alarm['trigger'] ?? 'entry';

        // 고유 ID 생성: 장소 + 트리거 + 이름 조합
        final alarmId = '$placeName|$trigger|$alarmName'.hashCode;

        // 비동기 작업을 순차적으로 처리
        if (!wasInside && isInside && trigger == 'entry') {
          print('✅ 진입 감지됨: $alarmName');

          await _playAlarmSound(soundPath);
          await _navigateToAlarmPage(alarmName, soundPath, true);
          onTrigger('entry', alarm);
        } else if (wasInside && !isInside && trigger == 'exit') {
          print('✅ 진출 감지됨: $alarmName');

          await _playAlarmSound(soundPath);
          await _navigateToAlarmPage(alarmName, soundPath, false);
          onTrigger('exit', alarm);
        }

        alarmStates[alarmKey] = isInside;
      }
    });
  }

  // 위치 감지 중지
  void stopMonitoring() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  // 벨소리 재생
  Future<void> _playAlarmSound(String? soundPath) async {
    if (soundPath == null || soundPath.isEmpty) return;

    try {
      await _player.setAsset(soundPath); // 벨소리 설정
      await _player.play(); // 벨소리 재생
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }

  // 네이티브 전체화면 알람 페이지 호출
  Future<void> _navigateToAlarmPage(
    String alarmTitle,
    String soundPath,
    bool isFirst,
  ) async {
    try {
      // ✅ 네이티브 전체화면 알람 호출
      const platform = MethodChannel('com.example.ringinout/fullscreen');
      await platform.invokeMethod('launchAlarmPage');
      print('📣 MethodChannel launchAlarmPage 호출 완료');

      // ✅ 앱이 포그라운드 상태일 때만 Flutter 알람 페이지 띄움
      if (navigatorKey.currentState?.mounted == true) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder:
                (context) => FullScreenAlarmPage(
                  alarmTitle: alarmTitle,
                  isFirstRing: isFirst,
                  soundPath: soundPath,
                ),
          ),
        );
      } else {
        print('🕶 앱이 백그라운드 상태 — Flutter 페이지 생략');
      }
    } catch (e) {
      print('⚠ MethodChannel launchAlarmPage 실패: $e');
    }
  }
}

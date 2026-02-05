// lib/widgets/realbackgroundtestpanel.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/alarm_notification_helper.dart';

class RealBackgroundTestPanel extends StatefulWidget {
  const RealBackgroundTestPanel({Key? key}) : super(key: key);

  @override
  _RealBackgroundTestPanelState createState() =>
      _RealBackgroundTestPanelState();
}

class _RealBackgroundTestPanelState extends State<RealBackgroundTestPanel> {
  Timer? _enterTimer;
  Timer? _exitTimer;
  int _enterCountdown = 0;
  int _exitCountdown = 0;
  String? _selectedLocation;

  @override
  Widget build(BuildContext context) {
    final locations = HiveHelper.getSavedLocations();

    if (locations.isEmpty) {
      return Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.location_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                '등록된 장소가 없습니다',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('MyPlaces에서 장소를 먼저 등록해주세요'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  '🌙 백그라운드 알람 테스트',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // 설명 박스
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📱 백그라운드 테스트 방법:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('1. 아래 버튼으로 진입/진출 타이머 시작'),
                  Text('2. 즉시 홈 버튼 눌러서 앱 백그라운드로 보내기'),
                  Text('3. 5초 후 자동으로 알람 트리거 강제 실행'),
                  Text('4. 실제 백그라운드 알림이 오는지 확인'),
                ],
              ),
            ),
            SizedBox(height: 16),

            // 위치별 테스트 버튼들
            ...locations.map((location) {
              final locationName = location['name'] as String;

              // ✅ 디버그: 알람 검색 로그 추가
              print('🔍 알람 검색 중: $locationName');
              final alarms = HiveHelper.getLocationAlarms();
              print('📋 전체 알람 목록: $alarms');

              final hasEnterAlarm = _hasAlarmForEvent(locationName, 'enter');
              final hasExitAlarm = _hasAlarmForEvent(locationName, 'exit');

              print('✅ $locationName 알람 상태:');
              print('   - 진입 알람: $hasEnterAlarm');
              print('   - 진출 알람: $hasExitAlarm');

              return Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📍 $locationName',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),

                    // ✅ 디버그 정보 표시
                    Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔍 디버그 정보:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '전체 알람 수: ${alarms.length}개',
                            style: TextStyle(fontSize: 11),
                          ),
                          ...alarms
                              .map(
                                (alarm) => Text(
                                  '- ${alarm['name']}: ${alarm['locationName']} (진입:${alarm['enter']}, 진출:${alarm['exit']}, 활성:${alarm['enabled']})',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                              .toList(),
                        ],
                      ),
                    ),

                    Row(
                      children: [
                        // 진입 테스트 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                hasEnterAlarm
                                    ? () {
                                      _startBackgroundTest(locationName, true);
                                    }
                                    : null,
                            icon: Icon(Icons.login),
                            label: Text(
                              _enterCountdown > 0 &&
                                      _selectedLocation == locationName
                                  ? '진입 ${_enterCountdown}초'
                                  : '진입 테스트',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hasEnterAlarm ? Colors.green : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // 진출 테스트 버튼
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                hasExitAlarm
                                    ? () {
                                      _startBackgroundTest(locationName, false);
                                    }
                                    : null,
                            icon: Icon(Icons.logout),
                            label: Text(
                              _exitCountdown > 0 &&
                                      _selectedLocation == locationName
                                  ? '진출 ${_exitCountdown}초'
                                  : '진출 테스트',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  hasExitAlarm ? Colors.orange : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!hasEnterAlarm && !hasExitAlarm)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '⚠️ 이 위치에 설정된 알람이 없습니다',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // ✅ 알람 검색 로직만 수정 (나머지는 그대로)
  bool _hasAlarmForEvent(String locationName, String event) {
    try {
      final alarms = HiveHelper.getLocationAlarms();
      print('🔍 _hasAlarmForEvent 호출: $locationName, $event');
      print('📋 검색할 알람 목록: $alarms');

      for (var alarm in alarms) {
        print('🔎 알람 체크: ${alarm['name']}');

        // ✅ 실제 데이터 구조에 맞게 수정
        final alarmPlace =
            alarm['place'] ?? alarm['locationName']; // place 또는 locationName
        final alarmTrigger = alarm['trigger']; // entry 또는 exit
        final isEnabled = alarm['enabled'] == true;

        print(
          '   - place: $alarmPlace == $locationName ? ${alarmPlace == locationName}',
        );
        print('   - trigger: $alarmTrigger');
        print('   - enabled: $isEnabled');

        // ✅ 조건 매칭 로직 수정
        bool isEventMatch = false;
        if (event == 'enter' && alarmTrigger == 'entry') {
          isEventMatch = true;
        } else if (event == 'exit' && alarmTrigger == 'exit') {
          isEventMatch = true;
        }

        print('   - event match: $event <-> $alarmTrigger = $isEventMatch');

        final isMatch = isEnabled && alarmPlace == locationName && isEventMatch;

        if (isMatch) {
          print('✅ 매칭된 알람 발견: ${alarm['name']}');
          return true;
        }
      }

      print('❌ 매칭된 알람 없음');
      return false;
    } catch (e) {
      print('❌ _hasAlarmForEvent 에러: $e');
      return false;
    }
  }

  void _startBackgroundTest(String locationName, bool isEntering) {
    _selectedLocation = locationName;

    // 사용자에게 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⏰ 5초 후 ${locationName} ${isEntering ? '진입' : '진출'} 테스트! 지금 홈 버튼을 누르세요!',
        ),
        backgroundColor: isEntering ? Colors.green : Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );

    // 카운트다운 시작
    if (isEntering) {
      _enterCountdown = 5;
      _enterTimer?.cancel();
      _enterTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _enterCountdown--;
        });

        if (_enterCountdown <= 0) {
          timer.cancel();
          _triggerBackgroundAlarm(locationName, true);
        }
      });
    } else {
      _exitCountdown = 5;
      _exitTimer?.cancel();
      _exitTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _exitCountdown--;
        });

        if (_exitCountdown <= 0) {
          timer.cancel();
          _triggerBackgroundAlarm(locationName, false);
        }
      });
    }
  }

  void _triggerBackgroundAlarm(String locationName, bool isEntering) {
    print('🌙 백그라운드에서 강제 알람 트리거: $locationName ${isEntering ? '진입' : '진출'}');

    // 해당 위치의 알람 찾기
    final alarms = HiveHelper.getLocationAlarms();
    for (var alarm in alarms) {
      final alarmPlace = alarm['place'] ?? alarm['locationName'];
      final alarmTrigger = alarm['trigger'];
      final isEnabled = alarm['enabled'] == true;

      // ✅ 조건 매칭
      bool shouldTrigger = false;
      if (isEntering && alarmTrigger == 'entry') {
        shouldTrigger = true;
      } else if (!isEntering && alarmTrigger == 'exit') {
        shouldTrigger = true;
      }

      if (isEnabled && alarmPlace == locationName && shouldTrigger) {
        print('🔔 알람 트리거: ${alarm['name']}');

        // 실제 알람 트리거 (백그라운드에서)
        _executeBackgroundAlarm(alarm, isEntering);
      }
    }

    setState(() {
      _selectedLocation = null;
      _enterCountdown = 0;
      _exitCountdown = 0;
    });
  }

  void _executeBackgroundAlarm(Map<String, dynamic> alarm, bool isEntering) {
    // ✅ 장소명 가져오기 수정
    final locationName = alarm['place'] ?? alarm['locationName'] ?? '알 수 없는 장소';

    final message =
        isEntering
            ? '${locationName}에 도착했습니다! 🎯'
            : '${locationName}에서 나갔습니다! 🚶‍♂️';

    // Native 알람 트리거
    AlarmNotificationHelper.showNativeAlarm(
      title: '🧪 [백그라운드 테스트] ${alarm['name']}',
      message: message,
      sound: alarm['sound'] ?? 'default',
      vibrate: alarm['vibrate'] ?? true,
    );

    print('🔔 백그라운드 테스트 알람 실행: ${alarm['name']} - $message');
  }

  @override
  void dispose() {
    _enterTimer?.cancel();
    _exitTimer?.cancel();
    super.dispose();
  }
}

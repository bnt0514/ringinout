import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/test_controller.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/widgets/realbackgroundtestpanel.dart';

class TestGeofencePanel extends StatelessWidget {
  const TestGeofencePanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TestGeofenceController>(
      builder: (context, controller, child) {
        final locations = HiveHelper.getSavedLocations();

        if (locations.isEmpty) {
          return Column(
            // ✅ Card를 Column으로 변경
            children: [
              Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('등록된 장소가 없습니다.'),
                ),
              ),
              RealBackgroundTestPanel(), // ✅ 백그라운드 테스트 패널 추가
            ],
          );
        }

        return Column(
          // ✅ Card를 Column으로 변경하고 여러 위젯 포함
          children: [
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '🧪 지오펜스 테스트',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    ...locations.map((location) {
                      final locationName = location['name'] as String;
                      final isInside =
                          controller.locationStates[locationName] ?? false;
                      final alarms =
                          HiveHelper.getLocationAlarms()
                              .where(
                                (alarm) =>
                                    alarm['enabled'] == true &&
                                    alarm['locationName'] == locationName,
                              )
                              .length;

                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(locationName),
                          subtitle: Text(
                            '${isInside ? '진입 상태' : '진출 상태'} • 활성 알람: ${alarms}개',
                            style: TextStyle(
                              color: isInside ? Colors.green : Colors.grey,
                            ),
                          ),
                          trailing: Container(
                            width: 60,
                            height: 30,
                            child: GestureDetector(
                              onTap: () {
                                print(
                                  '🧪 테스트 토글: $locationName ${isInside ? '→ 진출' : '→ 진입'}',
                                );
                                controller.toggleLocationState(locationName);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color:
                                      isInside
                                          ? Colors.green
                                          : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: AnimatedAlign(
                                  duration: Duration(milliseconds: 200),
                                  alignment:
                                      isInside
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    margin: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isInside
                                          ? Icons.location_on
                                          : Icons.location_off,
                                      size: 16,
                                      color:
                                          isInside ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            print('🔄 모든 상태 초기화');
                            controller.resetAllStates();
                          },
                          icon: Icon(Icons.refresh),
                          label: Text('초기화'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('📊 테스트 상태: ${controller.locationStates}');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('테스트 상태가 콘솔에 출력되었습니다'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: Icon(Icons.info),
                          label: Text('상태 확인'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            RealBackgroundTestPanel(), // ✅ 백그라운드 테스트 패널 추가
          ],
        );
      },
    );
  }
}

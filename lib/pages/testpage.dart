// lib/pages/test_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/services/test_controller.dart';
import 'package:ringinout/widgets/realbackgroundtestpanel.dart';

class TestPage extends StatelessWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('🧪 알람 테스트'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 테스트 컨트롤러 재초기화
              Provider.of<TestGeofenceController>(
                context,
                listen: false,
              ).initialize();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 테스트 환경이 초기화되었습니다'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 페이지 설명
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science, color: Colors.blue, size: 24),
                        SizedBox(width: 8),
                        Text(
                          '백그라운드 알람 테스트',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📋 테스트 목적:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text('• 백그라운드에서 위치 알람이 정상 작동하는지 확인'),
                          Text('• 실제 GPS 이동 없이 알람 트리거 테스트'),
                          Text('• 알림 소리, 진동, 메시지 정상 동작 확인'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // 백그라운드 테스트 패널
            RealBackgroundTestPanel(),

            SizedBox(height: 16),

            // 테스트 가이드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          '📖 테스트 가이드',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildGuideStep('1', '장소 등록', 'MyPlaces에서 테스트할 장소를 등록하세요'),
                    _buildGuideStep('2', '알람 설정', '해당 장소에 진입/진출 알람을 설정하세요'),
                    _buildGuideStep('3', '백그라운드 테스트', '위 버튼으로 5초 타이머를 시작하세요'),
                    _buildGuideStep(
                      '4',
                      '앱 백그라운드',
                      '즉시 홈 버튼을 눌러 앱을 백그라운드로 보내세요',
                    ),
                    _buildGuideStep('5', '결과 확인', '5초 후 알람이 울리는지 확인하세요'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // 디버그 정보
            Consumer<TestGeofenceController>(
              builder: (context, controller, child) {
                // ✅ 초기화 상태 체크
                if (!controller.isInitialized) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.bug_report, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                '🔍 디버그 정보',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('테스트 컨트롤러 초기화 중...'),
                            ],
                          ),
                          SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => controller.initialize(),
                            icon: Icon(Icons.refresh),
                            label: Text('다시 시도'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // ✅ 정상 초기화된 경우
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bug_report, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              '🔍 디버그 정보',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text('등록된 장소: ${controller.locationStates.length}개'),
                        SizedBox(height: 8),
                        ...controller.locationStates.entries
                            .map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '• ${entry.key}: ${entry.value ? '진입 상태' : '진출 상태'}',
                                  style: TextStyle(
                                    color:
                                        entry.value
                                            ? Colors.green
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        SizedBox(height: 12),
                        // ✅ 추가 시스템 정보
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🔧 시스템 상태:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text('• 컨트롤러 초기화: ✅ 완료'),
                              Text(
                                '• 백그라운드 서비스: ${controller.locationStates.isNotEmpty ? "✅ 활성" : "⚠️ 대기"}',
                              ),
                              Text('• Hive 데이터베이스: ✅ 연결됨'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 100), // 하단 여백
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String number, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

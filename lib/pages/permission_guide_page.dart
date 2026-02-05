// lib/pages/permission_guide_page.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 권한 가이드 페이지 - 사용자가 쉽게 권한을 설정할 수 있도록 안내
class PermissionGuidePage extends StatefulWidget {
  final VoidCallback? onComplete;

  const PermissionGuidePage({super.key, this.onComplete});

  @override
  State<PermissionGuidePage> createState() => _PermissionGuidePageState();
}

class _PermissionGuidePageState extends State<PermissionGuidePage> {
  int _currentStep = 0;
  final List<_PermissionStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializeSteps();
    _checkCurrentPermissions();
  }

  void _initializeSteps() {
    _steps.addAll([
      _PermissionStep(
        title: '위치 권한',
        description: '알람을 울릴 위치를 감지하기 위해 필요합니다.',
        icon: Icons.location_on,
        color: Colors.blue,
        checkPermission: () async {
          final status = await ph.Permission.location.status;
          return status.isGranted;
        },
        requestPermission: () async {
          await ph.Permission.location.request();
        },
      ),
      _PermissionStep(
        title: '백그라운드 위치',
        description: '앱을 사용하지 않을 때도 위치를 감지합니다.',
        icon: Icons.my_location,
        color: Colors.green,
        checkPermission: () async {
          final status = await ph.Permission.locationAlways.status;
          return status.isGranted;
        },
        requestPermission: () async {
          await ph.Permission.locationAlways.request();
        },
      ),
      _PermissionStep(
        title: '알림 권한',
        description: '알람이 울릴 때 알림을 표시합니다.',
        icon: Icons.notifications_active,
        color: Colors.orange,
        checkPermission: () async {
          final status = await ph.Permission.notification.status;
          return status.isGranted;
        },
        requestPermission: () async {
          await ph.Permission.notification.request();
        },
      ),
      _PermissionStep(
        title: '다른 앱 위에 표시',
        description: '전체화면 알람을 표시하기 위해 필요합니다.',
        icon: Icons.layers,
        color: Colors.purple,
        checkPermission: () async {
          final status = await ph.Permission.systemAlertWindow.status;
          return status.isGranted;
        },
        requestPermission: () async {
          await ph.Permission.systemAlertWindow.request();
        },
      ),
    ]);
  }

  Future<void> _checkCurrentPermissions() async {
    for (int i = 0; i < _steps.length; i++) {
      final isGranted = await _steps[i].checkPermission();
      setState(() {
        _steps[i].isGranted = isGranted;
      });
    }

    // 첫 번째 미허용 권한으로 이동
    for (int i = 0; i < _steps.length; i++) {
      if (!_steps[i].isGranted) {
        setState(() => _currentStep = i);
        break;
      }
    }
  }

  Future<void> _handlePermissionRequest(int index) async {
    final step = _steps[index];

    await step.requestPermission();

    // 잠시 대기 후 권한 재확인
    await Future.delayed(const Duration(milliseconds: 500));
    final isGranted = await step.checkPermission();

    setState(() {
      step.isGranted = isGranted;
      if (isGranted && index < _steps.length - 1) {
        _currentStep = index + 1;
      }
    });
  }

  bool get _allPermissionsGranted {
    return _steps.every((step) => step.isGranted);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('권한 설정'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // 진행 상태 표시
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: List.generate(_steps.length, (index) {
                final step = _steps[index];
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color:
                          step.isGranted ? Colors.green : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),

          // 권한 목록
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                final isActive = index == _currentStep;

                return Card(
                  elevation: isActive ? 4 : 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive ? step.color : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // 아이콘
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                step.isGranted
                                    ? Colors.green.shade100
                                    : step.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            step.isGranted ? Icons.check : step.icon,
                            color: step.isGranted ? Colors.green : step.color,
                          ),
                        ),
                        const SizedBox(width: 16),

                        // 텍스트
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                step.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: step.isGranted ? Colors.green : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                step.description,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 버튼
                        if (step.isGranted)
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _handlePermissionRequest(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('허용'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 완료 버튼
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _allPermissionsGranted
                        ? () {
                          widget.onComplete?.call();
                          Navigator.of(context).pop();
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: Text(
                  _allPermissionsGranted ? '설정 완료! 🎉' : '모든 권한을 허용해주세요',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          // 나중에 버튼
          if (!_allPermissionsGranted)
            TextButton(
              onPressed: () {
                widget.onComplete?.call();
                Navigator.of(context).pop();
              },
              child: Text(
                '나중에 설정하기',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _PermissionStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Future<bool> Function() checkPermission;
  final Future<void> Function() requestPermission;
  bool isGranted;

  _PermissionStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.checkPermission,
    required this.requestPermission,
    this.isGranted = false,
  });
}

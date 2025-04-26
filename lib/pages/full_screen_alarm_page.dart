import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class FullScreenAlarmPage extends StatefulWidget {
  final String alarmTitle;
  final bool isFirstRing;
  final String soundPath;

  const FullScreenAlarmPage({
    super.key,
    required this.alarmTitle,
    required this.isFirstRing,
    required this.soundPath,
  });

  @override
  State<FullScreenAlarmPage> createState() => _FullScreenAlarmPageState();
}

class _FullScreenAlarmPageState extends State<FullScreenAlarmPage> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playAlarmSound();
  }

  Future<void> _playAlarmSound() async {
    try {
      await _player.setAsset(widget.soundPath);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }

  Future<void> _stopAlarmSound() async {
    try {
      await _player.stop();
    } catch (e) {
      print('🔕 벨소리 정지 실패: $e');
    }
  }

  Future<void> _onSnooze() async {
    await _stopAlarmSound();

    int? selectedMinutes = await showDialog<int>(
      context: context,
      builder: (context) {
        int? customInput;
        return AlertDialog(
          title: const Text("다시 울림 시간 선택"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...[1, 3, 5, 10, 30].map(
                (m) => ListTile(
                  title: Text("$m분 후"),
                  onTap: () => Navigator.pop(context, m),
                ),
              ),
              ListTile(
                title: const Text("직접 입력"),
                onTap: () async {
                  final controller = TextEditingController();
                  final result = await showDialog<int>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("다시 울림 시간 (분)"),
                          content: TextField(
                            controller: controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: "예: 7"),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                final input = int.tryParse(controller.text);
                                Navigator.pop(context, input);
                              },
                              child: const Text("확인"),
                            ),
                          ],
                        ),
                  );
                  Navigator.pop(context, result);
                },
              ),
            ],
          ),
        );
      },
    );

    if (selectedMinutes != null && selectedMinutes > 0) {
      // TODO: selectedMinutes 분 후 다시 알람 예약 로직 추가
      print("⏰ $selectedMinutes분 후 다시 울림 예약됨");
    }

    Navigator.of(context).pop(); // 페이지 닫기
  }

  Future<void> _onConfirm() async {
    await _stopAlarmSound();
    // TODO: 알람 종료 처리 (Hive 등에서 알람 상태 변경 등)
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _stopAlarmSound();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.isFirstRing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.alarmTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isFirst) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      onPressed: _onConfirm,
                      child: const Text(
                        "알람 종료",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 20),
                  ],
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    onPressed: _onSnooze,
                    child: const Text(
                      "다시 울림",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

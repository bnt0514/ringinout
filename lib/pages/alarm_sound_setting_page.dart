import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:ringinout/services/alarm_sound_player.dart';
import 'package:ringinout/services/hive_helper.dart';

class AlarmSoundSettingPage extends StatefulWidget {
  final String? currentPath;
  final Function(String path) onSelected;

  const AlarmSoundSettingPage({
    super.key,
    this.currentPath,
    required this.onSelected,
  });

  @override
  State<AlarmSoundSettingPage> createState() => _AlarmSoundSettingPageState();
}

class _AlarmSoundSettingPageState extends State<AlarmSoundSettingPage> {
  String? selectedPath;
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false; // 벨소리 재생 중인지 여부를 추적하는 상태 변수
  bool alarmDisabled = false; // 알람 비활성화 상태

  final List<String> soundFiles = [
    'assets/sounds/beep.mp3',
    'assets/sounds/horizonmusic.mp3',
    'assets/sounds/thoughtfulringtone.mp3',
  ];

  @override
  void initState() {
    super.initState();
    selectedPath = widget.currentPath;
  }

  @override
  void dispose() {
    _player.stop(); // 알람음 멈춤
    _player.dispose();
    super.dispose();
  }

  // 알람 비활성화 시 리소스를 정리하는 부분
  Future<void> _stopAlarmIfDisabled() async {
    if (alarmDisabled) {
      await AlarmSoundPlayer.stop(); // 알람 음 중지 및 리소스 해제
      print("🔕 알람 비활성화됨. 벨소리 중지 및 리소스 해제.");
    }
  }

  Future<void> _playSound(String path) async {
    try {
      // 벨소리 재생 중에 새로운 벨소리가 선택되면, 이전 벨소리 재생을 멈춤
      if (isPlaying) {
        await _player.stop();
      }

      // 벨소리 재생 시작
      await _player.setAsset(path);
      await _player.play();
      setState(() {
        isPlaying = true; // 벨소리 재생 중
      });

      // 벨소리 재생 완료 시, 상태를 초기화하여 뒤로 가는 동작 방지
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          setState(() {
            isPlaying = false; // 벨소리 끝난 후, 재생 상태 초기화
          });
          print("🎵 벨소리 재생 끝. 뒤로 가기 방지.");
        }
      });
    } catch (e) {
      print('🔕 알람음 재생 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알람음 설정')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text("알람 비활성화"),
            value: alarmDisabled,
            onChanged: (bool value) {
              setState(() {
                alarmDisabled = value;
              });
              // 알람 비활성화 상태에서 벨소리 중지 및 리소스 해제
              _stopAlarmIfDisabled();
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: soundFiles.length,
              itemBuilder: (context, index) {
                final path = soundFiles[index];
                final fileName = path.split('/').last;

                return ListTile(
                  title: Text(fileName),
                  trailing:
                      selectedPath == path
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                  onTap: () async {
                    setState(() => selectedPath = path);
                    widget.onSelected(path);

                    // 🔊 미리듣기
                    await _playSound(path);

                    // 💾 Hive 저장 (수정 페이지에서 key가 전달된 경우에만)
                    final box = HiveHelper.alarmBox;
                    final settings = ModalRoute.of(context)?.settings;
                    if (settings != null && settings.arguments is String) {
                      final alarmKey = settings.arguments as String;
                      final alarm = box.get(alarmKey);
                      if (alarm != null) {
                        alarm['sound'] = path;
                        await box.put(alarmKey, alarm);
                      }
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

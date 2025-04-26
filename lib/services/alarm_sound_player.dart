import 'package:just_audio/just_audio.dart';

class AlarmSoundPlayer {
  static AudioPlayer? _player; // AudioPlayer 객체를 null로 초기화

  // 벨소리 재생
  static Future<void> play(String assetPath) async {
    try {
      // 새로 벨소리를 선택할 때마다 이전 재생을 멈추고 새로 시작
      await stop(); // 기존 벨소리 정지

      // AudioPlayer가 null일 경우에만 새로운 인스턴스를 생성
      if (_player == null) {
        _player = AudioPlayer();
        _player!.playerStateStream.listen((state) {
          // 재생 상태 변경 시, 새로운 벨소리가 나오면 상태 갱신
          if (state.processingState == ProcessingState.completed) {
            // 재생이 끝났으면 뒤로 가는 동작을 하지 않도록 처리
            print("🎵 벨소리 끝났지만 페이지는 유지됩니다.");
            // 페이지를 뒤로 가지 않도록 설정
          }
        });
      }

      // 새 벨소리 설정 및 재생
      await _player!.setAsset(assetPath); // 벨소리 설정
      await _player!.play(); // 벨소리 재생
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }

  // 벨소리 멈추기
  static Future<void> stop() async {
    try {
      if (_player != null) {
        await _player!.stop(); // 벨소리 정지
        await _player!.dispose(); // AudioPlayer 정리
        _player = null; // 인스턴스 해제
      }
    } catch (e) {
      print('🔕 벨소리 멈추기 실패: $e');
    }
  }

  // 상태 확인 (디버깅용)
  static bool isPlaying() {
    return _player?.playing ?? false;
  }
}

import 'package:just_audio/just_audio.dart';

class AlarmSoundPlayer {
  static final _player = AudioPlayer();

  static Future<void> play(String assetPath) async {
    try {
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (e) {
      print('🔕 벨소리 재생 실패: $e');
    }
  }

  static Future<void> stop() async {
    await _player.stop();
  }
}

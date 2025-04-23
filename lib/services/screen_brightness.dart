import 'package:screen_brightness/screen_brightness.dart';

Future<void> increaseScreenBrightnessTemporarily() async {
  try {
    double originalBrightness = await ScreenBrightness().current;
    print("현재 밝기: $originalBrightness");

    // 밝기 최대로 설정
    await ScreenBrightness().setScreenBrightness(1.0);
    print("📢 밝기 최대치로 설정됨");

    // 10초 후 원래 밝기로 복원 (필요 시 시간 조절 가능)
    await Future.delayed(const Duration(seconds: 10));
    await ScreenBrightness().setScreenBrightness(originalBrightness);
    print("🌙 원래 밝기로 복구됨");
  } catch (e) {
    print("❌ 밝기 설정 실패: $e");
  }
}

// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  runApp(const MaterialApp(home: DebugTestScreen()));
}

class DebugTestScreen extends StatelessWidget {
  const DebugTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("✅ DebugTestScreen build 실행됨");

    Future.delayed(const Duration(seconds: 2), () {
      debugPrint("➡️ 화면 전환 실행");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TextScreen()),
      );
    });

    return const Scaffold(
      body: Center(child: Text('🔵 초기화면: DebugTestScreen')),
    );
  }
}

class TextScreen extends StatelessWidget {
  const TextScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint("✅ TextScreen 도착!");
    return const Scaffold(body: Center(child: Text('🟢 다음화면: TextScreen')));
  }
}

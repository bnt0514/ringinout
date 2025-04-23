import 'package:flutter/material.dart';

class FullScreenAlarmPage extends StatelessWidget {
  final String alarmTitle;
  final bool isFirstRing;

  const FullScreenAlarmPage({
    super.key,
    required this.alarmTitle,
    required this.isFirstRing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                alarmTitle,
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
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // 알람 종료
                    },
                    child: const Text(
                      "확인",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                  if (!isFirstRing) ...[
                    const SizedBox(width: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 15,
                        ),
                      ),
                      onPressed: () {
                        // TODO: 다시 울림 로직 추가 예정
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        "다시 울림",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

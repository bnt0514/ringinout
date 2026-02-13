// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';

class SnoozeSettingPage extends StatelessWidget {
  final String currentSnooze;
  final Function(String) onSelected;

  const SnoozeSettingPage({
    super.key,
    required this.currentSnooze,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final snoozeOptions = ['1분 후', '3분 후', '5분 후', '10분 후', '30분 후'];

    return Scaffold(
      appBar: AppBar(title: const Text('다시 울림 설정')),
      body: ListView(
        children: [
          ExpansionTile(
            title: const Text(
              '📌 필독* 위치알람 다시울림 상세설명',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
              ),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  '위치알람은 최소 2번 울립니다. 알람 본연 목적 달성 위함이니 양해 부탁 드립니다.\n'
                  '\n'
                  '* 첫 알람 이후 아래에서 선택한 시간에 맞춰 두 번째 알람이 울립니다.\n'
                  '* 두 번째 알람부터는 사용자가 알람 종료 또는 다시 울림을 알람 화면에서 직접 선택 가능합니다.',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const Divider(),
          ...snoozeOptions.map((option) {
            final isSelected = option == currentSnooze;
            return ListTile(
              title: Text(option),
              trailing:
                  isSelected
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
              onTap: () {
                onSelected(option);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}

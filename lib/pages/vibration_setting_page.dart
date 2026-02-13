// Flutter imports:
import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';

class VibrationSettingPage extends StatelessWidget {
  final String currentVibration;
  final Function(String) onSelected;

  const VibrationSettingPage({
    super.key,
    required this.currentVibration,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final vibrationOptions = ['짧은 진동', '긴 진동', '두 번 진동', '강한 진동'];

    return Scaffold(
      appBar: AppBar(title: const Text('진동 설정')),
      body: ListView.builder(
        itemCount: vibrationOptions.length,
        itemBuilder: (context, index) {
          final option = vibrationOptions[index];
          final isSelected = option == currentVibration;

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
        },
      ),
    );
  }
}

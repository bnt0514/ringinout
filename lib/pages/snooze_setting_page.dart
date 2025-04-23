import 'package:flutter/material.dart';

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
    final snoozeOptions = ['5분 후 1회', '5분 후 2회', '10분 후 2회', '10분 후 3회'];

    return Scaffold(
      appBar: AppBar(title: const Text('다시 울림 설정')),
      body: ListView.builder(
        itemCount: snoozeOptions.length,
        itemBuilder: (context, index) {
          final option = snoozeOptions[index];
          final isSelected = option == currentSnooze;

          return ListTile(
            title: Text(option),
            trailing:
                isSelected ? const Icon(Icons.check, color: Colors.blue) : null,
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

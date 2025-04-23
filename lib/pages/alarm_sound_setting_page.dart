import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    selectedPath = widget.currentPath;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알람음 설정')),
      body: Column(
        children: [
          ListTile(
            title: const Text('기본 알람음'),
            subtitle: const Text('assets/sounds/1.mp3'),
            trailing: const Icon(Icons.music_note),
            onTap: () {
              setState(() => selectedPath = 'assets/sounds/1.mp3');
              widget.onSelected('assets/sounds/1.mp3');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

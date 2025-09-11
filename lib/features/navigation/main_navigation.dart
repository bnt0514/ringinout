import 'package:flutter/material.dart';

// Project imports
import 'package:ringinout/features/alarm/alarm_page.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';
import 'package:ringinout/pages/testpage.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;
  bool isSelectionMode = false;

  final List<Widget> _pages = [
    const KeepAliveWidget(child: AlarmPage()),
    const KeepAliveWidget(child: MyPlacesPage()),
    const KeepAliveWidget(child: TestPage()),
    const KeepAliveWidget(child: Center(child: Text('스톱워치'))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        firstChild: _buildBottomNav(),
        secondChild: _buildSelectionBar(),
        crossFadeState:
            isSelectionMode
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      key: const ValueKey('default_nav'),
      currentIndex: _selectedIndex,
      onTap: (index) => setState(() => _selectedIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.indigo,
      unselectedItemColor: Colors.grey,
      selectedFontSize: 14,
      unselectedFontSize: 12,
      selectedIconTheme: const IconThemeData(size: 28),
      unselectedIconTheme: const IconThemeData(size: 22),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.alarm), label: '알람'),
        BottomNavigationBarItem(icon: Icon(Icons.place), label: 'MyPlaces'),
        BottomNavigationBarItem(icon: Icon(Icons.science), label: '테스트'),
        BottomNavigationBarItem(icon: Icon(Icons.watch_later), label: '스톱워치'),
      ],
    );
  }

  Widget _buildSelectionBar() {
    return BottomAppBar(
      key: const ValueKey('selection_bar'),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.select_all),
            label: const Text('전체 선택'),
            onPressed: () {
              // TODO: Implement selection logic
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('삭제'),
            onPressed: () {
              // TODO: Implement delete logic
            },
          ),
        ],
      ),
    );
  }
}

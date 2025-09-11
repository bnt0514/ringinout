import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Project imports
import 'package:ringinout/config/constants.dart';
import 'package:ringinout/pages/location_alarm_list.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/features/common/keep_alive_wrapper.dart';

class AlarmPage extends StatefulWidget {
  const AlarmPage({super.key});

  @override
  State<AlarmPage> createState() => _AlarmPageState();
}

class _AlarmPageState extends State<AlarmPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await PermissionManager.hasAllRequiredPermissions();
    if (!hasPermissions) {
      await PermissionManager.requestAllPermissions();
    }
  }

  void _showSortOptions() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('정렬 방식 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('알람 시간 순서'),
                  onTap: () => Navigator.pop(context, 'time'),
                ),
                ListTile(
                  leading: const Icon(Icons.list),
                  title: const Text('사용자 지정 순서'),
                  onTap: () => Navigator.pop(context, 'custom'),
                ),
              ],
            ),
          ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringinout 알람'),
        actions: [
          IconButton(icon: const Icon(Icons.sort), onPressed: _showSortOptions),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: '위치알람'), Tab(text: '기본알람')],
        ),
      ),
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: const [
          KeepAliveWidget(child: LocationAlarmList()),
          KeepAliveWidget(child: Center(child: Text('기본알람 페이지'))),
        ],
      ),
    );
  }
}

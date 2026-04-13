// lib/pages/my_places_tab_page.dart
//
// 내 장소 / 내 기기 탭 전환 페이지
// - GPS 탭 구조(ServerSubscriptionPage)와 동일한 패턴
// - 좌측: 내 장소 (MyPlacesPage), 우측: 내 기기 (MyDevicesPage)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/pages/my_devices_page.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/app_localizations.dart';

class MyPlacesTabPage extends StatefulWidget {
  const MyPlacesTabPage({super.key});

  @override
  State<MyPlacesTabPage> createState() => _MyPlacesTabPageState();
}

class _MyPlacesTabPageState extends State<MyPlacesTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // AppBar actions 갱신
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('page_title_places')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          // sort 버튼은 내 장소 탭에서만
          if (_tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () {
                // MyPlacesPage 내부의 sort 다이얼로그는
                // MyPlacesPage가 자체 관리하므로, GlobalKey 사용
                _myPlacesKey.currentState?.showSortOptionsFromParent();
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: l10n.get('tab_my_places')),
                Tab(text: l10n.get('tab_my_devices')),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MyPlacesPage(key: _myPlacesKey, showAppBar: false),
                const MyDevicesPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final GlobalKey<MyPlacesPageState> _myPlacesKey =
      GlobalKey<MyPlacesPageState>();
}

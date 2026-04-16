// lib/pages/my_places_tab_page.dart
//
// 내 장소 / 내 기기 탭 전환 페이지
// - GPS 탭 구조(ServerSubscriptionPage)와 동일한 패턴
// - 좌측: 내 장소 (MyPlacesPage), 우측: 내 기기 (MyDevicesPage)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/my_places_page.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/app_localizations.dart';

class MyPlacesTabPage extends StatefulWidget {
  const MyPlacesTabPage({super.key});

  @override
  State<MyPlacesTabPage> createState() => _MyPlacesTabPageState();
}

class _MyPlacesTabPageState extends State<MyPlacesTabPage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
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
      body: MyPlacesPage(key: _myPlacesKey, showAppBar: false),
    );
  }

  final GlobalKey<MyPlacesPageState> _myPlacesKey =
      GlobalKey<MyPlacesPageState>();
}

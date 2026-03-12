import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Project imports
import 'package:ringinout/pages/full_screen_alarm_page.dart';
import 'package:ringinout/pages/login_page.dart';
import 'package:ringinout/features/navigation/main_navigation.dart';
import 'package:ringinout/widgets/terms_gate.dart';
import 'package:ringinout/widgets/permission_gate.dart';
import 'package:ringinout/app/routes.dart';
import 'package:ringinout/services/locale_provider.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/config/app_theme.dart';

class RinginoutApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Map<String, dynamic>? pendingLaunchAlarm;

  const RinginoutApp({
    super.key,
    required this.navigatorKey,
    this.pendingLaunchAlarm,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Ringinout',
          theme: AppTheme.theme,
          locale: localeProvider.locale,
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final user = snapshot.data;

              if (user == null) {
                return const LoginPage();
              }

              // 로그인된 경우 메인 화면
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _handlePendingAlarm(context);
                // 로그인 상태 변경 시 플랜 강제 새로고침
                context.read<BillingService>().fetchStatus(forceRefresh: true);
              });
              return const PermissionGate(
                child: TermsGate(child: MainNavigationPage()),
              );
            },
          ),
          routes: AppRoutes.routes,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ko', 'KR'),
            Locale('en', 'US'),
            Locale('ja', 'JP'),
            Locale('zh', 'CN'),
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            // 사용자가 설정한 언어가 있으면 그것 사용
            if (localeProvider.locale != null) {
              return localeProvider.locale;
            }
            // 시스템 언어가 지원되면 그것 사용
            if (locale != null) {
              for (var supportedLocale in supportedLocales) {
                if (supportedLocale.languageCode == locale.languageCode) {
                  return supportedLocale;
                }
              }
            }
            // 기본값은 영어
            return const Locale('en', 'US');
          },
        );
      },
    );
  }

  void _handlePendingAlarm(BuildContext context) {
    if (pendingLaunchAlarm != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(
          builder:
              (_) => FullScreenAlarmPage(
                alarmTitle: pendingLaunchAlarm!['title'] ?? 'Ringinout 알람',
                alarmData: {'id': pendingLaunchAlarm!['id']},
                soundPath: pendingLaunchAlarm!['soundPath'],
                onDismiss: _stopAlarmSound,
              ),
        ),
      );
    }
  }

  Future<void> _stopAlarmSound() async {
    const platform = MethodChannel('com.example.ringinout/audio');
    try {
      await platform.invokeMethod('stopRingtone');
    } catch (e) {
      print('🔕 알람 정지 실패: $e');
    }
  }
}
//앱의 기본 설정(테마, 로케일 등)//
//라우팅 설정
///보류 중인 알람 처리
//알람 소리 제어
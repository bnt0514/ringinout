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
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/config/app_config.dart';

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
        // 로케일 변경 시 맵 제공자 서비스에 알림 (한국만 네이버맵 허용)
        // localeProvider.locale이 null(시스템 기본)이면 시스템 언어로 해석
        WidgetsBinding.instance.addPostFrameCallback((_) {
          String resolvedCode;
          if (localeProvider.locale != null) {
            resolvedCode = localeProvider.locale!.languageCode;
          } else {
            final systemLocale =
                WidgetsBinding.instance.platformDispatcher.locale;
            const supported = ['ko', 'en', 'ja', 'zh'];
            resolvedCode =
                supported.contains(systemLocale.languageCode)
                    ? systemLocale.languageCode
                    : 'en';
          }
          context.read<MapProviderService>().initForLocale(resolvedCode);
        });
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
          // BETA 워터마크 오버레이
          builder: (context, child) {
            if (!AppConfig.isBetaVersion || child == null) return child!;
            return Stack(
              children: [
                child,
                // 바텀 네비 바 위 세미투명 BETA 스트립
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 56, // 네비바 높이
                  child: IgnorePointer(
                    child: Container(
                      height: 20,
                      color: const Color(0xFFFF6B35).withAlpha(80),
                      child: Center(
                        child: Text(
                          'BETA  •  BETA  •  BETA  •  BETA  •  BETA  •  BETA  •  BETA  •  BETA',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withAlpha(200),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
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
    const platform = MethodChannel('com.bnt0514.ringinout/audio');
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
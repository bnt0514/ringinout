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
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/force_update_service.dart';
import 'package:ringinout/widgets/force_update_dialog.dart';

/// 강제 업데이트 체크 — 로그인 직후 호출
Future<void> _checkForceUpdate(BuildContext context) async {
  final needs = await ForceUpdateService.needsUpdate();
  if (needs && context.mounted) {
    await ForceUpdateDialog.show(context);
  }
}

class RinginoutApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Map<String, dynamic>? pendingLaunchAlarm;
  static String? _lastAppliedOwnerUid;

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
          final systemLocale =
              WidgetsBinding.instance.platformDispatcher.locale;
          if (localeProvider.locale != null) {
            resolvedCode = localeProvider.locale!.languageCode;
          } else {
            const supported = ['ko', 'en', 'ja', 'zh', 'de', 'fr', 'es'];
            resolvedCode =
                supported.contains(systemLocale.languageCode)
                    ? systemLocale.languageCode
                    : 'en';
          }
          context.read<MapProviderService>().initForLocale(
            resolvedCode,
            countryCode: systemLocale.countryCode,
          );
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_lastAppliedOwnerUid != null ||
                      HiveHelper.hasStoredActiveOwnerUid) {
                    _lastAppliedOwnerUid = null;
                    HiveHelper.setActiveOwnerUid(null).then((_) async {
                      await SmartLocationService.cancelAllSnoozes();
                      await SmartLocationService.updatePlaces();
                      await SmartLocationService.stopMonitoring();
                    });
                  }
                });
                return const LoginPage();
              }

              return _AuthenticatedHome(
                userUid: user.uid,
                onReady: (readyContext) {
                  _handlePendingAlarm(readyContext);
                  readyContext.read<BillingService>().fetchStatus(
                    forceRefresh: true,
                  );
                  _checkForceUpdate(readyContext);
                },
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
            Locale('de', 'DE'),
            Locale('fr', 'FR'),
            Locale('es', 'ES'),
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

class _AuthenticatedHome extends StatefulWidget {
  final String userUid;
  final ValueChanged<BuildContext> onReady;

  const _AuthenticatedHome({required this.userUid, required this.onReady});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  Future<void>? _ownerFuture;
  String? _ownerFutureUid;
  String? _notifiedReadyUid;

  @override
  void initState() {
    super.initState();
    _ownerFuture = _ensureOwnerApplied();
    _ownerFutureUid = widget.userUid;
  }

  @override
  void didUpdateWidget(covariant _AuthenticatedHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ownerFutureUid != widget.userUid) {
      _ownerFuture = _ensureOwnerApplied();
      _ownerFutureUid = widget.userUid;
      _notifiedReadyUid = null;
    }
  }

  Future<void> _ensureOwnerApplied() async {
    final previousOwnerUid =
        RinginoutApp._lastAppliedOwnerUid ?? HiveHelper.storedActiveOwnerUid;

    if (previousOwnerUid != null && previousOwnerUid != widget.userUid) {
      await SmartLocationService.cancelAllSnoozes();
      await SmartLocationService.stopMonitoring();
    }

    RinginoutApp._lastAppliedOwnerUid = widget.userUid;
    await HiveHelper.setActiveOwnerUid(widget.userUid);
    await SmartLocationService.updatePlaces();
    await SmartLocationService.startMonitoring();
  }

  void _notifyReadyOnce() {
    if (_notifiedReadyUid == widget.userUid) return;
    _notifiedReadyUid = widget.userUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ownerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        _notifyReadyOnce();
        return const PermissionGate(
          child: TermsGate(child: MainNavigationPage()),
        );
      },
    );
  }
}

//앱의 기본 설정(테마, 로케일 등)//
//라우팅 설정
///보류 중인 알람 처리
//알람 소리 제어

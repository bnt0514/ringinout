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
import 'package:ringinout/services/auth_service.dart';
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
                    Future<void>(() async {
                      await SmartLocationService.cancelAllSnoozes();
                      await SmartLocationService.stopMonitoring();
                      await HiveHelper.setActiveOwnerUid(null);
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
  Future<AuthSessionInfo?>? _ownerFuture;
  String? _ownerFutureUid;
  String? _notifiedReadyOwner;

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
      _notifiedReadyOwner = null;
    }
  }

  Future<AuthSessionInfo?> _ensureOwnerApplied({
    bool forceDeviceTransfer = false,
  }) async {
    final authService = context.read<AuthService>();
    final session = await authService.ensureServerSession(
      forceRefresh: true,
      forceDeviceTransfer: forceDeviceTransfer,
    );
    if (session == null) return null;
    if (session.deviceTransferRequired && !forceDeviceTransfer) {
      return session;
    }

    await _applyCanonicalOwner(session.canonicalAccountId);
    return session;
  }

  Future<void> _applyCanonicalOwner(String canonicalOwnerUid) async {
    final previousOwnerUid =
        RinginoutApp._lastAppliedOwnerUid ?? HiveHelper.storedActiveOwnerUid;
    final needsReset = HiveHelper.needsCanonicalOwnerReset(canonicalOwnerUid);

    if ((previousOwnerUid != null && previousOwnerUid != canonicalOwnerUid) ||
        needsReset) {
      await SmartLocationService.cancelAllSnoozes();
      await SmartLocationService.stopMonitoring();
    }

    RinginoutApp._lastAppliedOwnerUid = canonicalOwnerUid;
    await HiveHelper.setActiveOwnerUid(canonicalOwnerUid);
    if (needsReset) {
      await HiveHelper.resetAccountScopedLocalDataForCanonicalOwner(
        canonicalOwnerUid,
      );
    }
    await SmartLocationService.updatePlaces();
    await SmartLocationService.startMonitoring();
  }

  void _acceptDeviceTransfer() {
    setState(() {
      _ownerFuture = _ensureOwnerApplied(forceDeviceTransfer: true);
      _notifiedReadyOwner = null;
    });
  }

  void _notifyReadyOnce(String ownerUid) {
    if (_notifiedReadyOwner == ownerUid) return;
    _notifiedReadyOwner = ownerUid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthSessionInfo?>(
      future: _ownerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _AccountSessionErrorGate(
            onRetry: () {
              setState(() {
                _ownerFuture = _ensureOwnerApplied();
                _notifiedReadyOwner = null;
              });
            },
            onSignOut: () async {
              await context.read<AuthService>().signOut();
            },
          );
        }

        final session = snapshot.data;
        if (session != null && session.deviceTransferRequired) {
          return _DeviceTransferGate(
            previousDeviceLabel: session.previousDeviceLabel,
            onConfirm: _acceptDeviceTransfer,
          );
        }

        final ownerUid =
            session?.canonicalAccountId ?? HiveHelper.storedActiveOwnerUid;
        if (ownerUid != null && ownerUid.isNotEmpty) {
          _notifyReadyOnce(ownerUid);
        }
        return const PermissionGate(
          child: TermsGate(child: MainNavigationPage()),
        );
      },
    );
  }
}

class _DeviceTransferGate extends StatelessWidget {
  const _DeviceTransferGate({
    required this.previousDeviceLabel,
    required this.onConfirm,
  });

  final String? previousDeviceLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final label =
        previousDeviceLabel?.isNotEmpty == true
            ? previousDeviceLabel!
            : 'another device';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.phonelink_lock, size: 56),
                const SizedBox(height: 20),
                const Text(
                  'Use This Device?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'This account is already active on $label. Continuing here will stop app access and alarm monitoring on the previous device when it next connects.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onConfirm,
                    child: const Text('Move to This Device'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSessionErrorGate extends StatelessWidget {
  const _AccountSessionErrorGate({
    required this.onRetry,
    required this.onSignOut,
  });

  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 52),
                const SizedBox(height: 18),
                const Text(
                  'Account Check Failed',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ringinout could not confirm the active account. Please try again with a stable connection.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try Again'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onSignOut, child: const Text('Sign Out')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//앱의 기본 설정(테마, 로케일 등)//
//라우팅 설정
///보류 중인 알람 처리
//알람 소리 제어

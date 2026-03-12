import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/terms_agreement_page.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/permissions.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _termsVersion = 'v2.0_beta_2026-02-06';
  bool _isLoading = false;

  // 개발자 테스트 모드
  int _devTapCount = 0;
  bool _showTestLogin = false;

  Future<void> _signInWithGoogle(AuthService authService) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);

    try {
      final user = await authService.signInWithGoogle();
      if (!mounted || user == null) return;
      await _proceedToHome();
    } catch (e) {
      if (!mounted) return;
      _showError(l10n.get('login_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _proceedToHome() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('no-user');

      // Step 1: 약관 체크 (네트워크 실패 시 스킵하고 진행)
      try {
        final termsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('agreements')
            .doc('terms');

        final termsSnap = await termsRef.get().timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('terms-timeout'),
        );
        final savedVersion = termsSnap.data()?['version'] as String?;
        final needsAgreement =
            !termsSnap.exists || savedVersion != _termsVersion;

        if (needsAgreement) {
          if (!mounted) return;
          final authService = Provider.of<AuthService>(context, listen: false);
          final agreed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder:
                  (_) => TermsAgreementPage(requiredVersion: _termsVersion),
            ),
          );

          if (agreed != true) {
            await authService.signOut();
            if (!mounted) return;
            SystemNavigator.pop();
            return;
          }
        }
      } catch (e) {
        // 약관 체크 실패 시 로그만 남기고 계속 진행
        print('⚠️ 약관 체크 실패 (무시하고 진행): $e');
      }

      // Step 2: 권한 체크
      var granted = await PermissionManager.hasAllRequiredPermissions();
      if (!granted) {
        if (!mounted) return;
        await PermissionManager.requestAllPermissions();
        granted = await PermissionManager.hasAllRequiredPermissions();
      }

      if (!granted) {
        if (!mounted) return;
        _showError(l10n.get('grant_all_permissions'));
        return;
      }

      // Step 3: 홈으로 이동
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      print('❌ _proceedToHome 오류: $e');
      _showError('${l10n.get('error')}: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  // 로고 10번 탭 핸들러
  void _handleLogoTap() {
    setState(() {
      _devTapCount++;
      if (_devTapCount >= 10) {
        _showTestLogin = true;
        _devTapCount = 0;
      }
    });
  }

  // 테스트 계정 로그인 (Remote Config 기반 - Functions 불필요)
  Color _planColor(String plan) {
    switch (plan) {
      case 'basic':
        return Colors.blue;
      case 'premium':
        return Colors.purple;
      case 'special':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // TODO: 배포 전 제거
  Future<void> _signInWithTestAccount(String plan) async {
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      final uid = credential.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'subscriptionStatus': 'active',
        'subscriptionPlan': plan,
        'subscriptionEndDate': null,
        'testAccount': true,
      }, SetOptions(merge: true));

      debugPrint('✅ 테스트 계정 로그인: $plan, uid=$uid');
      if (!mounted) return;
      await _proceedToHome();
    } catch (e) {
      if (!mounted) return;
      _showError('테스트 로그인 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) SystemNavigator.pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // 로고 (10번 탭 시 테스트 로그인 활성화)
                  GestureDetector(
                    onTap: _handleLogoTap,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Transform.scale(
                          scale: 2.4,
                          child: Image.asset(
                            'assets/images/RingInOutLogo.png',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            semanticLabel: 'Ringinout 로고',
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 앱 이름
                  const Text(
                    'Ringinout',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 앱 핵심 기능 소개
                  Text(
                    l10n.get('login_app_description'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 개발자 테스트 로그인 폼
                  if (_showTestLogin) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bug_report,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '개발자 테스트 모드',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warning,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed:
                                    () =>
                                        setState(() => _showTestLogin = false),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            Row(
                              children: [
                                for (final plan in [
                                  'free',
                                  'basic',
                                  'premium',
                                  'special',
                                ])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      child: ElevatedButton(
                                        onPressed:
                                            () => _signInWithTestAccount(plan),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _planColor(plan),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        child: Text(plan),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 데이터 보안 안내
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.shimmer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.get('login_data_security_title'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.get('login_data_security_content'),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 앱 삭제 시 데이터 삭제 안내
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.get('login_data_deletion_warning'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Google 로그인 또는 Start 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : user == null
                              ? () => _signInWithGoogle(authService)
                              : _proceedToHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.card,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                          side: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : user == null
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.google.com/favicon.ico',
                                    width: 24,
                                    height: 24,
                                    errorBuilder:
                                        (_, __, ___) => const Icon(
                                          Icons.g_mobiledata,
                                          size: 24,
                                        ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.get('login_continue_with_google'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                              : const Text(
                                '시작하기',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // 개인정보처리방침 링크
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/privacy_policy');
                    },
                    child: Text(
                      l10n.get('privacy_policy'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

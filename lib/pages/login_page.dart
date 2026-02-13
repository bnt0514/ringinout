import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';

import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold((
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 로고 자리 (앱 아이콘 모양으로 표시)
              SizedBox(
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

              const Spacer(flex: 1),

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

              const Spacer(flex: 1),

              // Google 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _isInitialized && !_isLoading
                          ? _handleGoogleSignIn
                          : null,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google 로고
                              Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 24,
                                height: 24,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
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

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn(BuildContext context, AuthService authService) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = await authService.signInWithGoogle();

      if (user != null && mounted) {
        // 메인 화면으로 이동 (뒤로가기 불가)
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showError('로그인 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}
              // Google 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      !_isLoading
                          ? () => _handleGoogleSignIn(context, authService)
                          : null,
                  style: ElevatedButton.styleFrom(
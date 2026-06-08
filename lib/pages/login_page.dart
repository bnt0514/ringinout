import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/pages/terms_agreement_page.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/services/smart_location_service.dart';

enum _MagicLinkFormState { idle, sending, sent, error }

enum _SignInProvider { google, kakao, naver, line, facebook, email }

class _SignInMethod {
  const _SignInMethod({
    required this.provider,
    required this.labelKey,
    required this.icon,
    this.badgeText,
    this.badgeColor,
  });

  final _SignInProvider provider;
  final String labelKey;
  final IconData icon;
  final String? badgeText;
  final Color? badgeColor;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _termsVersion = 'v2.1_beta_2026-06-08';
  static const MethodChannel _appLifecycleChannel = MethodChannel(
    'com.bnt0514.ringinout/app_lifecycle',
  );

  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;
  _MagicLinkFormState _magicLinkState = _MagicLinkFormState.idle;
  String? _magicLinkError;

  List<_SignInMethod> _methodsForLocale(Locale locale) {
    final country = _countryCodeForSignInOptions(locale);

    if (country == 'KR') {
      return const [
        _SignInMethod(
          provider: _SignInProvider.google,
          labelKey: 'login_continue_with_google',
          icon: Icons.g_mobiledata,
        ),
        _SignInMethod(
          provider: _SignInProvider.kakao,
          labelKey: 'login_continue_with_kakao',
          icon: Icons.chat_bubble_outline,
          badgeText: 'K',
          badgeColor: Color(0xFFFEE500),
        ),
        _SignInMethod(
          provider: _SignInProvider.naver,
          labelKey: 'login_continue_with_naver',
          icon: Icons.account_circle_outlined,
          badgeText: 'N',
          badgeColor: Color(0xFF03C75A),
        ),
        _SignInMethod(
          provider: _SignInProvider.facebook,
          labelKey: 'login_continue_with_facebook',
          icon: Icons.facebook,
          badgeText: 'f',
          badgeColor: Color(0xFF1877F2),
        ),
        _SignInMethod(
          provider: _SignInProvider.email,
          labelKey: 'login_continue_with_email',
          icon: Icons.email_outlined,
        ),
      ];
    }

    if (country == 'JP') {
      return const [
        _SignInMethod(
          provider: _SignInProvider.google,
          labelKey: 'login_continue_with_google',
          icon: Icons.g_mobiledata,
        ),
        _SignInMethod(
          provider: _SignInProvider.line,
          labelKey: 'login_continue_with_line',
          icon: Icons.chat_outlined,
          badgeText: 'L',
          badgeColor: Color(0xFF06C755),
        ),
        _SignInMethod(
          provider: _SignInProvider.facebook,
          labelKey: 'login_continue_with_facebook',
          icon: Icons.facebook,
          badgeText: 'f',
          badgeColor: Color(0xFF1877F2),
        ),
        _SignInMethod(
          provider: _SignInProvider.email,
          labelKey: 'login_continue_with_email',
          icon: Icons.email_outlined,
        ),
      ];
    }

    if (country == 'CN') {
      return const [
        _SignInMethod(
          provider: _SignInProvider.email,
          labelKey: 'login_continue_with_email',
          icon: Icons.email_outlined,
        ),
      ];
    }

    return const [
      _SignInMethod(
        provider: _SignInProvider.google,
        labelKey: 'login_continue_with_google',
        icon: Icons.g_mobiledata,
      ),
      _SignInMethod(
        provider: _SignInProvider.facebook,
        labelKey: 'login_continue_with_facebook',
        icon: Icons.facebook,
        badgeText: 'f',
        badgeColor: Color(0xFF1877F2),
      ),
      _SignInMethod(
        provider: _SignInProvider.email,
        labelKey: 'login_continue_with_email',
        icon: Icons.email_outlined,
      ),
    ];
  }

  String? _countryCodeForSignInOptions(Locale appLocale) {
    final systemCountry =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (systemCountry != null && systemCountry.isNotEmpty) {
      return systemCountry.toUpperCase();
    }
    return appLocale.countryCode?.toUpperCase();
  }

  Future<User?> _runProviderSignIn(
    AuthService authService,
    _SignInProvider provider,
  ) {
    switch (provider) {
      case _SignInProvider.google:
        return authService.signInWithGoogle();
      case _SignInProvider.kakao:
        return authService.signInWithKakao();
      case _SignInProvider.naver:
        return authService.signInWithNaver();
      case _SignInProvider.line:
        return authService.signInWithLine();
      case _SignInProvider.facebook:
        return authService.signInWithFacebook();
      case _SignInProvider.email:
        throw UnsupportedError('Use _sendMagicLink for email sign-in.');
    }
  }

  Future<void> _signInWithProvider(
    AuthService authService,
    _SignInProvider provider,
  ) async {
    if (_isLoading || provider == _SignInProvider.email) return;
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);

    try {
      final user = await _runProviderSignIn(authService, provider);
      if (!mounted || user == null) return;
      await _finishAuthenticatedFlow();
    } catch (e) {
      if (!mounted) return;
      _showError(l10n.get('login_failed'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMagicLink(AuthService authService) async {
    if (_isLoading || _magicLinkState == _MagicLinkFormState.sending) return;

    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() {
        _magicLinkState = _MagicLinkFormState.error;
        _magicLinkError = l10n.get('login_email_invalid');
      });
      return;
    }

    setState(() {
      _magicLinkState = _MagicLinkFormState.sending;
      _magicLinkError = null;
    });

    try {
      await authService.sendEmailSignInLink(email);
      if (!mounted) return;
      setState(() => _magicLinkState = _MagicLinkFormState.sent);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _magicLinkState = _MagicLinkFormState.error;
        _magicLinkError = l10n.get('login_magic_link_error');
      });
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  Future<void> _proceedToHome() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await _finishAuthenticatedFlow();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _finishAuthenticatedFlow() async {
    final l10n = AppLocalizations.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('no-user');
      final authService = Provider.of<AuthService>(context, listen: false);
      final session = await authService.ensureServerSession(forceRefresh: true);
      final accountId = session?.canonicalAccountId ?? user.uid;

      // Step 1: terms check. If the network check fails, keep sign-in moving.
      try {
        final termsRef = FirebaseFirestore.instance
            .collection('accounts')
            .doc(accountId)
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
          final agreed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder:
                  (_) => TermsAgreementPage(requiredVersion: _termsVersion),
            ),
          );

          if (agreed != true) {
            await SmartLocationService.cancelAllSnoozes();
            await SmartLocationService.stopMonitoring();
            await HiveHelper.setActiveOwnerUid(null);
            await authService.signOut();
            if (!mounted) return;
            await _moveAppToBackground();
            return;
          }
        }
      } catch (e) {
        debugPrint('Terms check failed; continuing sign-in: $e');
      }

      // Step 2: permission check.
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

      // Step 3: move to the app.
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (!mounted) return;
      debugPrint('_finishAuthenticatedFlow error: $e');
      _showError('${l10n.get('error')}: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  Future<void> _moveAppToBackground() async {
    try {
      await _appLifecycleChannel.invokeMethod('moveTaskToBack');
    } catch (e) {
      debugPrint('Failed to move app to background: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _moveAppToBackground();
        }
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
                          semanticLabel: 'Ringinout Logo',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Ringinout',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  _buildSecurityNotice(l10n),
                  const SizedBox(height: 16),
                  _buildActiveDeviceNotice(l10n),
                  const SizedBox(height: 24),
                  if (user == null)
                    _buildSignInMethods(context, authService, l10n)
                  else
                    _buildStartButton(l10n),
                  const SizedBox(height: 32),
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

  Widget _buildSecurityNotice(AppLocalizations l10n) {
    return Container(
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
              Icon(Icons.security, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.get('login_data_security_title'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
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
    );
  }

  Widget _buildActiveDeviceNotice(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.devices_other, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.get('login_active_device_notice_body'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignInMethods(
    BuildContext context,
    AuthService authService,
    AppLocalizations l10n,
  ) {
    final methods = _methodsForLocale(Localizations.localeOf(context));
    final providerMethods =
        methods.where((m) => m.provider != _SignInProvider.email).toList();
    final hasEmail = methods.any((m) => m.provider == _SignInProvider.email);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.get('login_sign_in_methods_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          l10n.get('login_country_methods_hint'),
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        for (final method in providerMethods) ...[
          _buildProviderButton(authService, l10n, method),
          const SizedBox(height: 10),
        ],
        if (hasEmail) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    l10n.get('login_or'),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          _buildMagicLinkForm(authService, l10n),
        ],
      ],
    );
  }

  Widget _buildProviderButton(
    AuthService authService,
    AppLocalizations l10n,
    _SignInMethod method,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed:
            _isLoading
                ? null
                : () => _signInWithProvider(authService, method.provider),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          backgroundColor: AppColors.card,
        ),
        child:
            _isLoading
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProviderMark(method),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.get(method.labelKey),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildProviderMark(_SignInMethod method) {
    if (method.provider == _SignInProvider.google) {
      return Image.network(
        'https://www.google.com/favicon.ico',
        width: 22,
        height: 22,
        errorBuilder: (_, __, ___) => Icon(method.icon, size: 24),
      );
    }

    if (method.badgeText != null) {
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: method.badgeColor,
          shape: BoxShape.circle,
        ),
        child: Text(
          method.badgeText!,
          style: TextStyle(
            color:
                method.provider == _SignInProvider.naver ||
                        method.provider == _SignInProvider.facebook ||
                        method.provider == _SignInProvider.line
                    ? Colors.white
                    : Colors.black,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Icon(method.icon, size: 24);
  }

  Widget _buildMagicLinkForm(AuthService authService, AppLocalizations l10n) {
    final isSending = _magicLinkState == _MagicLinkFormState.sending;
    final isSent = _magicLinkState == _MagicLinkFormState.sent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.email_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.get('login_continue_with_email'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              enabled: !isSending,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.get('login_email_label'),
                hintText: l10n.get('login_email_hint'),
                border: const OutlineInputBorder(),
                isDense: true,
                errorText:
                    _magicLinkState == _MagicLinkFormState.error
                        ? _magicLinkError
                        : null,
              ),
              onChanged: (_) {
                if (_magicLinkState != _MagicLinkFormState.idle) {
                  setState(() {
                    _magicLinkState = _MagicLinkFormState.idle;
                    _magicLinkError = null;
                  });
                }
              },
              onSubmitted: (_) => _sendMagicLink(authService),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: isSending ? null : () => _sendMagicLink(authService),
                icon:
                    isSending
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.outgoing_mail),
                label: Text(
                  isSent
                      ? l10n.get('login_magic_link_sent_title')
                      : l10n.get('login_send_magic_link'),
                ),
              ),
            ),
            if (isSent) ...[
              const SizedBox(height: 10),
              Text(
                l10n.get('login_magic_link_sent_body'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _proceedToHome,
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
                : Text(
                  l10n.get('get_started'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
      ),
    );
  }
}

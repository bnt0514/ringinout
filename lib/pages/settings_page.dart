import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/holiday_service.dart';
import 'package:ringinout/services/locale_provider.dart';
import 'package:ringinout/services/smart_location_service.dart';
import 'package:ringinout/utils/report_rate_limiter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showAccountOptions() {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSheetHandle(),
                      const SizedBox(height: 12),
                      _buildAccountHeader(l10n, authService.currentUser),
                      const SizedBox(height: 8),
                      const Divider(height: 24),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: Text(l10n.get('logout')),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleGoogleSignOut();
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          l10n.get('delete_account'),
                          style: const TextStyle(color: AppColors.danger),
                        ),
                        subtitle: Text(
                          l10n.get('delete_account_subtitle'),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleDeleteAccount();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildSheetHandle() {
    return Align(
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildAccountHeader(AppLocalizations l10n, User? user) {
    final authService = Provider.of<AuthService>(context, listen: false);
    return FutureBuilder<CurrentAuthIdentity>(
      future: authService.currentAuthIdentity(),
      builder: (context, snapshot) {
        final displayName = _accountDisplayName(
          l10n,
          user,
          identity: snapshot.data,
        );

        return Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              foregroundColor: AppColors.primary,
              child: const Icon(Icons.account_circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.get('account_signed_in_as'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccountSubtitle(AppLocalizations l10n, AuthService authService) {
    return FutureBuilder<CurrentAuthIdentity>(
      future: authService.currentAuthIdentity(),
      builder:
          (context, snapshot) => Text(
            _accountDisplayName(
              l10n,
              authService.currentUser,
              identity: snapshot.data,
            ),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }

  String _accountDisplayName(
    AppLocalizations l10n,
    User? user, {
    CurrentAuthIdentity? identity,
  }) {
    if (user == null) return l10n.get('account_not_logged_in');
    final providerId = identity?.providerId;
    final label =
        providerId != null && providerId.trim().isNotEmpty
            ? _providerDisplayLabel(providerId)
            : null;
    final email =
        identity?.email?.trim().isNotEmpty == true
            ? identity!.email!.trim()
            : user.email?.trim();
    if (email != null && email.isNotEmpty) {
      return label == null ? email : '$label - $email';
    }
    final displayName =
        identity?.displayName?.trim().isNotEmpty == true
            ? identity!.displayName!.trim()
            : user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return label == null ? displayName : '$label - $displayName';
    }
    if (providerId != null && providerId.trim().isNotEmpty) {
      return _signedInProviderText(l10n, providerId);
    }
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return isKorean ? '로그인됨' : 'Signed in';
  }

  String _signedInProviderText(AppLocalizations l10n, String providerId) {
    final label = _providerDisplayLabel(providerId);
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return isKorean ? '$label 계정으로 로그인됨' : 'Signed in with $label';
  }

  String _providerDisplayLabel(String providerId) {
    final normalized = providerId.trim();
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    if (_providerAliases(AuthService.kakaoProviderId).contains(normalized)) {
      return isKorean ? '카카오톡' : 'KakaoTalk';
    }
    if (_providerAliases(AuthService.naverProviderId).contains(normalized)) {
      return 'Naver';
    }
    if (_providerAliases(AuthService.lineProviderId).contains(normalized)) {
      return 'LINE';
    }
    if (_providerAliases(AuthService.yahooProviderId).contains(normalized)) {
      return 'Yahoo Japan';
    }
    switch (normalized) {
      case 'google.com':
        return 'Google';
      case 'facebook.com':
        return 'Facebook';
      case 'password':
      case 'email':
        return isKorean ? '이메일' : 'Email';
      case 'custom':
        return isKorean ? '외부 로그인' : 'External provider';
      default:
        return normalized;
    }
  }

  Set<String> _providerAliases(String providerId) {
    switch (providerId) {
      case AuthService.kakaoProviderId:
        return _aliasSet([AuthService.kakaoProviderId, 'kakao', 'oidc.kakao']);
      case AuthService.naverProviderId:
        return _aliasSet([AuthService.naverProviderId, 'naver', 'oidc.naver']);
      case AuthService.lineProviderId:
        return _aliasSet([AuthService.lineProviderId, 'line', 'oidc.line']);
      case AuthService.yahooProviderId:
        return _aliasSet([AuthService.yahooProviderId, 'yahoo', 'oidc.yahoo']);
      case 'password':
        return {'password', 'email'};
      default:
        return {providerId};
    }
  }

  Set<String> _aliasSet(List<String> values) => values.toSet();

  Future<void> _handleGoogleSignOut() async {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final billingService = Provider.of<BillingService>(context, listen: false);

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('logout')),
            content: Text(l10n.get('logout_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.get('logout')),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await SmartLocationService.cancelAllSnoozes();
      await SmartLocationService.stopMonitoring();
      await HiveHelper.setActiveOwnerUid(null);
      await authService.signOut();
      billingService.clearCache();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final billingService = Provider.of<BillingService>(context, listen: false);

    final confirm1 = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('delete_account')),
            content: _buildDeleteWarningContent(
              l10n,
              l10n.get('delete_account_warning'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(l10n.get('delete_account_confirm')),
              ),
            ],
          ),
    );
    if (confirm1 != true) return;
    if (!mounted) return;

    final confirm2 = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('delete_account_final_title')),
            content: _buildDeleteWarningContent(
              l10n,
              l10n.get('delete_account_final_warning'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.get('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                child: Text(
                  l10n.get('delete_account_final_confirm'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
    if (confirm2 != true) return;

    try {
      await SmartLocationService.cancelAllSnoozes();
      await SmartLocationService.stopMonitoring();
      await HiveHelper.setActiveOwnerUid(null);
      await authService.deleteAccount();
      billingService.clearCache();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.get('delete_account_failed'))),
      );
    }
  }

  Widget _buildDeleteWarningContent(AppLocalizations l10n, String body) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.devices_other,
                    color: AppColors.danger,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.get('account_delete_device_warning'),
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('language_select')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  AppLanguage.values.map((language) {
                    return ListTile(
                      title: Text(language.displayName),
                      trailing:
                          localeProvider.currentLanguage == language
                              ? const Icon(
                                Icons.check,
                                color: AppColors.primary,
                              )
                              : null,
                      onTap: () async {
                        final nav = Navigator.of(context);
                        await localeProvider.setLanguage(language);
                        if (!mounted) return;
                        nav.pop();
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showHolidayCountryDialog() {
    final l10n = AppLocalizations.of(context);
    final currentSetting = HiveHelper.getHolidayCountry();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.get('holiday_country')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _holidayCountryTile(
                  dialogContext,
                  code: 'auto',
                  displayName: l10n.get('holiday_country_auto'),
                  flag: '🌐',
                  isSelected: currentSetting == 'auto',
                ),
                const Divider(),
                ...HolidayService.supportedCountries.map((code) {
                  final flag = HolidayService.countryFlags[code] ?? '';
                  final name = l10n.get('country_$code');
                  return _holidayCountryTile(
                    dialogContext,
                    code: code,
                    displayName: name,
                    flag: flag,
                    isSelected: currentSetting == code,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _holidayCountryTile(
    BuildContext dialogContext, {
    required String code,
    required String displayName,
    required String flag,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(displayName),
      trailing:
          isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      onTap: () async {
        final nav = Navigator.of(dialogContext);
        await HiveHelper.setHolidayCountry(code);
        HolidayService.instance.clearCache();
        if (!mounted) return;
        nav.pop();
        setState(() {});
      },
    );
  }

  String _getHolidayCountrySubtitle(AppLocalizations l10n) {
    final setting = HiveHelper.getHolidayCountry();
    if (setting == 'auto') {
      return l10n.get('holiday_country_auto');
    }
    final flag = HolidayService.countryFlags[setting] ?? '';
    final name = l10n.get('country_$setting');
    return '$flag $name';
  }

  void _showFeedbackDialog() {
    final l10n = AppLocalizations.of(context);

    final limitReason = ReportRateLimiter.canSend('feedback');
    if (limitReason != null) {
      String msg;
      if (limitReason == 'daily_limit') {
        msg =
            '오늘 최대 ${ReportRateLimiter.maxPerDay}회까지 전송할 수 있습니다.\n'
            '서버 안정성 보호를 위한 조치입니다.';
      } else {
        final parts = limitReason.split(':');
        msg =
            '${parts[1]}분 ${parts[2]}초 후에 다시 전송할 수 있습니다.\n'
            '서버 안정성 보호를 위해 30분 간격으로 제한합니다.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final remaining = ReportRateLimiter.remainingToday('feedback');
    final controller = TextEditingController();
    const int maxContentBytes = 12 * 1024;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentBytes = controller.text.length * 2;
            final sizeKb = (currentBytes / 1024).toStringAsFixed(1);
            final maxKb = (maxContentBytes / 1024).toStringAsFixed(0);
            final isOverLimit = currentBytes > maxContentBytes;

            return AlertDialog(
              title: Text(l10n.get('feedback_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.getWithArgs('report_remaining_count', {
                      'remaining': '$remaining',
                      'max': '${ReportRateLimiter.maxPerDay}',
                    }),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      hintText: l10n.get('feedback_hint'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${sizeKb}KB / ${maxKb}KB',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverLimit ? Colors.red : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.get('cancel')),
                ),
                ElevatedButton(
                  onPressed:
                      (isOverLimit || controller.text.trim().isEmpty)
                          ? null
                          : () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
                            await ReportRateLimiter.recordSent('feedback');
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l10n.get('feedback_sent')),
                                ),
                              );
                            }
                          },
                  child: Text(l10n.get('send')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAppInfoDialog() async {
    final l10n = AppLocalizations.of(context);
    final info = await PackageInfo.fromPlatform();
    final version = '${info.version}+${info.buildNumber}';
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('app_info')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ringinout',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('${l10n.get('version')}: $version'),
                const SizedBox(height: 4),
                Text(l10n.get('location_based_alarm')),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPrivacyPolicy();
                  },
                  child: Text(l10n.get('privacy_policy')),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.get('close')),
              ),
            ],
          ),
    );
  }

  void _showPrivacyPolicy() {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('privacy_policy_title')),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.get('privacy_last_updated'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _privacySection(
                    l10n.get('privacy_section_1_title'),
                    l10n.get('privacy_section_1_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_2_title'),
                    l10n.get('privacy_section_2_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_3_title'),
                    l10n.get('privacy_section_3_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_4_title'),
                    l10n.get('privacy_section_4_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_6_title'),
                    l10n.get('privacy_section_6_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_7_title'),
                    l10n.get('privacy_section_7_content'),
                  ),
                  _privacySection(
                    l10n.get('privacy_section_5_title'),
                    l10n.get('privacy_section_5_content'),
                    isLast: true,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.get('close')),
              ),
            ],
          ),
    );
  }

  Widget _privacySection(String title, String content, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('settings'))),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.get('language')),
            subtitle: Text(localeProvider.currentLanguage.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(l10n.get('holiday_country')),
            subtitle: Text(_getHolidayCountrySubtitle(l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showHolidayCountryDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(l10n.get('account')),
            subtitle: _buildAccountSubtitle(l10n, authService),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAccountOptions,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: Text(l10n.get('feedback')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFeedbackDialog,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.get('app_info')),
            subtitle: Text(
              '${l10n.get('version')}, ${l10n.get('privacy_policy')}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAppInfoDialog,
          ),
          const Divider(),
        ],
      ),
    );
  }
}

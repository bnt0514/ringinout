import 'package:flutter/material.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:ringinout/services/locale_provider.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/billing_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _handleGoogleSignOut() async {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final billingService = Provider.of<BillingService>(context, listen: false);

    // 로그아웃 확인 다이얼로그
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

    if (confirm != true) return;

    try {
      await authService.signOut();
      billingService.clearCache();

      if (!mounted) return;

      // 로그인 화면으로 이동 (뒤로가기 불가)
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      print('로그아웃 실패: $e');
    }
  }

  oid _showLanguageDialog() {
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
                        await localeProvider.setLanguage(language);
                        if (!mounted) return;
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showFeedbackDialog() {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('feedback_title')),
            content: TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: l10n.get('feedback_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.get('cancel')),
              ),
              ElevatedButton(
                onPressed: () {
                  // TODO: 실제 피드백 전송 로직 구현 (이메일 또는 서버)
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.get('feedback_sent'))),
                  );
                },
                child: Text(l10n.get('send')),
              ),
            ],
          ),
    );
  }

  void _showAppInfoDialog() {
    final l10n = AppLocalizations.of(context);
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
                Text('${l10n.get('version')}: 1.0.0'),
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
                  Text(
                    l10n.get('privacy_section_1_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.get('privacy_section_1_content')),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('privacy_section_2_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.get('privacy_section_2_content')),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('privacy_section_3_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.get('privacy_section_3_content')),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('privacy_section_4_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.get('privacy_section_4_content')),
                  const SizedBox(height: 16),
                  Text(
                    l10n.get('privacy_section_5_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.get('privacy_section_5_content')),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.get('settings'))),
      body: ListView(
        children: [
          // 언어 설정
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.get('language')),
            subtitle: Text(localeProvider.currentLanguage.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),
          const Divider(),

          // 계정 설정
          ListTile(
            leading: const Icon(Icons.account_circle),
            title: Text(l10n.get('account')),
            subtitle:
                _currentUser != null
                    ? Text(
                      _currentUser!.displayName ?? _currentUser!.email ?? '',
                    )
                    : null,
            trailing: TextButton(
              onPressed: _handleGoogleSignOut,
              child: Text(l10n.get('logout')),
            ),
          ),
          const Divider(),

          // 건의사항
          ListTile(
            leading: const Icon(Icons.feedback),
            title: Text(l10n.get('feedback')),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showFeedbackDialog,
          ),
          const Divider(),

          // 앱 정보
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

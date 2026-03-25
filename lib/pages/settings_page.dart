import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/holiday_service.dart';
import 'package:ringinout/services/locale_provider.dart';

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
      await authService.signOut();
      billingService.clearCache();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('로그아웃 실패: $e');
    }
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
                // Auto 옵션
                _holidayCountryTile(
                  dialogContext,
                  code: 'auto',
                  displayName: l10n.get('holiday_country_auto'),
                  flag: '🌍',
                  isSelected: currentSetting == 'auto',
                ),
                const Divider(),
                // 지원 국가 목록
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
        await HiveHelper.setHolidayCountry(code);
        HolidayService.instance.clearCache();
        if (!mounted) return;
        Navigator.of(dialogContext).pop();
        setState(() {}); // UI 갱신
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
            subtitle: Text(
              authService.currentUser?.email ??
                  authService.currentUser?.displayName ??
                  'Not logged in',
            ),
            trailing: TextButton(
              onPressed: _handleGoogleSignOut,
              child: Text(l10n.get('logout')),
            ),
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

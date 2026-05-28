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
import 'package:ringinout/utils/report_rate_limiter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _showAccountOptions() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.get('logout')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleGoogleSignOut();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: Text(
                    l10n.get('delete_account'),
                    style: const TextStyle(color: Colors.red),
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
    );
  }

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

  Future<void> _handleDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final authService = Provider.of<AuthService>(context, listen: false);
    final billingService = Provider.of<BillingService>(context, listen: false);

    // 1차 확인
    final confirm1 = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('delete_account')),
            content: Text(l10n.get('delete_account_warning')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.get('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.get('delete_account_confirm')),
              ),
            ],
          ),
    );
    if (confirm1 != true) return;

    // 2차 최종 확인
    final confirm2 = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('delete_account_final_title')),
            content: Text(l10n.get('delete_account_final_warning')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.get('cancel')),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

    // ── 전송 제한 확인 ──
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
            '서버 안정성 보호를 위해 30분 간격으로 제한됩니다.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⏳ $msg')));
      return;
    }

    final remaining = ReportRateLimiter.remainingToday('feedback');
    final controller = TextEditingController();
    const int maxContentBytes = 12 * 1024; // 12KB

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
                    '오늘 남은 전송 횟수: $remaining/${ReportRateLimiter.maxPerDay}회',
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
                            Navigator.pop(context);
                            await ReportRateLimiter.recordSent('feedback');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
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

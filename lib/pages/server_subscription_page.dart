/**
 * ServerSubscriptionPage - 서버 기반 구독 관리 페이지
 * 
 * 기존 subscription_management_page.dart를 대체
 * BillingService에서 실시간으로 플랜을 가져와 표시
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_theme.dart';

import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/pages/gps_page.dart';
import 'package:ringinout/pages/settings_page.dart';
import 'package:ringinout/services/policy_texts.dart';
import 'package:ringinout/config/app_config.dart';

class ServerSubscriptionPage extends StatefulWidget {
  const ServerSubscriptionPage({super.key});

  @override
  State<ServerSubscriptionPage> createState() => _ServerSubscriptionPageState();
}

class _ServerSubscriptionPageState extends State<ServerSubscriptionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 페이지 열릴 때 플랜 새로고침
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BillingService>().fetchStatus(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.get('page_title_gps')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.textPrimary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              tabs: [
                Tab(text: l10n.get('gps_tab')),
                Tab(text: l10n.get('subscription_tab')),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                GpsPage(showAppBar: false),
                _ServerSubscriptionView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerSubscriptionView extends StatelessWidget {
  const _ServerSubscriptionView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Consumer<BillingService>(
      builder: (context, billingService, child) {
        final plan = billingService.currentPlan;
        final expiresAt = billingService.expiresAt;
        final isLoading = billingService.isLoading;

        return RefreshIndicator(
          onRefresh: () => billingService.fetchStatus(forceRefresh: true),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 현재 플랜 카드
              _CurrentPlanCard(
                plan: plan,
                expiresAt: expiresAt,
                isLoading: isLoading,
              ),
              const SizedBox(height: 16),

              // 베타 안내 또는 플랜 목록
              if (AppConfig.isBetaVersion)
                Card(
                  color: AppColors.shimmer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      l10n.get('subscription_beta_notice'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else ...[
                _PlanCard(
                  title: 'Basic',
                  price: '₩2,900 ${l10n.get('subscription_per_month')}',
                  features: [
                    l10n.getWithArgs('subscription_places_n', {'n': '5'}),
                    l10n.getWithArgs('subscription_alarms_n', {'n': '10'}),
                    l10n.get('subscription_no_ads'),
                  ],
                  isCurrentPlan: plan == SubscriptionPlan.basic,
                  l10n: l10n,
                  onTap: () => _showComingSoon(context),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: 'Premium',
                  price: '₩4,900 ${l10n.get('subscription_per_month')}',
                  features: [
                    l10n.get('subscription_places_unlimited'),
                    l10n.get('subscription_alarms_unlimited'),
                    l10n.get('subscription_no_ads'),
                  ],
                  isCurrentPlan:
                      plan == SubscriptionPlan.premium ||
                      plan == SubscriptionPlan.special,
                  recommended: true,
                  l10n: l10n,
                  onTap: () => _showComingSoon(context),
                ),
              ],
              const SizedBox(height: 24),

              // 정책 링크
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed:
                        () => _openPolicy(
                          context,
                          l10n.get('subscription_policy'),
                        ),
                    child: Text(l10n.get('subscription_policy')),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed:
                        () => _openPolicy(
                          context,
                          l10n.get('subscription_refund_policy'),
                        ),
                    child: Text(l10n.get('subscription_refund_policy')),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.get('subscription_coming_soon'))),
    );
  }

  void _openPolicy(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Text(
                title == l10n.get('subscription_policy')
                    ? getSubscriptionPolicyText(
                      isBeta: AppConfig.isBetaVersion,
                      lang: lang,
                    )
                    : getRefundPolicyText(
                      isBeta: AppConfig.isBetaVersion,
                      lang: lang,
                    ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.get('close')),
              ),
            ],
          ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.plan,
    this.expiresAt,
    this.isLoading = false,
  });

  final SubscriptionPlan plan;
  final DateTime? expiresAt;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final planName = _getPlanName(plan);
    final expiryText =
        expiresAt != null
            ? l10n.getWithArgs('subscription_expires', {
              'date':
                  '${expiresAt!.year}.${expiresAt!.month}.${expiresAt!.day}',
            })
            : plan == SubscriptionPlan.free
            ? l10n.get('subscription_free_plan')
            : l10n.get('subscription_unlimited');

    return Card(
      color: AppColors.card,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Text(
                  l10n.get('subscription_current_plan'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              planName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              expiryText,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              _getPlanDescription(plan),
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  String _getPlanName(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.basic:
        return 'Basic';
      case SubscriptionPlan.premium:
        return 'Premium';
      case SubscriptionPlan.special:
        return 'Developer (Special)';
    }
  }

  String _getPlanDescription(SubscriptionPlan plan) {
    // Plan descriptions use the build context's l10n indirectly
    // These are displayed as secondary text, keep English plan names
    switch (plan) {
      case SubscriptionPlan.free:
        return '2 places, 2 alarms';
      case SubscriptionPlan.basic:
        return '5 places, 10 alarms';
      case SubscriptionPlan.premium:
        return 'All features unlimited';
      case SubscriptionPlan.special:
        return 'Developer - all features unlimited';
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.onTap,
    required this.l10n,
    this.isCurrentPlan = false,
    this.recommended = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final VoidCallback onTap;
  final AppLocalizations l10n;
  final bool isCurrentPlan;
  final bool recommended;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: recommended ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: recommended ? AppColors.primary : AppColors.border,
          width: recommended ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isCurrentPlan ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (recommended) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.get('subscription_recommended'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.check, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text(feature, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              if (isCurrentPlan) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.shimmer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.get('subscription_in_use'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      l10n.get('subscription_subscribe'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

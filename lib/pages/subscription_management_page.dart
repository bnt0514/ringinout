import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:ringinout/pages/gps_page.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/policy_texts.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/billing_service.dart';
import 'package:ringinout/services/subscription_service.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({
    super.key,
    this.currentPlanName = 'Free',
    this.currentPlanExpiry,
    this.onCancelPlan,
    this.basicProduct,
    this.premiumProduct,
    this.adRemoveProduct,
  });

  final String currentPlanName;
  final DateTime? currentPlanExpiry;
  final VoidCallback? onCancelPlan;
  final ProductDetails? basicProduct;
  final ProductDetails? premiumProduct;
  final ProductDetails? adRemoveProduct;

  @override
  State<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState extends State<SubscriptionManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).get('subscription_mgmt_title'),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
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
                Tab(
                  text: AppLocalizations.of(
                    context,
                  ).get('subscription_mgmt_title'),
                ),
                const Tab(text: 'GPS'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SubscriptionManagementView(
                  currentPlanName: widget.currentPlanName,
                  currentPlanExpiry: widget.currentPlanExpiry,
                  onCancelPlan: widget.onCancelPlan,
                  basicProduct: widget.basicProduct,
                  premiumProduct: widget.premiumProduct,
                  adRemoveProduct: widget.adRemoveProduct,
                ),
                const GpsPage(showAppBar: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionManagementView extends StatefulWidget {
  const _SubscriptionManagementView({
    required this.currentPlanName,
    required this.currentPlanExpiry,
    required this.onCancelPlan,
    required this.basicProduct,
    required this.premiumProduct,
    required this.adRemoveProduct,
  });

  final String currentPlanName;
  final DateTime? currentPlanExpiry;
  final VoidCallback? onCancelPlan;
  final ProductDetails? basicProduct;
  final ProductDetails? premiumProduct;
  final ProductDetails? adRemoveProduct;

  @override
  State<_SubscriptionManagementView> createState() =>
      _SubscriptionManagementViewState();
}

class _SubscriptionManagementViewState
    extends State<_SubscriptionManagementView> {
  bool _isDevUser = false;

  @override
  void initState() {
    super.initState();
    _checkDevUser();
  }

  /// Firestore admin_config/special_users 기반 개발자 여부 체크
  Future<void> _checkDevUser() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('special_users')
              .get();
      if (doc.exists) {
        final uids = List<String>.from(doc.data()?['uids'] ?? []);
        if (uids.contains(uid) && mounted) {
          setState(() => _isDevUser = true);
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // BillingService에서 현재 플랜 확인 (special = 개발자)
    final billingPlan = context.watch<BillingService>().currentPlan;
    final isDevByPlan = billingPlan == SubscriptionPlan.special;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentPlanCard(
          planName: widget.currentPlanName,
          expiryDate: widget.currentPlanExpiry,
          onCancel: widget.onCancelPlan,
        ),
        const SizedBox(height: 16),
        // 개발자는 베타여도 플랜 표시
        if (AppConfig.isBetaVersion && !_isDevUser && !isDevByPlan)
          Card(
            color: AppColors.shimmer,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                AppLocalizations.of(context).get('beta_no_paid_plans'),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else ...[
          _PlanCard(
            title: 'Basic',
            priceText: _priceText(context, widget.basicProduct),
            benefits: [
              AppLocalizations.of(context).get('places_5'),
              AppLocalizations.of(context).get('active_alarms_10'),
              AppLocalizations.of(context).get('ad_free_included'),
            ],
            onSubscribe:
                () => _showOneTimeSheet(
                  context,
                  'Basic ${AppLocalizations.of(context).get('subscribe_btn')}',
                ),
            onAutoSubscribe:
                () => _showAutoRenewSheet(
                  context,
                  'Basic ${AppLocalizations.of(context).get('auto_subscribe_btn')}',
                ),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Premium',
            priceText: _priceText(context, widget.premiumProduct),
            benefits: [
              AppLocalizations.of(context).get('places_alarms_unlimited'),
              AppLocalizations.of(context).get('ad_free_included'),
            ],
            onSubscribe:
                () => _showOneTimeSheet(
                  context,
                  'Premium ${AppLocalizations.of(context).get('subscribe_btn')}',
                ),
            onAutoSubscribe:
                () => _showAutoRenewSheet(
                  context,
                  'Premium ${AppLocalizations.of(context).get('auto_subscribe_btn')}',
                ),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: AppLocalizations.of(context).get('ad_remove_title'),
            priceText: _priceText(context, widget.adRemoveProduct),
            benefits: [AppLocalizations.of(context).get('in_app_ad_remove')],
            onSubscribe:
                () => _showOneTimeSheet(
                  context,
                  AppLocalizations.of(context).get('ad_remove_title'),
                ),
            onAutoSubscribe:
                () => _showAutoRenewSheet(
                  context,
                  '${AppLocalizations.of(context).get('ad_remove_title')} ${AppLocalizations.of(context).get('auto_subscribe_btn')}',
                ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed:
                  () => _openPolicy(
                    context,
                    AppLocalizations.of(context).get('subscription_policy_btn'),
                  ),
              child: Text(
                AppLocalizations.of(context).get('subscription_policy_btn'),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed:
                  () => _openPolicy(
                    context,
                    AppLocalizations.of(context).get('refund_policy_btn'),
                    isRefund: true,
                  ),
              child: Text(
                AppLocalizations.of(context).get('refund_policy_btn'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _priceText(BuildContext context, ProductDetails? product) {
    if (product == null)
      return AppLocalizations.of(context).get('price_loading');
    return product.price;
  }

  void _openPolicy(
    BuildContext context,
    String title, {
    bool isRefund = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PolicyPage(title: title, isRefund: isRefund),
      ),
    );
  }

  void _showOneTimeSheet(BuildContext context, String title) {
    final l10n = AppLocalizations.of(context);
    final options = [
      _PlanDurationOption(months: 1, label: l10n.get('duration_1month')),
      _PlanDurationOption(
        months: 3,
        label: l10n.get('duration_3months'),
        discountLabel: l10n.get('discount_5'),
      ),
      _PlanDurationOption(
        months: 6,
        label: l10n.get('duration_6months'),
        discountLabel: l10n.get('discount_10'),
      ),
      _PlanDurationOption(
        months: 12,
        label: l10n.get('duration_12months'),
        discountLabel: l10n.get('discount_20'),
      ),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => ListTile(
                    title: Text(option.label),
                    trailing:
                        option.discountLabel != null
                            ? Text(option.discountLabel!)
                            : null,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAutoRenewSheet(BuildContext context, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        bool agreeBilling = false;
        bool agreeTerms = false;

        return StatefulBuilder(
          builder: (context, setState) {
            final canProceed = agreeBilling && agreeTerms;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context).get('auto_renew_msg')),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreeBilling,
                      title: Text(
                        AppLocalizations.of(context).get('agree_auto_pay'),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => agreeBilling = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreeTerms,
                      title: Text(
                        AppLocalizations.of(context).get('agree_policy'),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => agreeTerms = value ?? false),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            canProceed ? () => Navigator.pop(context) : null,
                        child: Text(
                          AppLocalizations.of(
                            context,
                          ).get('start_auto_subscription'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.planName,
    required this.expiryDate,
    required this.onCancel,
  });

  final String planName;
  final DateTime? expiryDate;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final expiryText =
        expiryDate == null
            ? l10n.get('expiry_date_none')
            : l10n.getWithArgs('expiry_date_format', {
              'date': _formatDate(expiryDate!),
            });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.get('current_plan'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(planName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(expiryText),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onCancel,
                child: Text(
                  AppLocalizations.of(context).get('cancel_subscription'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y.$m.$d';
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.priceText,
    required this.benefits,
    required this.onSubscribe,
    required this.onAutoSubscribe,
  });

  final String title;
  final String priceText;
  final List<String> benefits;
  final VoidCallback? onSubscribe;
  final VoidCallback? onAutoSubscribe;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(priceText, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...benefits.map(
              (benefit) => Row(
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSubscribe,
                    child: Text(
                      AppLocalizations.of(context).get('subscribe_btn'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAutoSubscribe,
                    child: Text(
                      AppLocalizations.of(context).get('auto_subscribe_btn'),
                    ),
                  ),
                ),
              ],
            ),
            if (onSubscribe == null && onAutoSubscribe == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppLocalizations.of(context).get('beta_sub_activate_later'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanDurationOption {
  const _PlanDurationOption({
    required this.months,
    required this.label,
    this.discountLabel,
  });

  final int months;
  final String label;
  final String? discountLabel;
}

class PolicyPage extends StatelessWidget {
  const PolicyPage({super.key, required this.title, this.isRefund = false});

  final String title;
  final bool isRefund;

  @override
  Widget build(BuildContext context) {
    final content =
        isRefund
            ? getRefundPolicyText(isBeta: AppConfig.isBetaVersion)
            : getSubscriptionPolicyText(isBeta: AppConfig.isBetaVersion);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

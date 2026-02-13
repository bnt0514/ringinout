import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/config/app_theme.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:ringinout/pages/gps_page.dart';
import 'package:ringinout/services/policy_texts.dart';
import 'package:ringinout/config/app_config.dart';

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
        title: const Text('구독 관리'),
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
              tabs: const [Tab(text: '구독 관리'), Tab(text: 'GPS')],
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

class _SubscriptionManagementView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentPlanCard(
          planName: currentPlanName,
          expiryDate: currentPlanExpiry,
          onCancel: onCancelPlan,
        ),
        const SizedBox(height: 16),
        if (AppConfig.isBetaVersion)
          Card(
            color: AppColors.shimmer,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '베타 기간에는 유료 플랜이 제공되지 않습니다. 베타 종료 후 공개됩니다.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
        else ...[
          _PlanCard(
            title: 'Basic',
            priceText: _priceText(basicProduct),
            benefits: const ['장소 5개', '활성 알람 10개', '광고 제거 포함'],
            onSubscribe: () => _showOneTimeSheet(context, 'Basic 구독'),
            onAutoSubscribe: () => _showAutoRenewSheet(context, 'Basic 자동 구독'),
          ),
          const SizedBox(height: 12),
          _PlanCard(
            title: 'Premium',
            priceText: _priceText(premiumProduct),
            benefits: const ['장소/알람 무제한', '광고 제거 포함'],
            onSubscribe: () => _showOneTimeSheet(context, 'Premium 구독'),
            onAutoSubscribe:
                () => _showAutoRenewSheet(context, 'Premium 자동 구독'),
          ),
          const SizedBox(height: 16),
          _PlanCard(
            title: '광고 제거',
            priceText: _priceText(adRemoveProduct),
            benefits: const ['앱 내 광고 제거'],
            onSubscribe: () => _showOneTimeSheet(context, '광고 제거'),
            onAutoSubscribe: () => _showAutoRenewSheet(context, '광고 제거 자동 구독'),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openPolicy(context, '구독 정책'),
              child: const Text('구독 정책'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _openPolicy(context, '환불 정책'),
              child: const Text('환불 정책'),
            ),
          ],
        ),
      ],
    );
  }

  String _priceText(ProductDetails? product) {
    if (product == null) return '가격 불러오는 중';
    return product.price;
  }

  void _openPolicy(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PolicyPage(title: title)),
    );
  }

  void _showOneTimeSheet(BuildContext context, String title) {
    final options = [
      _PlanDurationOption(months: 1, label: '1개월'),
      _PlanDurationOption(months: 3, label: '3개월', discountLabel: '5% 할인'),
      _PlanDurationOption(months: 6, label: '6개월', discountLabel: '10% 할인'),
      _PlanDurationOption(months: 12, label: '12개월', discountLabel: '20% 할인'),
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
                    const Text('31일마다 자동 결제됩니다.'),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreeBilling,
                      title: const Text('자동 결제에 동의합니다.'),
                      onChanged:
                          (value) =>
                              setState(() => agreeBilling = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreeTerms,
                      title: const Text('구독/환불 정책을 확인했습니다.'),
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
                        child: const Text('자동 구독 시작'),
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
    final expiryText =
        expiryDate == null ? '만료일: -' : '만료일: ${_formatDate(expiryDate!)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 플랜', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(planName, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(expiryText),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onCancel,
                child: const Text('해지'),
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
                    child: const Text('구독하기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAutoSubscribe,
                    child: const Text('자동 구독'),
                  ),
                ),
              ],
            ),
            if (onSubscribe == null && onAutoSubscribe == null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '베타 종료 후 구독이 활성화됩니다.',
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
  const PolicyPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final content =
        title.contains('환불')
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

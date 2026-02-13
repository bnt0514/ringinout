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
import 'package:ringinout/pages/gps_page.dart';
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
              children: const [
                _ServerSubscriptionView(),
                GpsPage(showAppBar: false),
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
                  price: '₩2,900 / 월',
                  features: const ['장소 5개', '활성 알람 10개', '광고 제거'],
                  isCurrentPlan: plan == SubscriptionPlan.basic,
                  onTap: () => _showComingSoon(context),
                ),
                const SizedBox(height: 12),
                _PlanCard(
                  title: 'Premium',
                  price: '₩4,900 / 월',
                  features: const ['장소 무제한', '알람 무제한', '광고 제거'],
                  isCurrentPlan:
                      plan == SubscriptionPlan.premium ||
                      plan == SubscriptionPlan.special,
                  recommended: true,
                  onTap: () => _showComingSoon(context),
                ),
              ],
              const SizedBox(height: 24),

              // 정책 링크
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
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('구독 기능은 준비 중입니다.')));
  }

  void _openPolicy(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PolicyPage(title: title)),
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
    final planName = _getPlanName(plan);
    final expiryText =
        expiresAt != null
            ? '만료: ${expiresAt!.year}.${expiresAt!.month}.${expiresAt!.day}'
            : plan == SubscriptionPlan.free
            ? '무료 플랜'
            : '무제한';

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
                const Text(
                  '현재 플랜',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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
    switch (plan) {
      case SubscriptionPlan.free:
        return '장소 2개, 알람 2개까지 사용 가능';
      case SubscriptionPlan.basic:
        return '장소 5개, 알람 10개까지 사용 가능';
      case SubscriptionPlan.premium:
        return '모든 기능 무제한 사용';
      case SubscriptionPlan.special:
        return '개발자 플랜 - 모든 기능 무제한';
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.features,
    required this.onTap,
    this.isCurrentPlan = false,
    this.recommended = false,
  });

  final String title;
  final String price;
  final List<String> features;
  final VoidCallback onTap;
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
                      child: const Text(
                        '추천',
                        style: TextStyle(
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
                    '사용 중',
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
                    child: const Text(
                      '구독하기',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

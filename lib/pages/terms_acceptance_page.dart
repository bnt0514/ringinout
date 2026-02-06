import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ringinout/services/policy_texts.dart';
import 'package:ringinout/services/terms_acceptance_service.dart';
import 'package:ringinout/config/app_config.dart';

class TermsAcceptancePage extends StatefulWidget {
  const TermsAcceptancePage({super.key, this.onAccepted});

  final VoidCallback? onAccepted;

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _agreed = false;

  Future<void> _accept() async {
    await TermsAcceptanceService.setAccepted(true);
    if (!mounted) return;
    if (widget.onAccepted != null) {
      widget.onAccepted!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _decline() async {
    await TermsAcceptanceService.setAccepted(false);
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final combinedText =
        '${getSubscriptionPolicyText(isBeta: AppConfig.isBetaVersion)}\n\n'
        '${getRefundPolicyText(isBeta: AppConfig.isBetaVersion)}';

    return Scaffold(
      appBar: AppBar(title: const Text('이용약관 동의')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    combinedText,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _agreed,
                    onChanged: (value) {
                      setState(() => _agreed = value ?? false);
                    },
                    title: const Text('이용약관 및 환불/구독 정책을 확인하고 동의합니다.'),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _agreed ? _accept : null,
                      child: const Text('동의하고 계속'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _decline,
                      child: const Text('동의하지 않음 (앱 종료)'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ringinout/services/app_localizations.dart';
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
  static const MethodChannel _appLifecycleChannel = MethodChannel(
    'com.example.ringinout/app_lifecycle',
  );
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
    await _appLifecycleChannel.invokeMethod('moveTaskToBack');
  }

  @override
  Widget build(BuildContext context) {
    final combinedText =
        '${getSubscriptionPolicyText(isBeta: AppConfig.isBetaVersion)}\n\n'
        '${getRefundPolicyText(isBeta: AppConfig.isBetaVersion)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('terms_agreement_title')),
      ),
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
                    title: Text(
                      AppLocalizations.of(context).get('terms_agree_text'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _agreed ? _accept : null,
                      child: Text(
                        AppLocalizations.of(context).get('terms_agree_btn'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _decline,
                      child: Text(
                        AppLocalizations.of(context).get('terms_disagree_btn'),
                      ),
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

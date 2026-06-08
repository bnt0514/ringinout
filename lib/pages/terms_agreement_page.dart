import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/policy_texts.dart';
import 'package:ringinout/services/smart_location_service.dart';

class TermsAgreementPage extends StatefulWidget {
  const TermsAgreementPage({super.key, required this.requiredVersion});

  final String requiredVersion;

  @override
  State<TermsAgreementPage> createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage> {
  static const MethodChannel _appLifecycleChannel = MethodChannel(
    'com.bnt0514.ringinout/app_lifecycle',
  );
  bool _agreed = false;

  Future<void> _accept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final authService = context.read<AuthService>();
      final session = await authService.ensureServerSession(forceRefresh: true);
      final accountId = session?.canonicalAccountId ?? user.uid;
      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(accountId)
          .collection('agreements')
          .doc('terms')
          .set({
            'version': widget.requiredVersion,
            'agreedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).get('terms_save_failed')),
        ),
      );
    }
  }

  Future<void> _decline() async {
    await SmartLocationService.cancelAllSnoozes();
    await SmartLocationService.stopMonitoring();
    await HiveHelper.setActiveOwnerUid(null);
    if (mounted) {
      await context.read<AuthService>().signOut();
    } else {
      await FirebaseAuth.instance.signOut();
    }
    await _appLifecycleChannel.invokeMethod('moveTaskToBack');
  }

  @override
  Widget build(BuildContext context) {
    final combinedText =
        '${getSubscriptionPolicyText(isBeta: AppConfig.isBetaVersion)}\n\n'
        '${getRefundPolicyText(isBeta: AppConfig.isBetaVersion)}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _decline();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).get('terms_agreement_title'),
          ),
          automaticallyImplyLeading: false,
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
                          AppLocalizations.of(
                            context,
                          ).get('terms_disagree_btn'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

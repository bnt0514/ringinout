import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/policy_texts.dart';

class TermsAgreementPage extends StatefulWidget {
  const TermsAgreementPage({super.key, required this.requiredVersion});

  final String requiredVersion;

  @override
  State<TermsAgreementPage> createState() => _TermsAgreementPageState();
}

class _TermsAgreementPageState extends State<TermsAgreementPage> {
  bool _agreed = false;

  Future<void> _accept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('약관 저장 실패. 다시 시도해주세요.')));
    }
  }

  Future<void> _decline() async {
    await FirebaseAuth.instance.signOut();
    SystemNavigator.pop();
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
          title: const Text('이용약관 동의 (필수)'),
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
      ),
    );
  }
}

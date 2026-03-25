import 'package:flutter/material.dart';

import 'package:ringinout/pages/terms_acceptance_page.dart';
import 'package:ringinout/services/terms_acceptance_service.dart';

class TermsGate extends StatefulWidget {
  const TermsGate({super.key, required this.child});

  final Widget child;

  @override
  State<TermsGate> createState() => _TermsGateState();
}

class _TermsGateState extends State<TermsGate> {
  bool _checked = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accepted = await TermsAcceptanceService.hasAccepted();
    if (!mounted) return;
    setState(() {
      _accepted = accepted;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_accepted) {
      return widget.child;
    }
    return TermsAcceptancePage(
      key: const ValueKey('terms_acceptance'),
      onAccepted: () {
        setState(() {
          _accepted = true;
          _checked = true;
        });
      },
    );
  }
}

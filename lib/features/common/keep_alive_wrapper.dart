import 'package:flutter/material.dart';

/// A wrapper widget that keeps its child alive when it would otherwise be disposed
/// Useful for maintaining state in tabs, PageView, etc.
class KeepAliveWidget extends StatefulWidget {
  final Widget child;

  const KeepAliveWidget({super.key, required this.child});

  @override
  State<KeepAliveWidget> createState() => _KeepAliveWidgetState();
}

class _KeepAliveWidgetState extends State<KeepAliveWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // Must call super.build to handle keep-alive functionality
    super.build(context);
    return widget.child;
  }
}

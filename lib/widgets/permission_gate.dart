import 'package:flutter/material.dart';
import 'package:ringinout/services/permissions.dart';
import 'package:ringinout/services/app_localizations.dart';

class PermissionGate extends StatefulWidget {
  final Widget child;

  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;
  bool _allGranted = false;
  bool _autoRequested = false;
  bool _batteryOptDisabled = true;
  bool _batteryDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initPermissionFlow();
  }

  Future<void> _initPermissionFlow() async {
    await _checkPermissions();
    if (_allGranted || _autoRequested) return;

    _autoRequested = true;
    await _requestPermissions();
  }

  Future<void> _checkPermissions() async {
    final granted = await PermissionManager.hasAllRequiredPermissions();
    final batteryOptDisabled =
        await PermissionManager.isBatteryOptimizationDisabled();
    if (!mounted) return;
    setState(() {
      _allGranted = granted;
      _batteryOptDisabled = batteryOptDisabled;
      _checking = false;
    });

    if (!batteryOptDisabled && !_batteryDialogShown) {
      _batteryDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBatteryOptimizationDialog();
      });
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _checking = true);
    await PermissionManager.requestAllPermissions();
    await _checkPermissions();
  }

  Future<void> _showBatteryOptimizationDialog() async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.get('battery_opt_warning_title')),
            content: Text(l10n.get('battery_opt_warning_desc')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.get('allow')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_allGranted) {
      return widget.child;
    }

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!_batteryOptDisabled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.get('battery_opt_warning_desc'),
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              const Spacer(),
              const Icon(Icons.lock_outline, size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                l10n.get('permission_required'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.get('grant_all_permissions'),
                style: const TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _requestPermissions,
                  child: Text(l10n.get('grant_permission')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: PermissionManager.openAppSettings,
                  child: Text(l10n.get('permission_settings')),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

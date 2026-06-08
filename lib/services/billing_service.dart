library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/utils/retry_helper.dart';

class BillingService extends ChangeNotifier {
  static const String serverUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  BillingService(this._authService);

  final AuthService _authService;

  SubscriptionPlan _cachedPlan = SubscriptionPlan.free;
  DateTime? _cachedExpiresAt;
  DateTime? _lastFetch;
  bool _isLoading = false;

  SubscriptionPlan get currentPlan => _cachedPlan;
  DateTime? get expiresAt => _cachedExpiresAt;
  bool get isLoading => _isLoading;

  Future<void> fetchStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastFetch != null) {
      final diff = DateTime.now().difference(_lastFetch!);
      if (diff.inMinutes < 5) {
        debugPrint('Billing status cached (${diff.inSeconds}s ago)');
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        _cachedPlan = SubscriptionPlan.free;
        return;
      }

      await _authService.ensureServerSession();
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        _cachedPlan = SubscriptionPlan.free;
        return;
      }

      final response = await retryWithBackoff(
        () async => http.get(
          Uri.parse('$serverUrl/getBillingStatus'),
          headers: await SecureHttpHeaders.json(idToken: idToken),
        ),
        maxAttempts: 3,
        initialDelay: const Duration(seconds: 2),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _cachedExpiresAt =
            data['expires_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'])
                : null;
        final active = data['status'] == 'active';
        final notExpired =
            _cachedExpiresAt == null ||
            _cachedExpiresAt!.isAfter(DateTime.now());
        _cachedPlan =
            active && notExpired
                ? _parsePlan(data['plan']?.toString())
                : SubscriptionPlan.free;
        _lastFetch = DateTime.now();
        debugPrint('Plan from server: $_cachedPlan');
      } else {
        _cachedPlan = SubscriptionPlan.free;
      }
    } catch (e) {
      debugPrint('Billing fetch failed: $e');
      _cachedPlan = SubscriptionPlan.free;
    } finally {
      _isLoading = false;
      await SubscriptionService.enforceAlarmLimits(_cachedPlan);
      notifyListeners();
    }
  }

  Future<bool> verifyPurchase({
    required String store,
    required String receipt,
    String? purchaseToken,
    required String productId,
    String packageName = 'com.bnt0514.ringinout',
    String purchaseType = 'subscription',
  }) async {
    try {
      await _authService.ensureServerSession();
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$serverUrl/verifyPurchase'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'store': store,
          'receipt': receipt,
          if (purchaseToken != null) 'purchaseToken': purchaseToken,
          'productId': productId,
          'packageName': packageName,
          'purchaseType': purchaseType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final verified = data['verified'] == true;
        if (!verified) {
          debugPrint('Purchase was not verified: ${response.body}');
          return false;
        }
        _cachedPlan = _parsePlan(data['plan']?.toString());
        _cachedExpiresAt =
            data['expires_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'])
                : null;
        _lastFetch = DateTime.now();

        debugPrint('Purchase verified: $_cachedPlan');
        notifyListeners();
        return true;
      } else {
        debugPrint('Purchase verification failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Purchase verification error: $e');
      return false;
    }
  }

  Future<String?> getObfuscatedAccountId() async {
    final session = await _authService.ensureServerSession();
    final canonical = session?.canonicalAccountId;
    if (canonical == null || canonical.isEmpty) return null;
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  SubscriptionPlan _parsePlan(String? planString) {
    switch (planString) {
      case 'plus':
      case 'basic':
        return SubscriptionPlan.plus;
      case 'pro':
      case 'premium':
        return SubscriptionPlan.pro;
      case 'special':
        return SubscriptionPlan.special;
      default:
        return SubscriptionPlan.free;
    }
  }

  void clearCache() {
    _cachedPlan = SubscriptionPlan.free;
    _cachedExpiresAt = null;
    _lastFetch = null;
    notifyListeners();
  }
}

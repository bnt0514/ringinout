/// BillingService - 구독 관리 서비스
///
/// 플랜 조회 우선순위:
/// 1. Firestore admin_config/special_users.uids 에 포함된 UID → special
/// 2. 서버 getBillingStatus (일반 유저)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/subscription_service.dart';
import 'package:ringinout/utils/retry_helper.dart';

class BillingService extends ChangeNotifier {
  static const String serverUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  final AuthService _authService;

  SubscriptionPlan _cachedPlan = SubscriptionPlan.free;
  DateTime? _cachedExpiresAt;
  DateTime? _lastFetch;
  bool _isLoading = false;

  BillingService(this._authService);

  SubscriptionPlan get currentPlan => _cachedPlan;
  DateTime? get expiresAt => _cachedExpiresAt;
  bool get isLoading => _isLoading;

  /// 구독 상태 가져오기
  /// 우선순위: special_users > 서버
  Future<void> fetchStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastFetch != null) {
      final diff = DateTime.now().difference(_lastFetch!);
      if (diff.inMinutes < 5) {
        debugPrint('⏭️  Billing status cached (${diff.inSeconds}s ago)');
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

      // 1. admin_config/special_users 에 포함된 UID → special 플랜
      final specialDoc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('special_users')
              .get();

      if (specialDoc.exists) {
        final uids = List<String>.from(specialDoc.data()?['uids'] ?? []);
        if (uids.contains(uid)) {
          _cachedPlan = SubscriptionPlan.special;
          _cachedExpiresAt = null;
          _lastFetch = DateTime.now();
          debugPrint('✅ Plan from special_users: special');
          return;
        }
      }

      // 2. 서버에서 조회 (일반 Google 로그인 유저)
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
        final data = jsonDecode(response.body);
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
                ? _parsePlan(data['plan'])
                : SubscriptionPlan.free;
        _lastFetch = DateTime.now();
        debugPrint('✅ Plan from server: $_cachedPlan');
      } else {
        _cachedPlan = SubscriptionPlan.free;
      }
    } catch (e) {
      debugPrint('❌ Billing fetch failed: $e');
      _cachedPlan = SubscriptionPlan.free;
    } finally {
      _isLoading = false;
      // ✅ 플랜 변경 시 초과 알람 자동 비활성화 (유료→무료 전환 보호)
      await SubscriptionService.enforceAlarmLimits(_cachedPlan);
      notifyListeners();
    }
  }

  /// 영수증 검증 (iOS/Android)
  Future<bool> verifyPurchase({
    required String store,
    required String receipt,
    String? purchaseToken,
    required String productId,
    String packageName = 'com.bnt0514.ringinout',
    String purchaseType = 'subscription',
  }) async {
    try {
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
        final data = jsonDecode(response.body);
        final verified = data['verified'] == true;
        if (!verified) {
          debugPrint('⚠️ Purchase was not verified: ${response.body}');
          return false;
        }
        _cachedPlan = _parsePlan(data['plan']);
        _cachedExpiresAt =
            data['expires_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'])
                : null;
        _lastFetch = DateTime.now();

        debugPrint('✅ Purchase verified: $_cachedPlan');
        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Purchase verification failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Purchase verification error: $e');
      return false;
    }
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

  /// 캐시 초기화
  void clearCache() {
    _cachedPlan = SubscriptionPlan.free;
    _cachedExpiresAt = null;
    _lastFetch = null;
    notifyListeners();
  }
}

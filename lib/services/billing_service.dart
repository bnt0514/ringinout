/**
 * BillingService - 구독 관리 서비스
 *
 * 플랜 조회 우선순위:
 * 1. Firestore users/{uid}.subscriptionPlan (테스트 계정 / 특별 부여)
 * 2. Firestore admin_config/special_users.uids 에 포함된 UID → special
 * 3. 서버 getBillingStatus (일반 유저)
 */

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/subscription_service.dart';

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
  /// 우선순위: Firestore 직접 부여 플랜 > special_users > 서버
  Future<void> fetchStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _lastFetch != null) {
      final diff = DateTime.now().difference(_lastFetch!);
      if (diff.inSeconds < 30) {
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

      // TODO: 배포 전 제거 — 개발자 UID 하드코딩
      const _devUids = ['IPf2TW0c62et7bwi8B5hZGyKLlc2'];
      if (_devUids.contains(uid)) {
        _cachedPlan = SubscriptionPlan.special;
        _cachedExpiresAt = null;
        _lastFetch = DateTime.now();
        debugPrint('✅ Plan: special (dev uid)');
        return;
      }

      // 1. Firestore users/{uid} 에 직접 플랜이 지정된 경우 (테스트 계정 포함)
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        final directPlan = data['subscriptionPlan'] as String?;
        final status = data['subscriptionStatus'] as String?;

        if (directPlan != null && status == 'active') {
          _cachedPlan = _parsePlan(directPlan);
          _cachedExpiresAt = null;
          _lastFetch = DateTime.now();
          debugPrint('✅ Plan from Firestore (direct): $_cachedPlan');
          return;
        }
      }

      // 2. admin_config/special_users 에 포함된 UID → special 플랜
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

      // 3. 서버에서 조회 (일반 Google 로그인 유저)
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        _cachedPlan = SubscriptionPlan.free;
        return;
      }

      final response = await http.get(
        Uri.parse('$serverUrl/getBillingStatus'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedPlan = _parsePlan(data['plan']);
        _cachedExpiresAt =
            data['expires_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'])
                : null;
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
      notifyListeners();
    }
  }

  /// 영수증 검증 (iOS/Android)
  Future<bool> verifyPurchase({
    required String store,
    required String receipt,
    String? purchaseToken,
  }) async {
    try {
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('$serverUrl/verifyPurchase'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'store': store,
          'receipt': receipt,
          if (purchaseToken != null) 'purchaseToken': purchaseToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cachedPlan = _parsePlan(data['plan']);
        _cachedExpiresAt =
            data['expires_at'] != null
                ? DateTime.fromMillisecondsSinceEpoch(data['expires_at'])
                : null;
        _lastFetch = DateTime.now();

        print('✅ Purchase verified: $_cachedPlan');
        notifyListeners();
        return true;
      } else {
        print('❌ Purchase verification failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Purchase verification error: $e');
      return false;
    }
  }

  SubscriptionPlan _parsePlan(String? planString) {
    switch (planString) {
      case 'basic':
        return SubscriptionPlan.basic;
      case 'premium':
        return SubscriptionPlan.premium;
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

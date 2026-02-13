/**
 * BillingService - 구독 관리 서비스
 * 
 * 기능:
 * - 서버에서 구독 플랜 조회
 * - 구독 상태 캐싱
 * - 플랜 변경 알림
 * 
 * 원칙:
 * - 플랜은 항상 서버에서 가져옴
 * - 로컬 캐시는 읽기 전용
 */

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:ringinout/services/auth_service.dart';
import 'package:ringinout/services/subscription_service.dart';

class BillingService extends ChangeNotifier {
  static const String serverUrl = 'http://localhost:3000'; // TODO: 프로덕션 URL로 변경

  final AuthService _authService;

  SubscriptionPlan _cachedPlan = SubscriptionPlan.free;
  DateTime? _cachedExpiresAt;
  DateTime? _lastFetch;
  bool _isLoading = false;

  BillingService(this._authService);

  SubscriptionPlan get currentPlan => _cachedPlan;
  DateTime? get expiresAt => _cachedExpiresAt;
  bool get isLoading => _isLoading;

  /// 서버에서 구독 상태 가져오기
  Future<void> fetchStatus({bool forceRefresh = false}) async {
    // 30초 이내 재요청 방지 (forceRefresh 제외)
    if (!forceRefresh && _lastFetch != null) {
      final diff = DateTime.now().difference(_lastFetch!);
      if (diff.inSeconds < 30) {
        print('⏭️  Billing status cached (${diff.inSeconds}s ago)');
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final idToken = await _authService.getIdToken();
      if (idToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('$serverUrl/billing/status'),
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

        print('✅ Billing status fetched: $_cachedPlan');
        notifyListeners();
      } else {
        throw Exception(
          'Failed to fetch billing status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('❌ Billing fetch failed: $e');
      // 오류 시 free 플랜으로 폴백
      _cachedPlan = SubscriptionPlan.free;
      notifyListeners();
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
        Uri.parse('$serverUrl/billing/verify'),
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

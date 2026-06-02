// lib/google_geocoding_service.dart
// Google 지오코딩 서비스 — 주소/장소 검색(forward)만 사용합니다.

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/services/naver_geocoding_service.dart';
import 'package:ringinout/services/secure_http_headers.dart';

class GoogleGeocodingService {
  static const String _functionsBaseUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  /// 주소/장소명 검색 (Google Places Text Search)
  static Future<List<LocalSearchResult>> searchPlace(
    String query, {
    double? lat,
    double? lng,
    String language = 'ko',
  }) async {
    if (!AppConfig.isGeocodingEnabled) {
      debugPrint('🚫 [GoogleGeocode] 지오코딩 킬스위치 활성 — searchPlace 스킵');
      return [];
    }
    try {
      debugPrint('🔍 Google 장소 검색 시작: $query');
      await MapUsageService.trackGeocodingCall('google_place');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[GooglePlace] missing login token');
        return [];
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/googlePlaceSearch'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'query': query,
          'language': _normalizeLanguage(language),
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List? ?? [];
        final results =
            places
                .map(
                  (item) => LocalSearchResult(
                    title: item['name'] ?? '',
                    address: item['address'] ?? '',
                    roadAddress: item['roadAddress'] ?? item['address'] ?? '',
                    category: item['category'] ?? '',
                    lat: (item['lat'] as num?)?.toDouble() ?? 0,
                    lng: (item['lng'] as num?)?.toDouble() ?? 0,
                  ),
                )
                .where((r) => r.lat != 0 && r.lng != 0)
                .toList();

        debugPrint('✅ Google 장소 검색 결과: ${results.length}건');
        return results;
      }
      debugPrint('❌ Google 장소 검색 실패: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('❌ Google 장소 검색 에러: $e');
    }
    return [];
  }

  /// 주소 → 좌표 변환 (Geocoding)
  static Future<GeocodingResult?> searchAddress(
    String query, {
    String language = 'ko',
  }) async {
    if (!AppConfig.isGeocodingEnabled) {
      debugPrint('🚫 [GoogleGeocode] 지오코딩 킬스위치 활성 — searchAddress 스킵');
      return null;
    }
    try {
      debugPrint('🔍 Google 지오코딩 검색 시작: $query');
      await MapUsageService.trackGeocodingCall('google_fwd');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[GoogleGeocode] missing login token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/googleGeocode'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'query': query,
          'language': _normalizeLanguage(language),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📋 Google 지오코딩 응답 status: ${data['status']}');
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final address = result['formatted_address'] ?? '';

          debugPrint('✅ Google 주소 찾음: $address');
          return GeocodingResult(
            lat: (location['lat'] as num).toDouble(),
            lng: (location['lng'] as num).toDouble(),
            roadAddress: address,
            jibunAddress: address,
          );
        }
      }
      debugPrint('❌ Google 지오코딩 실패: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('❌ Google 지오코딩 에러: $e');
    }
    return null;
  }

  static Future<GeocodingResult?> reverseGeocode(
    double lat,
    double lng, {
    String language = 'ko',
  }) async {
    if (!AppConfig.isGeocodingEnabled) {
      return null;
    }
    try {
      await MapUsageService.trackGeocodingCall('google_rev');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[GoogleReverse] missing login token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/googleReverseGeocode'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'lat': lat,
          'lng': lng,
          'language': _normalizeLanguage(language),
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          final address = result['formatted_address'] ?? '';
          return GeocodingResult(
            lat: lat,
            lng: lng,
            roadAddress: address,
            jibunAddress: address,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Google 역지오코딩 에러: $e');
    }
    return null;
  }

  static String _normalizeLanguage(String language) {
    const supported = {'ko', 'en', 'ja', 'zh', 'de', 'fr', 'es'};
    final normalized = language.toLowerCase().split(RegExp('[-_]')).first;
    return supported.contains(normalized) ? normalized : 'en';
  }
}

// lib/services/google_geocoding_service.dart
// Google 지오코딩 서비스 (geocoding 패키지 활용)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ringinout/services/naver_geocoding_service.dart';
import 'package:ringinout/utils/geocoding_cache.dart';

class GoogleGeocodingService {
  // Google Maps Geocoding API key (AndroidManifest.xml과 동일)
  static const String _apiKey = 'AIzaSyBeH5HhLcpj2JL91U_1eSHU4vRyC_qmxao';
  static final _cache = GeocodingCache();

  /// 좌표 → 주소 변환 (Reverse Geocoding)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    // 온디바이스 캐시 확인
    final cached = _cache.get(lat, lng);
    if (cached != null) {
      debugPrint('📦 [GoogleGeocode] cache hit');
      return cached;
    }

    try {
      debugPrint('🔄 Google 역지오코딩 시작: ($lat, $lng)');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng'
        '&key=$_apiKey'
        '&language=ko',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📋 Google 역지오코딩 응답 status: ${data['status']}');
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            (data['results'] as List).isNotEmpty) {
          final address = data['results'][0]['formatted_address'] as String?;
          debugPrint('✅ Google 역지오코딩 결과: $address');
          if (address != null) await _cache.put(lat, lng, address);
          return address;
        }
        if (data['status'] == 'REQUEST_DENIED') {
          debugPrint(
            '⚠️ Google Geocoding API가 활성화되지 않았습니다. '
            'Google Cloud Console에서 "Geocoding API"를 활성화해주세요.',
          );
          debugPrint('⚠️ 에러 메시지: ${data['error_message'] ?? 'N/A'}');
        }
      }
      debugPrint(
        '❌ Google 역지오코딩 실패: HTTP ${response.statusCode}, body: ${response.body.substring(0, (response.body.length > 300) ? 300 : response.body.length)}',
      );
    } catch (e) {
      debugPrint('❌ Google 역지오코딩 에러: $e');
    }
    return null;
  }

  /// 주소/장소명 검색 (Google Places Text Search)
  static Future<List<LocalSearchResult>> searchPlace(
    String query, {
    double? lat,
    double? lng,
  }) async {
    try {
      debugPrint('🔍 Google 장소 검색 시작: $query');

      String urlStr =
          'https://maps.googleapis.com/maps/api/place/textsearch/json'
          '?query=${Uri.encodeComponent(query)}'
          '&key=$_apiKey'
          '&language=ko';

      if (lat != null && lng != null) {
        urlStr += '&location=$lat,$lng&radius=50000';
      }

      final url = Uri.parse(urlStr);
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📋 Google 장소 검색 응답 status: ${data['status']}');
        if (data['status'] == 'OK') {
          final results =
              (data['results'] as List)
                  .take(5)
                  .map((item) {
                    final location = item['geometry']?['location'];
                    return LocalSearchResult(
                      title: item['name'] ?? '',
                      address: item['formatted_address'] ?? '',
                      roadAddress: item['formatted_address'] ?? '',
                      category:
                          (item['types'] as List?)?.take(2).join(', ') ?? '',
                      lat: (location?['lat'] as num?)?.toDouble() ?? 0,
                      lng: (location?['lng'] as num?)?.toDouble() ?? 0,
                    );
                  })
                  .where((r) => r.lat != 0 && r.lng != 0)
                  .toList();

          debugPrint('✅ Google 장소 검색 결과: ${results.length}건');
          return results;
        }
        if (data['status'] == 'REQUEST_DENIED') {
          debugPrint(
            '⚠️ Google Places API가 활성화되지 않았습니다. '
            'Google Cloud Console에서 "Places API"를 활성화해주세요.',
          );
          debugPrint('⚠️ 에러 메시지: ${data['error_message'] ?? 'N/A'}');
        }
      }
      debugPrint('❌ Google 장소 검색 실패: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Google 장소 검색 에러: $e');
    }
    return [];
  }

  /// 주소 → 좌표 변환 (Geocoding)
  static Future<GeocodingResult?> searchAddress(String query) async {
    try {
      debugPrint('🔍 Google 지오코딩 검색 시작: $query');
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(query)}'
        '&key=$_apiKey'
        '&language=ko',
      );

      final response = await http.get(url);

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
        if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('⚠️ Google Geocoding API가 활성화되지 않았습니다.');
          debugPrint('⚠️ 에러 메시지: ${data['error_message'] ?? 'N/A'}');
        }
      }
      debugPrint('❌ Google 지오코딩 실패: HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Google 지오코딩 에러: $e');
    }
    return null;
  }
}

// lib/services/naver_geocoding_service.dart
// 네이버 지오코딩 API 서비스
// - 역지오코딩(reverse)은 OSM Nominatim으로 통합되어 제거됨

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/map_usage_service.dart';

class NaverGeocodingService {
  // 네이버 클라우드 플랫폼 API 키 (Geocoding)
  static const String _clientId = 'k68ej9xnz7';
  static const String _clientSecret =
      '5GLjOCubGYbZZwPpFK5sP6ko71ktqB7uRbJASNYg';

  // 네이버 개발자센터 API 키 (Local Search)
  static const String _devClientId = 'aUS9TAPzqwqtpQJwNvKL';
  static const String _devClientSecret = 'MKU_6OiXW9';

  /// 주소 → 좌표 변환 (Geocoding)
  static Future<GeocodingResult?> searchAddress(String query) async {
    if (!AppConfig.isGeocodingEnabled) {
      debugPrint('🚫 [NaverGeocode] 지오코딩 킬스위치 활성 — searchAddress 스킵');
      return null;
    }
    try {
      debugPrint('🔍 지오코딩 검색 시작: $query');
      await MapUsageService.trackGeocodingCall('naver_fwd');
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://maps.apigw.ntruss.com/map-geocode/v2/geocode?query=$encodedQuery',
      );

      debugPrint('📡 API 호출 URL: $url');
      final response = await http.get(
        url,
        headers: {
          'x-ncp-apigw-api-key-id': _clientId,
          'x-ncp-apigw-api-key': _clientSecret,
          'Accept': 'application/json',
        },
      );

      debugPrint('📥 응답 코드: ${response.statusCode}');
      debugPrint('📥 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['addresses'] != null &&
            (data['addresses'] as List).isNotEmpty) {
          final address = data['addresses'][0];
          debugPrint('✅ 주소 찾음: ${address['roadAddress']}');
          return GeocodingResult(
            lat: double.parse(address['y']),
            lng: double.parse(address['x']),
            roadAddress: address['roadAddress'] ?? '',
            jibunAddress: address['jibunAddress'] ?? '',
          );
        } else {
          debugPrint('⚠️ 주소 결과 없음');
        }
      } else {
        debugPrint(
          '❌ 네이버 지오코딩 API 오류: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 지오코딩 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
    return null;
  }

  // [제거됨] reverseGeocode — NCP 유료(₩4/호출) → OSM Nominatim(무료)로 통합
  //   → add_myplaces_page._reverseGeocode 는 OsmGeocodingService.reverseGeocode 사용

  /// 장소명 검색 (Naver Local Search API)
  /// [lat], [lng]가 주어지면 해당 좌표 기준으로 검색어에 지역명을 자동 추가
  static Future<List<LocalSearchResult>> searchPlace(
    String query, {
    double? lat,
    double? lng,
  }) async {
    try {
      debugPrint('🔍 장소 검색 시작: $query');
      final encodedQuery = Uri.encodeComponent(query);
      final url = Uri.parse(
        'https://openapi.naver.com/v1/search/local.json?query=$encodedQuery&display=5&sort=random',
      );

      final response = await http.get(
        url,
        headers: {
          'X-Naver-Client-Id': _devClientId,
          'X-Naver-Client-Secret': _devClientSecret,
          'Accept': 'application/json',
        },
      );

      debugPrint('📥 장소 검색 응답: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List? ?? [];

        final results =
            items
                .map((item) {
                  // 네이버 Local Search API는 KATECH 좌표 → WGS84 변환 필요 없음
                  // mapx, mapy는 이미 경위도 * 10,000,000 형태
                  final mapx =
                      int.tryParse(item['mapx']?.toString() ?? '0') ?? 0;
                  final mapy =
                      int.tryParse(item['mapy']?.toString() ?? '0') ?? 0;
                  final lng = mapx / 10000000.0;
                  final lat = mapy / 10000000.0;

                  // HTML 태그 제거
                  final title = (item['title'] ?? '').replaceAll(
                    RegExp(r'<[^>]*>'),
                    '',
                  );

                  return LocalSearchResult(
                    title: title,
                    address: item['address'] ?? '',
                    roadAddress: item['roadAddress'] ?? '',
                    category: item['category'] ?? '',
                    lat: lat,
                    lng: lng,
                  );
                })
                .where((r) => r.lat != 0 && r.lng != 0)
                .toList();

        debugPrint('✅ 장소 검색 결과: ${results.length}건');
        return results;
      } else {
        debugPrint('❌ 장소 검색 API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ 장소 검색 실패: $e');
      debugPrint('스택 트레이스: $stackTrace');
    }
    return [];
  }
}

class LocalSearchResult {
  final String title;
  final String address;
  final String roadAddress;
  final String category;
  final double lat;
  final double lng;

  LocalSearchResult({
    required this.title,
    required this.address,
    required this.roadAddress,
    required this.category,
    required this.lat,
    required this.lng,
  });

  String get displayAddress => roadAddress.isNotEmpty ? roadAddress : address;
}

class GeocodingResult {
  final double lat;
  final double lng;
  final String roadAddress;
  final String jibunAddress;

  GeocodingResult({
    required this.lat,
    required this.lng,
    required this.roadAddress,
    required this.jibunAddress,
  });

  String get displayAddress =>
      roadAddress.isNotEmpty ? roadAddress : jibunAddress;
}

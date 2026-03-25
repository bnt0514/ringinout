// lib/services/naver_geocoding_service.dart
// 네이버 지오코딩 API 서비스

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NaverGeocodingService {
  // 네이버 클라우드 플랫폼 API 키 (Geocoding/Reverse Geocoding)
  static const String _clientId = 'k68ej9xnz7';
  static const String _clientSecret =
      '5GLjOCubGYbZZwPpFK5sP6ko71ktqB7uRbJASNYg';

  // 네이버 개발자센터 API 키 (Local Search)
  static const String _devClientId = 'aUS9TAPzqwqtpQJwNvKL';
  static const String _devClientSecret = 'MKU_6OiXW9';

  /// 주소 → 좌표 변환 (Geocoding)
  static Future<GeocodingResult?> searchAddress(String query) async {
    try {
      debugPrint('🔍 지오코딩 검색 시작: $query');
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

  /// 좌표 → 주소 변환 (Reverse Geocoding)
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      debugPrint('🔄 역지오코딩 시작: ($lat, $lng)');
      final url = Uri.parse(
        'https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc'
        '?coords=$lng,$lat'
        '&orders=roadaddr,addr'
        '&output=json',
      );

      debugPrint('📡 역지오코딩 URL: $url');
      final response = await http.get(
        url,
        headers: {
          'x-ncp-apigw-api-key-id': _clientId,
          'x-ncp-apigw-api-key': _clientSecret,
          'Accept': 'application/json',
        },
      );

      debugPrint('📥 역지오코딩 응답: ${response.statusCode}');
      debugPrint('📥 역지오코딩 본문: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final result = data['results'][0];
          final region = result['region'];
          final land = result['land'];

          // 도로명 주소 조합
          if (result['name'] == 'roadaddr' && land != null) {
            final area1 = region['area1']['name'] ?? ''; // 시/도
            final area2 = region['area2']['name'] ?? ''; // 구/군
            final area3 = region['area3']['name'] ?? ''; // 동
            final roadName = land['name'] ?? '';
            final number1 = land['number1'] ?? '';
            final number2 = land['number2'] ?? '';

            String address = '$area1 $area2 $roadName $number1';
            if (number2.isNotEmpty) {
              address += '-$number2';
            }
            return address.trim();
          }

          // 지번 주소 조합
          if (result['name'] == 'addr' && land != null) {
            final area1 = region['area1']['name'] ?? '';
            final area2 = region['area2']['name'] ?? '';
            final area3 = region['area3']['name'] ?? '';
            final number1 = land['number1'] ?? '';
            final number2 = land['number2'] ?? '';

            String address = '$area1 $area2 $area3 $number1';
            if (number2.isNotEmpty) {
              address += '-$number2';
            }
            return address.trim();
          }
        }
      } else {
        debugPrint('역지오코딩 API 오류: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('역지오코딩 실패: $e');
    }
    return null;
  }

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

// lib/services/naver_geocoding_service.dart
// 네이버 지오코딩 API 서비스

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class NaverGeocodingService {
  // 네이버 클라우드 플랫폼 API 키
  static const String _clientId = 'k68ej9xnz7';
  static const String _clientSecret =
      '5GLjOCubGYbZZwPpFK5sP6ko71ktqB7uRbJASNYg';

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

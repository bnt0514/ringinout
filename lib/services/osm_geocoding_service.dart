// lib/services/osm_geocoding_service.dart
// Nominatim (OpenStreetMap) 지오코딩 서비스 — 무료, API 키 불필요
// Usage Policy: https://operations.osmfoundation.org/policies/nominatim/
// - 1 req/sec 이하 유지, User-Agent 명시 필수

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OsmGeocodingService {
  static const _userAgent = 'ringinout/1.0 (location-alarm-app)';
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  // ──────────────────────────────────────────────
  // 역지오코딩: 좌표 → 주소
  // ──────────────────────────────────────────────
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/reverse'
        '?lat=$lat&lon=$lng'
        '&format=jsonv2'
        '&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['display_name'] as String?;
    } catch (e) {
      debugPrint('⚠️ [OsmGeocode] reverseGeocode 실패: $e');
      return null;
    }
  }

  // ──────────────────────────────────────────────
  // 정방향 지오코딩: 주소/장소명 → 좌표
  // 한국의 경우 품질이 낮을 수 있음
  // ──────────────────────────────────────────────
  static Future<List<OsmSearchResult>> search(
    String query, {
    int limit = 5,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/search'
        '?q=${Uri.encodeQueryComponent(query)}'
        '&format=jsonv2'
        '&limit=$limit'
        '&accept-language=ko',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': _userAgent},
      );

      if (response.statusCode != 200) return [];
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map(
            (e) => OsmSearchResult(
              displayName: e['display_name'] as String? ?? '',
              lat: double.tryParse(e['lat'] as String? ?? '') ?? 0,
              lng: double.tryParse(e['lon'] as String? ?? '') ?? 0,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('⚠️ [OsmGeocode] search 실패: $e');
      return [];
    }
  }
}

class OsmSearchResult {
  final String displayName;
  final double lat;
  final double lng;

  OsmSearchResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

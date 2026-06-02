// lib/services/naver_geocoding_service.dart
// Naver Cloud Platform Maps Geocoding proxy.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/map_usage_service.dart';
import 'package:ringinout/services/secure_http_headers.dart';

class NaverGeocodingService {
  static const String _functionsBaseUrl =
      'https://us-central1-ringgo-485705.cloudfunctions.net';

  static Future<GeocodingResult?> searchAddress(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (!AppConfig.isGeocodingEnabled) {
      debugPrint('[NaverGeocode] disabled, skipping searchAddress');
      return null;
    }

    try {
      debugPrint('[NaverGeocode] searching: $query');
      await MapUsageService.trackGeocodingCall('naver_fwd');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[NaverGeocode] missing login token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/naverGeocode'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'query': query,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        }),
      );

      debugPrint('[NaverGeocode] response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addresses = data['addresses'] as List? ?? [];
        if (addresses.isNotEmpty) {
          final address = addresses.first;
          return GeocodingResult(
            lat: double.parse(address['y']),
            lng: double.parse(address['x']),
            roadAddress: address['roadAddress'] ?? '',
            jibunAddress: address['jibunAddress'] ?? '',
          );
        }
        debugPrint('[NaverGeocode] no address result');
      } else {
        debugPrint(
          '[NaverGeocode] API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[NaverGeocode] failed: $e');
      debugPrint('[NaverGeocode] stack: $stackTrace');
    }
    return null;
  }

  static Future<List<LocalSearchResult>> searchPlace(
    String query, {
    double? lat,
    double? lng,
  }) async {
    if (!AppConfig.isGeocodingEnabled) {
      debugPrint('[NaverLocalSearch] disabled, skipping searchPlace');
      return [];
    }

    try {
      debugPrint('[NaverLocalSearch] searching: $query');
      await MapUsageService.trackGeocodingCall('naver_place');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[NaverLocalSearch] missing login token');
        return [];
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/naverLocalSearch'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'query': query,
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
        }),
      );

      debugPrint('[NaverLocalSearch] response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data['places'] as List? ?? [];
        final results =
            places
                .take(5)
                .map((item) {
                  final placeLat =
                      (item['lat'] as num?)?.toDouble() ??
                      _coordinateFromPair(item['coords'], 1);
                  final placeLng =
                      (item['lng'] as num?)?.toDouble() ??
                      _coordinateFromPair(item['coords'], 0);

                  return LocalSearchResult(
                    title: item['name'] ?? '',
                    address: item['address'] ?? '',
                    roadAddress: item['roadAddress'] ?? item['address'] ?? '',
                    category: item['category'] ?? '',
                    lat: placeLat,
                    lng: placeLng,
                  );
                })
                .where((result) => result.lat != 0 && result.lng != 0)
                .toList();

        debugPrint('[NaverLocalSearch] results: ${results.length}');
        return results;
      } else {
        debugPrint(
          '[NaverLocalSearch] API error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('[NaverLocalSearch] failed: $e');
      debugPrint('[NaverLocalSearch] stack: $stackTrace');
    }
    return [];
  }

  static Future<GeocodingResult?> reverseGeocode(double lat, double lng) async {
    if (!AppConfig.isGeocodingEnabled) {
      return null;
    }

    try {
      await MapUsageService.trackGeocodingCall('naver_rev');
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        debugPrint('[NaverReverse] missing login token');
        return null;
      }

      final response = await http.post(
        Uri.parse('$_functionsBaseUrl/naverReverseGeocode'),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({'lat': lat, 'lng': lng}),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[NaverReverse] API error: ${response.statusCode} - ${response.body}',
        );
        return null;
      }

      final data = json.decode(response.body);
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) return null;

      final road = _formatNaverAddress(
        results.cast<Map>().firstWhere(
          (item) => item['name'] == 'roadaddr',
          orElse: () => const {},
        ),
      );
      final jibun = _formatNaverAddress(
        results.cast<Map>().firstWhere(
          (item) => item['name'] == 'addr',
          orElse: () => results.first as Map,
        ),
      );

      return GeocodingResult(
        lat: lat,
        lng: lng,
        roadAddress: road,
        jibunAddress: jibun,
      );
    } catch (e, stackTrace) {
      debugPrint('[NaverReverse] failed: $e');
      debugPrint('[NaverReverse] stack: $stackTrace');
    }
    return null;
  }

  static double _coordinateFromPair(dynamic coords, int index) {
    final value = coords?.toString() ?? '';
    if (!value.contains(',')) return 0;
    final parts = value.split(',');
    if (index < 0 || index >= parts.length) return 0;
    return double.tryParse(parts[index].trim()) ?? 0;
  }

  static String _formatNaverAddress(Map item) {
    if (item.isEmpty) return '';
    final region = item['region'] as Map? ?? {};
    final land = item['land'] as Map? ?? {};
    final area1 = (region['area1'] as Map?)?['name']?.toString() ?? '';
    final area2 = (region['area2'] as Map?)?['name']?.toString() ?? '';
    final area3 = (region['area3'] as Map?)?['name']?.toString() ?? '';
    final area4 = (region['area4'] as Map?)?['name']?.toString() ?? '';
    final roadName = land['name']?.toString() ?? '';
    final number1 = land['number1']?.toString() ?? '';
    final number2 = land['number2']?.toString() ?? '';
    final addition0 = ((land['addition0'] as Map?)?['value'] ?? '').toString();
    final number =
        number2.isNotEmpty && number2 != '0' ? '$number1-$number2' : number1;

    final parts =
        <String>[
          area1,
          area2,
          area3,
          area4,
        ].where((part) => part.isNotEmpty).toList();
    if (roadName.isNotEmpty) parts.add(roadName);
    if (number.isNotEmpty) parts.add(number);
    if (addition0.isNotEmpty) parts.add(addition0);
    return parts.join(' ');
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

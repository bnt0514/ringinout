import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class SecureHttpHeaders {
  static Future<Map<String, String>> json({String? idToken}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (idToken != null && idToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    try {
      final appCheckToken = await FirebaseAppCheck.instance.getToken(false);
      if (appCheckToken != null && appCheckToken.isNotEmpty) {
        headers['X-Firebase-AppCheck'] = appCheckToken;
      }
    } catch (e) {
      debugPrint('App Check token unavailable: $e');
    }

    return headers;
  }
}

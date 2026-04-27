// lib/services/force_update_service.dart
//
// 강제 업데이트 체크 서비스
// - Firestore admin_config/app_settings 의 min_version 필드를 읽어
//   현재 앱 버전이 낮으면 ForceUpdateDialog를 표시
// - 어드민이 Firestore에서 min_version을 바꾸면 즉시 적용됨

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateService {
  static const _collection = 'admin_config';
  static const _doc = 'app_settings';
  static const _field = 'min_version';

  /// 현재 버전 < min_version 이면 true
  static Future<bool> needsUpdate() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection(_collection)
              .doc(_doc)
              .get();
      final minStr = snap.data()?[_field] as String?;
      if (minStr == null) return false;

      final info = await PackageInfo.fromPlatform();
      return _isLower(info.version, minStr);
    } catch (e) {
      debugPrint('⚠️ [ForceUpdate] 버전 체크 실패 (통과): $e');
      return false; // 네트워크 오류 시 차단하지 않음
    }
  }

  /// 어드민: min_version 설정
  static Future<void> setMinVersion(String version) async {
    await FirebaseFirestore.instance.collection(_collection).doc(_doc).set({
      _field: version,
    }, SetOptions(merge: true));
  }

  /// 어드민: 현재 설정된 min_version 조회
  static Future<String?> getMinVersion() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection(_collection)
              .doc(_doc)
              .get();
      return snap.data()?[_field] as String?;
    } catch (_) {
      return null;
    }
  }

  /// "1.0.4" < "1.0.5" → true
  static bool _isLower(String current, String minimum) {
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final m = minimum.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = [c.length, m.length].reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < len; i++) {
      final cv = i < c.length ? c[i] : 0;
      final mv = i < m.length ? m[i] : 0;
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return false; // 같으면 업데이트 불필요
  }
}

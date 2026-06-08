// lib/services/force_update_service.dart
//
// Force update checks use the full app version: version+buildNumber.
// Example: 1.0.11+19

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ringinout/services/hive_helper.dart';

class ForceUpdateService {
  static const _collection = 'admin_config';
  static const _doc = 'app_settings';
  static const _field = 'min_version';
  static const _specialUsersDoc = 'special_users';
  static const _specialUsersField = 'uids';
  static const _specialCanonicalField = 'canonicalAccountIds';

  static Future<bool> needsUpdate() async {
    try {
      if (await _isForceUpdateExemptUser()) {
        debugPrint('[ForceUpdate] exempt user, bypassing force update');
        return false;
      }

      final snap =
          await FirebaseFirestore.instance
              .collection(_collection)
              .doc(_doc)
              .get();
      final minStr = snap.data()?[_field] as String?;
      if (minStr == null || minStr.trim().isEmpty) return false;

      final info = await PackageInfo.fromPlatform();
      return _isLower(_fullVersion(info), minStr);
    } catch (e) {
      debugPrint('[ForceUpdate] version check failed, allowing app: $e');
      return false;
    }
  }

  static Future<bool> _isForceUpdateExemptUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return false;

    final snap =
        await FirebaseFirestore.instance
            .collection(_collection)
            .doc(_specialUsersDoc)
            .get();
    final rawUids = snap.data()?[_specialUsersField];
    final rawCanonical = snap.data()?[_specialCanonicalField];
    final candidates = {
      uid,
      if (HiveHelper.storedActiveOwnerUid != null)
        HiveHelper.storedActiveOwnerUid!,
    };
    final uidMatch =
        rawUids is List &&
        rawUids.map((e) => e.toString()).any(candidates.contains);
    final canonicalMatch =
        rawCanonical is List &&
        rawCanonical.map((e) => e.toString()).any(candidates.contains);
    return uidMatch || canonicalMatch;
  }

  static Future<void> setMinVersion(String version) async {
    final trimmed = version.trim();
    if (trimmed.isNotEmpty && !isFullVersion(trimmed)) {
      throw ArgumentError(
        'min_version must use full app version format, e.g. 1.0.11+19',
      );
    }

    await FirebaseFirestore.instance.collection(_collection).doc(_doc).set({
      _field: trimmed,
    }, SetOptions(merge: true));
  }

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

  static String fullVersionFromPackageInfo(PackageInfo info) =>
      _fullVersion(info);

  static bool isFullVersion(String value) =>
      RegExp(r'^\d+(?:\.\d+)*\+\d+$').hasMatch(value.trim());

  static String _fullVersion(PackageInfo info) =>
      '${info.version}+${info.buildNumber}';

  static bool _isLower(String current, String minimum) {
    final currentVersion = _ParsedAppVersion.parse(current);
    final minimumVersion = _ParsedAppVersion.parse(minimum);
    if (currentVersion == null || minimumVersion == null) return false;

    final len = [
      currentVersion.versionParts.length,
      minimumVersion.versionParts.length,
    ].reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < len; i++) {
      final cv =
          i < currentVersion.versionParts.length
              ? currentVersion.versionParts[i]
              : 0;
      final mv =
          i < minimumVersion.versionParts.length
              ? minimumVersion.versionParts[i]
              : 0;
      if (cv < mv) return true;
      if (cv > mv) return false;
    }
    return currentVersion.buildNumber < minimumVersion.buildNumber;
  }
}

class _ParsedAppVersion {
  final List<int> versionParts;
  final int buildNumber;

  const _ParsedAppVersion({
    required this.versionParts,
    required this.buildNumber,
  });

  static _ParsedAppVersion? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final split = value.split('+');
    if (split.length > 2) return null;

    final versionParts =
        split.first
            .split('.')
            .map((part) => int.tryParse(part.trim()))
            .toList();
    if (versionParts.isEmpty || versionParts.any((part) => part == null)) {
      return null;
    }

    return _ParsedAppVersion(
      versionParts: versionParts.cast<int>(),
      buildNumber: split.length == 2 ? int.tryParse(split[1].trim()) ?? 0 : 0,
    );
  }
}

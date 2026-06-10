class WifiAlarmSettings {
  static const int defaultWaitMinutes = 15;
  static const int minWaitMinutes = 5;
  static const int maxWaitMinutes = 60;

  static int normalizeWaitMinutes(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    final minutes = parsed ?? defaultWaitMinutes;
    return minutes.clamp(minWaitMinutes, maxWaitMinutes).toInt();
  }

  static String normalizeSsidBase(String ssid) {
    var value = ssid.trim().toLowerCase();
    if (value.isEmpty) return value;

    value = value.replaceAll(RegExp(r'\s+'), ' ');

    final suffixPatterns = [
      RegExp(r'[\s_-]*(2g|5g|6g)$', caseSensitive: false),
      RegExp(r'[\s_-]*(2\.4g|2\.4ghz|5ghz|6ghz)$', caseSensitive: false),
      RegExp(r'[\s_-]*(24g|24ghz)$', caseSensitive: false),
    ];

    for (final pattern in suffixPatterns) {
      final next = value.replaceFirst(pattern, '').trim();
      if (next.isNotEmpty && next != value) return next;
    }
    return value;
  }

  static bool isGuestLikeSsid(String ssid) {
    final value = ssid.trim().toLowerCase();
    if (value.isEmpty) return false;
    return RegExp(
      r'(^|[\s_-])(guest|iot|ext|extend|repeater)($|[\s_-])',
    ).hasMatch(value);
  }

  static bool isSuggestedSibling(String connectedSsid, String candidateSsid) {
    if (connectedSsid.trim().isEmpty || candidateSsid.trim().isEmpty) {
      return false;
    }
    if (isGuestLikeSsid(candidateSsid)) return false;

    final connectedBase = normalizeSsidBase(connectedSsid);
    final candidateBase = normalizeSsidBase(candidateSsid);
    if (connectedBase.length < 3 || candidateBase.length < 3) return false;
    if (connectedBase != candidateBase) return false;
    return connectedSsid.trim().toLowerCase() !=
        candidateSsid.trim().toLowerCase();
  }
}

class AlarmDetectionMode {
  static const gps = 'gps';
  static const wifi = 'wifi';

  static String normalize(String? mode) {
    return mode == wifi ? wifi : gps;
  }

  static bool isWifi(String? mode) => normalize(mode) == wifi;

  static bool placeHasWifi(Map<String, dynamic>? place) {
    final networks = place?['wifiNetworks'];
    return networks is List && networks.isNotEmpty;
  }

  static Map<String, dynamic>? findPlaceForAlarm(
    Map<String, dynamic> alarm,
    List<Map<String, dynamic>> places,
  ) {
    final placeId = alarm['placeId']?.toString();
    final placeName = (alarm['place'] ?? alarm['locationName'])?.toString();

    for (final place in places) {
      if (placeId != null &&
          placeId.isNotEmpty &&
          place['id']?.toString() == placeId) {
        return place;
      }
    }

    if (placeName != null && placeName.isNotEmpty) {
      for (final place in places) {
        if (place['name']?.toString() == placeName) return place;
      }
    }

    return null;
  }

  /// Existing alarms do not have detectionMode. For those legacy alarms,
  /// preserve the previous behavior: places with registered Wi-Fi use Wi-Fi;
  /// otherwise GPS is used. New alarms explicitly save gps by default.
  static String resolve(
    Map<String, dynamic> alarm, {
    Map<String, dynamic>? place,
    List<Map<String, dynamic>>? places,
  }) {
    final rawMode = alarm['detectionMode']?.toString();
    final resolvedPlace =
        place ?? (places == null ? null : findPlaceForAlarm(alarm, places));

    if (rawMode == gps) return gps;
    if (rawMode == wifi) {
      return placeHasWifi(resolvedPlace) ? wifi : gps;
    }

    return placeHasWifi(resolvedPlace) ? wifi : gps;
  }

  static String forSave(String mode, Map<String, dynamic>? place) {
    if (mode == wifi && placeHasWifi(place)) return wifi;
    return gps;
  }

  static bool wifiMatches(
    Map<String, String>? connected,
    List<Map<String, dynamic>> registeredNetworks,
  ) {
    if (connected == null || registeredNetworks.isEmpty) return false;
    final connectedBssid = (connected['bssid'] ?? '').trim().toLowerCase();
    final connectedSsid = (connected['ssid'] ?? '').trim().toLowerCase();

    for (final network in registeredNetworks) {
      final bssid = (network['bssid'] ?? '').toString().trim().toLowerCase();
      if (bssid.isNotEmpty &&
          connectedBssid.isNotEmpty &&
          bssid == connectedBssid) {
        return true;
      }
    }

    for (final network in registeredNetworks) {
      final ssid = (network['ssid'] ?? '').toString().trim().toLowerCase();
      if (ssid.isNotEmpty &&
          connectedSsid.isNotEmpty &&
          ssid == connectedSsid) {
        return true;
      }
    }

    return false;
  }
}

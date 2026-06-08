class AppConfig {
  static bool isBetaVersion = true;

  // 지도 킬스위치 (Firestore admin_config/map_settings 에서 로드)
  static bool isGoogleMapsEnabled = true;
  static bool isNaverMapsEnabled = true;

  // 지오코딩 킬스위치 (맵 킬 시 자동으로 함께 차단됨)
  // false → Geocoding API 호출 차단
  static bool isGeocodingEnabled = true;

  // Bluetooth/device alarms are not production-ready yet.
  // Keep every user-facing and background execution path disabled.
  static const bool enableBluetoothFeatures = false;
}

class AppConfig {
  static bool isBetaVersion = true;

  // 지도 킬스위치 (Firestore admin_config/map_settings 에서 로드)
  static bool isGoogleMapsEnabled = true;
  static bool isNaverMapsEnabled = true;
  // OSM은 항상 활성화 (폴백용, 비용 없음)
}

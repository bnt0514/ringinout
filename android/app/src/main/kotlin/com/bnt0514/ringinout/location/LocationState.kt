package com.bnt0514.ringinout.location

/** 알람 트리거 타입 */
enum class AlarmTriggerType {
    ENTER, // 진입
    EXIT // 진출
}

/** Wi-Fi 네트워크 식별 데이터 */
data class WifiNetwork(
        val ssid: String,
        val bssid: String // MAC 주소 (AP 고유 식별)
)

/** v2 알람 장소 데이터 — 단일 지오펜스 (반경 = radiusMeters 그대로) */
data class AlarmPlace(
        val id: String,
        val name: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Float, // 실제 알람 반경 = 지오펜스 반경 (버퍼 없음)
        val triggerType: AlarmTriggerType,
        val enabled: Boolean = true,
        val isFirstOnly: Boolean = false,
        val startTimeMs: Long = 0L,
        val isTimeSpecified: Boolean = false,
        val wifiNetworks: List<WifiNetwork> = emptyList(), // Wi-Fi 기반 장소 감지용
) {
    /** 이 장소에 Wi-Fi 네트워크가 등록되어 있는지 */
    val hasWifi: Boolean get() = wifiNetworks.isNotEmpty()
}

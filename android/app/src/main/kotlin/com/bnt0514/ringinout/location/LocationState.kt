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

/** 블루투스 기기 식별 데이터 */
data class BluetoothDeviceInfo(
        val name: String,           // 기기 이름 (예: "My Car", "Galaxy Buds")
        val macAddress: String,     // MAC 주소 (고유 식별, 예: "AA:BB:CC:DD:EE:FF")
        val deviceType: Int = 0,    // 0=UNKNOWN, 1=CLASSIC, 2=LE, 3=DUAL
        val alias: String = "",     // 사용자 지정 별칭 (선택)
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
        val bluetoothDevices: List<BluetoothDeviceInfo> = emptyList(), // 블루투스 기반 장소 감지용
) {
    /** 이 장소에 Wi-Fi 네트워크가 등록되어 있는지 */
    val hasWifi: Boolean get() = wifiNetworks.isNotEmpty()

    /** 이 장소에 블루투스 기기가 등록되어 있는지 */
    val hasBluetooth: Boolean get() = bluetoothDevices.isNotEmpty()
}

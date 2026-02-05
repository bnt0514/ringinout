package com.example.ringinout.location

/**
 * 3단계 위치 모니터링 상태
 *
 * IDLE: 99% 시간 - 배터리 0% ARMED: 근접 감지 - 배터리 ~1% HOT: 고정밀 버스트 - 30~60초만
 */
enum class LocationState {
    IDLE, // 대기 모드: Activity Transition + 큰 지오펜스 + Passive 위치
    ARMED, // 근접 모드: 작은 지오펜스 + 저전력 위치 (30초 간격)
    HOT // 확정 모드: 고정밀 GPS (5초 간격) - 30~60초만
}

/** 알람 트리거 타입 */
enum class AlarmTriggerType {
    ENTER, // 진입
    EXIT // 진출
}

/** 알람 장소 데이터 */
data class AlarmPlace(
        val id: String,
        val name: String,
        val latitude: Double,
        val longitude: Double,
        val radiusMeters: Float, // 실제 알람 반경 (100~300m)
        val triggerType: AlarmTriggerType,
        val enabled: Boolean = true
) {
    // 큰 지오펜스 반경 (IDLE용) - 알람 반경의 5~10배
    val largeGeofenceRadius: Float
        get() = (radiusMeters * 7).coerceIn(500f, 2000f)

    // 작은 지오펜스 반경 (ARMED용) - 알람 반경의 1.5~2배
    val smallGeofenceRadius: Float
        get() = (radiusMeters * 1.5f).coerceIn(150f, 500f)
}

/** 위치 모니터링 이벤트 */
sealed class LocationEvent {
    // Activity Transition 이벤트
    data class ActivityChanged(val isMoving: Boolean) : LocationEvent()

    // 지오펜스 이벤트
    data class GeofenceTriggered(
            val placeId: String,
            val isEnter: Boolean,
            val isLargeGeofence: Boolean
    ) : LocationEvent()

    // 위치 업데이트
    data class LocationUpdated(val latitude: Double, val longitude: Double, val accuracy: Float) :
            LocationEvent()

    // 알람 확정
    data class AlarmConfirmed(val place: AlarmPlace, val triggerType: AlarmTriggerType) :
            LocationEvent()
}

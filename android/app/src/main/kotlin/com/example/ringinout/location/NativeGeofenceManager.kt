package com.example.ringinout.location

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

/**
 * 네이티브 GeofencingClient 관리자
 *
 * 큰 지오펜스 (IDLE용): 반경 500m~2km - 접근 감지 작은 지오펜스 (ARMED용): 반경 150~500m - 정밀 감지
 *
 * 배터리 소모: 거의 0% (네트워크 위치만 사용)
 */
class NativeGeofenceManager(private val context: Context) {

    companion object {
        private const val TAG = "NativeGeofence"
        const val ACTION_GEOFENCE = "com.example.ringinout.ACTION_GEOFENCE_EVENT"
        private const val REQUEST_CODE_LARGE = 2001
        private const val REQUEST_CODE_SMALL = 2002

        // 지오펜스 ID 접두사
        const val PREFIX_LARGE = "large_"
        const val PREFIX_SMALL = "small_"
    }

    private val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)
    private var largePendingIntent: PendingIntent? = null
    private var smallPendingIntent: PendingIntent? = null

    // 현재 등록된 지오펜스 ID
    private val registeredLargeGeofences = mutableSetOf<String>()
    private val registeredSmallGeofences = mutableSetOf<String>()

    /**
     * 큰 지오펜스 등록 (IDLE 모드용)
     *
     * @param places 알람 장소 목록
     * @param notificationResponsiveness 응답성 (ms) - 배터리와 반응속도 타협 (기본 60초)
     */
    fun registerLargeGeofences(
            places: List<AlarmPlace>,
            notificationResponsiveness: Int = 10000 // 10초 (지연 최소화)
    ) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        // 기존 큰 지오펜스 제거
        removeLargeGeofences()

        if (places.isEmpty()) {
            Log.d(TAG, "📭 등록할 장소 없음")
            return
        }

        val geofences =
                places.map { place ->
                    val geofenceId = "$PREFIX_LARGE${place.id}"
                    registeredLargeGeofences.add(geofenceId)

                    Geofence.Builder()
                            .setRequestId(geofenceId)
                            .setCircularRegion(
                                    place.latitude,
                                    place.longitude,
                                    place.largeGeofenceRadius
                            )
                            .setExpirationDuration(Geofence.NEVER_EXPIRE)
                            .setTransitionTypes(
                                    Geofence.GEOFENCE_TRANSITION_ENTER or
                                            Geofence.GEOFENCE_TRANSITION_EXIT
                            )
                            .setNotificationResponsiveness(notificationResponsiveness)
                            .build()
                }

        val request =
                GeofencingRequest.Builder()
                        .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                        .addGeofences(geofences)
                        .build()

        largePendingIntent = createPendingIntent(REQUEST_CODE_LARGE, isLarge = true)

        try {
            geofencingClient
                    .addGeofences(request, largePendingIntent!!)
                    .addOnSuccessListener {
                        Log.d(TAG, "✅ 큰 지오펜스 ${places.size}개 등록 완료")
                        places.forEach { place ->
                            Log.d(TAG, "   📍 ${place.name}: ${place.largeGeofenceRadius}m")
                        }
                    }
                    .addOnFailureListener { e -> Log.e(TAG, "❌ 큰 지오펜스 등록 실패: ${e.message}") }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /**
     * 작은 지오펜스 등록 (ARMED 모드용)
     *
     * @param place 특정 알람 장소
     * @param notificationResponsiveness 응답성 - 낮을수록 빠른 감지 (기본 5초)
     */
    fun registerSmallGeofence(
            place: AlarmPlace,
            notificationResponsiveness: Int = 3000 // 3초 (더 빠른 감지)
    ) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        val geofenceId = "$PREFIX_SMALL${place.id}"

        // 이미 등록되어 있으면 스킵
        if (registeredSmallGeofences.contains(geofenceId)) {
            Log.d(TAG, "⏭️ 작은 지오펜스 이미 등록됨: ${place.name}")
            return
        }

        val geofence =
                Geofence.Builder()
                        .setRequestId(geofenceId)
                        .setCircularRegion(
                                place.latitude,
                                place.longitude,
                                place.smallGeofenceRadius
                        )
                        .setExpirationDuration(600000) // 10분 후 자동 만료
                        .setTransitionTypes(
                                Geofence.GEOFENCE_TRANSITION_ENTER or
                                        Geofence.GEOFENCE_TRANSITION_EXIT or
                                        Geofence.GEOFENCE_TRANSITION_DWELL
                        )
                        .setLoiteringDelay(5000) // 5초 머물러야 DWELL
                        .setNotificationResponsiveness(notificationResponsiveness)
                        .build()

        val request =
                GeofencingRequest.Builder()
                        .setInitialTrigger(
                                GeofencingRequest.INITIAL_TRIGGER_ENTER or
                                        GeofencingRequest.INITIAL_TRIGGER_DWELL
                        )
                        .addGeofence(geofence)
                        .build()

        if (smallPendingIntent == null) {
            smallPendingIntent = createPendingIntent(REQUEST_CODE_SMALL, isLarge = false)
        }

        try {
            geofencingClient
                    .addGeofences(request, smallPendingIntent!!)
                    .addOnSuccessListener {
                        registeredSmallGeofences.add(geofenceId)
                        Log.d(TAG, "✅ 작은 지오펜스 등록: ${place.name} (${place.smallGeofenceRadius}m)")
                    }
                    .addOnFailureListener { e -> Log.e(TAG, "❌ 작은 지오펜스 등록 실패: ${e.message}") }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /** 작은 지오펜스 제거 (특정 장소) */
    fun removeSmallGeofence(placeId: String) {
        val geofenceId = "$PREFIX_SMALL$placeId"
        if (registeredSmallGeofences.contains(geofenceId)) {
            geofencingClient.removeGeofences(listOf(geofenceId)).addOnSuccessListener {
                registeredSmallGeofences.remove(geofenceId)
                Log.d(TAG, "🗑️ 작은 지오펜스 제거: $placeId")
            }
        }
    }

    /** 모든 작은 지오펜스 제거 */
    fun removeAllSmallGeofences() {
        if (registeredSmallGeofences.isNotEmpty()) {
            geofencingClient.removeGeofences(registeredSmallGeofences.toList())
                    .addOnSuccessListener {
                        Log.d(TAG, "🗑️ 모든 작은 지오펜스 제거: ${registeredSmallGeofences.size}개")
                        registeredSmallGeofences.clear()
                    }
        }
    }

    /** 큰 지오펜스 제거 */
    fun removeLargeGeofences() {
        if (registeredLargeGeofences.isNotEmpty()) {
            geofencingClient.removeGeofences(registeredLargeGeofences.toList())
                    .addOnSuccessListener {
                        Log.d(TAG, "🗑️ 큰 지오펜스 제거: ${registeredLargeGeofences.size}개")
                        registeredLargeGeofences.clear()
                    }
        }
    }

    /** 모든 지오펜스 제거 */
    fun removeAllGeofences() {
        removeLargeGeofences()
        removeAllSmallGeofences()
    }

    private fun createPendingIntent(requestCode: Int, isLarge: Boolean): PendingIntent {
        val intent =
                Intent(context, GeofenceBroadcastReceiver::class.java).apply {
                    action = ACTION_GEOFENCE
                    putExtra("isLarge", isLarge)
                }
        return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}

/** 지오펜스 이벤트 BroadcastReceiver */
class GeofenceBroadcastReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "GeofenceReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NativeGeofenceManager.ACTION_GEOFENCE) return

        val geofencingEvent = GeofencingEvent.fromIntent(intent)

        if (geofencingEvent == null) {
            Log.e(TAG, "❌ GeofencingEvent null")
            return
        }

        if (geofencingEvent.hasError()) {
            Log.e(TAG, "❌ 지오펜스 오류: ${geofencingEvent.errorCode}")
            return
        }

        val transitionType =
                when (geofencingEvent.geofenceTransition) {
                    Geofence.GEOFENCE_TRANSITION_ENTER -> "ENTER"
                    Geofence.GEOFENCE_TRANSITION_EXIT -> "EXIT"
                    Geofence.GEOFENCE_TRANSITION_DWELL -> "DWELL"
                    else -> "UNKNOWN"
                }

        val isEnter =
                geofencingEvent.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER ||
                        geofencingEvent.geofenceTransition == Geofence.GEOFENCE_TRANSITION_DWELL
        val isLarge = intent.getBooleanExtra("isLarge", true)

        geofencingEvent.triggeringGeofences?.forEach { geofence ->
            val geofenceId = geofence.requestId
            val placeId =
                    geofenceId
                            .removePrefix(NativeGeofenceManager.PREFIX_LARGE)
                            .removePrefix(NativeGeofenceManager.PREFIX_SMALL)

            Log.d(TAG, "📍 지오펜스 이벤트: $geofenceId, $transitionType, Large=$isLarge")

            // SmartLocationManager에 알림
            SmartLocationManager.getInstance(context)
                    ?.onGeofenceEvent(
                            placeId = placeId,
                            isEnter = isEnter,
                            isLargeGeofence = isLarge
                    )
        }
    }
}

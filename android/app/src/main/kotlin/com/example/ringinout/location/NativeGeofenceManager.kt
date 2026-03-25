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
 * v2 네이티브 GeofencingClient 관리자 — 단일 지오펜스
 *
 * 장소당 1개 지오펜스: 반경 = 사용자 설정 반경 R (버퍼 없음) ENTER + EXIT 모두 감시, 배터리 0% 이벤트 수신 → SmartLocationManager →
 * Flutter LMS로 전달
 */
class NativeGeofenceManager(private val context: Context) {

    companion object {
        private const val TAG = "NativeGeofence"
        const val ACTION_GEOFENCE = "com.example.ringinout.ACTION_GEOFENCE_EVENT"
        private const val REQUEST_CODE = 2001
    }

    private val geofencingClient: GeofencingClient = LocationServices.getGeofencingClient(context)
    private var pendingIntent: PendingIntent? = null

    // 현재 등록된 지오펜스 ID
    private val registeredGeofences = mutableSetOf<String>()

    /**
     * v2: 단일 지오펜스 등록 (반경 = 사용자 설정 R)
     * @param places 알람 장소 목록
     */
    fun registerGeofences(places: List<AlarmPlace>) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        removeAllGeofences()

        if (places.isEmpty()) {
            Log.d(TAG, "📭 등록할 장소 없음")
            return
        }

        val geofences =
                places.map { place ->
                    val geofenceId = place.id
                    registeredGeofences.add(geofenceId)

                    Geofence.Builder()
                            .setRequestId(geofenceId)
                            .setCircularRegion(
                                    place.latitude,
                                    place.longitude,
                                    place.radiusMeters // v2: 실제 반경 R 사용 (버퍼 없음)
                            )
                            .setExpirationDuration(Geofence.NEVER_EXPIRE)
                            .setTransitionTypes(
                                    Geofence.GEOFENCE_TRANSITION_ENTER or
                                            Geofence.GEOFENCE_TRANSITION_EXIT
                            )
                            .setNotificationResponsiveness(5000) // 5초 반응
                            .build()
                }

        // v2: INITIAL_TRIGGER_ENTER 사용 (Init Guard가 Flutter에서 5초간 억제)
        val request =
                GeofencingRequest.Builder()
                        .setInitialTrigger(
                                GeofencingRequest.INITIAL_TRIGGER_ENTER or
                                        GeofencingRequest.INITIAL_TRIGGER_EXIT
                        )
                        .addGeofences(geofences)
                        .build()

        pendingIntent = createPendingIntent(REQUEST_CODE)

        try {
            geofencingClient
                    .addGeofences(request, pendingIntent!!)
                    .addOnSuccessListener {
                        Log.d(TAG, "✅ 지오펜스 ${places.size}개 등록 완료")
                        places.forEach { place ->
                            Log.d(TAG, "   📍 ${place.name}: R=${place.radiusMeters.toInt()}m")
                        }
                    }
                    .addOnFailureListener { e -> Log.e(TAG, "❌ 지오펜스 등록 실패: ${e.message}") }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /** 모든 지오펜스 제거 */
    fun removeAllGeofences() {
        if (registeredGeofences.isNotEmpty()) {
            geofencingClient.removeGeofences(registeredGeofences.toList()).addOnSuccessListener {
                Log.d(TAG, "🗑️ 지오펜스 제거: ${registeredGeofences.size}개")
                registeredGeofences.clear()
            }
        }
    }

    private fun createPendingIntent(requestCode: Int): PendingIntent {
        val intent =
                Intent(context, GeofenceBroadcastReceiver::class.java).apply {
                    action = ACTION_GEOFENCE
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
                    else -> "UNKNOWN"
                }

        val isEnter = geofencingEvent.geofenceTransition == Geofence.GEOFENCE_TRANSITION_ENTER

        geofencingEvent.triggeringGeofences?.forEach { geofence ->
            val placeId = geofence.requestId // v2: ID = alarmId 그대로

            Log.d(TAG, "📍 지오펜스: $placeId $transitionType")

            SmartLocationManager.getInstance(context)
                    .onGeofenceEvent(placeId = placeId, isEnter = isEnter)
        }
    }
}

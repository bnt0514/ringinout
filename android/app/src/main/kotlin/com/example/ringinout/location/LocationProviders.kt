package com.example.ringinout.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.*

/**
 * Passive Location Provider - 무임승차 위치
 *
 * 다른 앱(지도, 네비, 카카오택시 등)이 위치를 요청하면 그 위치를 "무료로" 받아옴 (배터리 0%)
 */
class PassiveLocationProvider(private val context: Context) {

    companion object {
        private const val TAG = "PassiveLocation"
    }

    private val fusedLocationClient: FusedLocationProviderClient =
            LocationServices.getFusedLocationProviderClient(context)

    private var locationCallback: LocationCallback? = null
    private var onLocationUpdate: ((Location) -> Unit)? = null

    /** Passive 위치 수신 시작 배터리 소모: 0% (다른 앱 요청에 편승) */
    fun startPassiveUpdates(onUpdate: (Location) -> Unit) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        onLocationUpdate = onUpdate

        val request =
                LocationRequest.Builder(Priority.PRIORITY_PASSIVE, 0)
                        .setMinUpdateIntervalMillis(30000) // 최소 30초 간격
                        .setMinUpdateDistanceMeters(50f) // 최소 50m 이동
                        .build()

        locationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(result: LocationResult) {
                        result.lastLocation?.let { location ->
                            Log.d(
                                    TAG,
                                    "📍 Passive 위치: ${location.latitude}, ${location.longitude} " +
                                            "(정확도: ${location.accuracy}m)"
                            )
                            onLocationUpdate?.invoke(location)
                        }
                    }
                }

        try {
            fusedLocationClient.requestLocationUpdates(
                    request,
                    locationCallback!!,
                    Looper.getMainLooper()
            )
            Log.d(TAG, "✅ Passive 위치 수신 시작")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /** Passive 위치 수신 중지 */
    fun stopPassiveUpdates() {
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
            Log.d(TAG, "🛑 Passive 위치 수신 중지")
        }
        locationCallback = null
        onLocationUpdate = null
    }

    /** 마지막 알려진 위치 가져오기 (즉시, 배터리 0%) */
    fun getLastKnownLocation(onResult: (Location?) -> Unit) {
        if (!hasLocationPermission()) {
            onResult(null)
            return
        }

        try {
            fusedLocationClient.lastLocation
                    .addOnSuccessListener { location ->
                        Log.d(TAG, "📍 마지막 위치: ${location?.latitude}, ${location?.longitude}")
                        onResult(location)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "❌ 마지막 위치 가져오기 실패: ${e.message}")
                        onResult(null)
                    }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
            onResult(null)
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}

/**
 * 저전력 위치 Provider (ARMED 모드용)
 *
 * Network + WiFi 위치만 사용 배터리 소모: 매우 낮음
 */
class LowPowerLocationProvider(private val context: Context) {

    companion object {
        private const val TAG = "LowPowerLocation"
    }

    private val fusedLocationClient: FusedLocationProviderClient =
            LocationServices.getFusedLocationProviderClient(context)

    private var locationCallback: LocationCallback? = null
    private var onLocationUpdate: ((Location) -> Unit)? = null

    /**
     * 저전력 위치 업데이트 시작
     *
     * @param intervalMs 업데이트 간격 (밀리초)
     */
    fun startUpdates(intervalMs: Long = 30000, onUpdate: (Location) -> Unit) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        onLocationUpdate = onUpdate

        val request =
                LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, intervalMs)
                        .setMinUpdateIntervalMillis(intervalMs / 2)
                        .setMinUpdateDistanceMeters(20f)
                        .build()

        locationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(result: LocationResult) {
                        result.lastLocation?.let { location ->
                            Log.d(
                                    TAG,
                                    "📍 저전력 위치: ${location.latitude}, ${location.longitude} " +
                                            "(정확도: ${location.accuracy}m)"
                            )
                            onLocationUpdate?.invoke(location)
                        }
                    }
                }

        try {
            fusedLocationClient.requestLocationUpdates(
                    request,
                    locationCallback!!,
                    Looper.getMainLooper()
            )
            Log.d(TAG, "✅ 저전력 위치 업데이트 시작 (${intervalMs}ms 간격)")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /** 저전력 위치 업데이트 중지 */
    fun stopUpdates() {
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
            Log.d(TAG, "🛑 저전력 위치 업데이트 중지")
        }
        locationCallback = null
        onLocationUpdate = null
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}

/**
 * 고정밀 GPS Provider (HOT 모드용)
 *
 * GPS 사용 - 30~60초 버스트만! 배터리 소모: 높음 (하지만 짧은 시간만 사용)
 */
class HighAccuracyLocationProvider(private val context: Context) {

    companion object {
        private const val TAG = "HighAccuracyLocation"
    }

    private val fusedLocationClient: FusedLocationProviderClient =
            LocationServices.getFusedLocationProviderClient(context)

    private var locationCallback: LocationCallback? = null
    private var onLocationUpdate: ((Location) -> Unit)? = null

    /**
     * 고정밀 GPS 버스트 시작
     *
     * @param intervalMs 업데이트 간격 (밀리초) - 5초 권장
     * @param maxDurationMs 최대 지속 시간 - 자동 종료
     */
    fun startBurst(
            intervalMs: Long = 5000,
            maxDurationMs: Long = 60000,
            onUpdate: (Location) -> Unit
    ) {
        if (!hasLocationPermission()) {
            Log.e(TAG, "❌ 위치 권한 없음")
            return
        }

        onLocationUpdate = onUpdate

        val request =
                LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
                        .setMinUpdateIntervalMillis(intervalMs / 2)
                        .setDurationMillis(maxDurationMs) // 자동 만료
                        .setMaxUpdates(((maxDurationMs / intervalMs) + 1).toInt())
                        .build()

        locationCallback =
                object : LocationCallback() {
                    override fun onLocationResult(result: LocationResult) {
                        result.lastLocation?.let { location ->
                            Log.d(
                                    TAG,
                                    "🎯 고정밀 GPS: ${location.latitude}, ${location.longitude} " +
                                            "(정확도: ${location.accuracy}m)"
                            )
                            onLocationUpdate?.invoke(location)
                        }
                    }
                }

        try {
            fusedLocationClient.requestLocationUpdates(
                    request,
                    locationCallback!!,
                    Looper.getMainLooper()
            )
            Log.d(TAG, "🔥 고정밀 GPS 버스트 시작 (${intervalMs}ms 간격, 최대 ${maxDurationMs}ms)")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
        }
    }

    /** 고정밀 GPS 즉시 중지 */
    fun stopBurst() {
        locationCallback?.let { callback ->
            fusedLocationClient.removeLocationUpdates(callback)
            Log.d(TAG, "🛑 고정밀 GPS 버스트 중지")
        }
        locationCallback = null
        onLocationUpdate = null
    }

    /** 현재 위치 1회 요청 (빠른 응답) */
    fun getCurrentLocation(onResult: (Location?) -> Unit) {
        if (!hasLocationPermission()) {
            onResult(null)
            return
        }

        try {
            fusedLocationClient
                    .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                    .addOnSuccessListener { location ->
                        Log.d(TAG, "🎯 현재 위치: ${location?.latitude}, ${location?.longitude}")
                        onResult(location)
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "❌ 현재 위치 가져오기 실패: ${e.message}")
                        onResult(null)
                    }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 권한 오류: ${e.message}")
            onResult(null)
        }
    }

    private fun hasLocationPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }
}

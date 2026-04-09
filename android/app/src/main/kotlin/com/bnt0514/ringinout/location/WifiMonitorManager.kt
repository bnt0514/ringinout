package com.bnt0514.ringinout.location

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Wi-Fi 기반 장소 감지 매니저
 *
 * - ConnectivityManager.NetworkCallback으로 Wi-Fi 연결/해제 감지
 * - WIFI_STATE_CHANGED_ACTION으로 Wi-Fi 하드웨어 ON/OFF 감지
 * - 연속 시간 기반 디바운스: 15초 연속 끊김 → EXIT / 15초 연속 연결 → ENTER
 * - SmartLocationManager를 통해 Flutter로 신호 전달
 */
class WifiMonitorManager(private val context: Context) {

    companion object {
        private const val TAG = "WifiMonitorManager"

        // 디바운스: 15초 연속 끊김/연결 시 EXIT/ENTER 확정
        private const val DEBOUNCE_DURATION_MS = 15000L
    }

    // ========== 콜백 ==========

    /** Wi-Fi 기반 장소 진입/진출 콜백: (placeId, isEnter) */
    var onWifiPlaceEvent: ((String, Boolean) -> Unit)? = null

    /** Wi-Fi 하드웨어 ON/OFF 콜백: (isEnabled) */
    var onWifiHardwareChanged: ((Boolean) -> Unit)? = null

    // ========== 상태 ==========

    private var isMonitoring = false
    private var alarmPlaces = listOf<AlarmPlace>()

    /** 현재 연결된 Wi-Fi BSSID → 매칭된 placeId 목록 */
    private val connectedPlaceIds = mutableSetOf<String>()

    /** EXIT 디바운스: placeId → 단일 타이머 Runnable */
    private val mainHandler = Handler(Looper.getMainLooper())
    private val exitDebounceRunnables = mutableMapOf<String, Runnable>()

    /** ENTER 디바운스: placeId → 단일 타이머 Runnable */
    private val enterDebounceRunnables = mutableMapOf<String, Runnable>()

    /** 마지막으로 감지된 Wi-Fi 하드웨어 상태 */
    private var lastWifiEnabled: Boolean? = null

    // ========== 시스템 서비스 ==========

    private val connectivityManager by lazy {
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    }
    private val wifiManager by lazy {
        context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    }

    // ========== 시작/중지 ==========

    fun startMonitoring(places: List<AlarmPlace>) {
        if (isMonitoring) {
            // 이미 모니터링 중이면 장소만 업데이트
            updatePlaces(places)
            return
        }

        alarmPlaces = places.filter { it.wifiNetworks.isNotEmpty() }
        if (alarmPlaces.isEmpty()) {
            Log.d(TAG, "📶 Wi-Fi 등록된 장소 없음 — Wi-Fi 모니터링 건너뜀")
            return
        }

        Log.d(TAG, "📶 Wi-Fi 모니터링 시작: ${alarmPlaces.size}개 장소")
        for (place in alarmPlaces) {
            Log.d(TAG, "   - ${place.name}: ${place.wifiNetworks.map { it.ssid }}")
        }

        isMonitoring = true

        // 1. NetworkCallback 등록 (Wi-Fi 연결/해제 감지)
        registerNetworkCallback()

        // 2. Wi-Fi 하드웨어 ON/OFF 리시버 등록
        registerWifiStateReceiver()

        // 3. 현재 연결된 Wi-Fi 초기 체크
        checkCurrentWifiConnection()
    }

    fun stopMonitoring() {
        if (!isMonitoring) return

        Log.d(TAG, "📶 Wi-Fi 모니터링 중지")
        isMonitoring = false

        // 콜백 해제
        try {
            connectivityManager.unregisterNetworkCallback(networkCallback)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ NetworkCallback 해제 실패: ${e.message}")
        }

        // 리시버 해제
        try {
            context.unregisterReceiver(wifiStateReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ Wi-Fi 리시버 해제 실패: ${e.message}")
        }

        // 디바운스 타이머 모두 취소
        cancelAllExitDebounce()
        cancelAllEnterDebounce()
        connectedPlaceIds.clear()
    }

    fun updatePlaces(places: List<AlarmPlace>) {
        val wifiPlaces = places.filter { it.wifiNetworks.isNotEmpty() }
        alarmPlaces = wifiPlaces

        if (wifiPlaces.isEmpty() && isMonitoring) {
            Log.d(TAG, "📶 Wi-Fi 장소 없음 → 모니터링 중지")
            stopMonitoring()
            return
        }

        if (wifiPlaces.isNotEmpty() && !isMonitoring) {
            startMonitoring(places)
            return
        }

        Log.d(TAG, "📶 Wi-Fi 장소 업데이트: ${wifiPlaces.size}개")
        // 현재 연결 상태 재평가
        checkCurrentWifiConnection()
    }

    // ========== NetworkCallback (Wi-Fi 연결/해제) ==========

    private val networkCallback = object : ConnectivityManager.NetworkCallback(
            FLAG_INCLUDE_LOCATION_INFO
    ) {
        override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
        ) {
            if (!isMonitoring) return
            if (!networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) return

            val wifiInfo = networkCapabilities.transportInfo as? WifiInfo ?: return
            val bssid = wifiInfo.bssid ?: return
            val ssid = cleanSsid(wifiInfo.ssid)

            Log.d(TAG, "📶 Wi-Fi 연결: SSID=$ssid, BSSID=$bssid")

            mainHandler.post {
                handleWifiConnected(ssid, bssid)
            }
        }

        override fun onLost(network: Network) {
            if (!isMonitoring) return

            Log.d(TAG, "📶 Wi-Fi 연결 끊김")

            mainHandler.post {
                handleWifiDisconnected()
            }
        }
    }

    private fun registerNetworkCallback() {
        val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .build()
        try {
            connectivityManager.registerNetworkCallback(request, networkCallback)
            Log.d(TAG, "✅ NetworkCallback 등록 완료")
        } catch (e: Exception) {
            Log.e(TAG, "❌ NetworkCallback 등록 실패: ${e.message}")
        }
    }

    // ========== Wi-Fi 하드웨어 ON/OFF ==========

    private val wifiStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != WifiManager.WIFI_STATE_CHANGED_ACTION) return

            val state = intent.getIntExtra(
                    WifiManager.EXTRA_WIFI_STATE,
                    WifiManager.WIFI_STATE_UNKNOWN
            )

            val isEnabled = state == WifiManager.WIFI_STATE_ENABLED
            val isDisabled = state == WifiManager.WIFI_STATE_DISABLED

            if (isEnabled || isDisabled) {
                if (lastWifiEnabled != isEnabled) {
                    lastWifiEnabled = isEnabled
                    Log.d(TAG, "📶 Wi-Fi 하드웨어: ${if (isEnabled) "ON" else "OFF"}")

                    mainHandler.post {
                        onWifiHardwareChanged?.invoke(isEnabled)

                        if (isDisabled) {
                            // Wi-Fi OFF → 모든 Wi-Fi 기반 장소 즉시 EXIT 처리
                            handleWifiHardwareOff()
                        }
                    }
                }
            }
        }
    }

    private fun registerWifiStateReceiver() {
        val filter = IntentFilter(WifiManager.WIFI_STATE_CHANGED_ACTION)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(wifiStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(wifiStateReceiver, filter)
        }
        lastWifiEnabled = wifiManager.isWifiEnabled
        Log.d(TAG, "✅ Wi-Fi 상태 리시버 등록 (현재: ${if (lastWifiEnabled == true) "ON" else "OFF"})")
    }

    // ========== 연결 상태 처리 ==========

    private fun checkCurrentWifiConnection() {
        try {
            val activeNetwork = connectivityManager.activeNetwork
            val caps = activeNetwork?.let { connectivityManager.getNetworkCapabilities(it) }
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                val wifiInfo = caps.transportInfo as? WifiInfo
                if (wifiInfo != null) {
                    val bssid = wifiInfo.bssid ?: return
                    val ssid = cleanSsid(wifiInfo.ssid)
                    Log.d(TAG, "📶 현재 Wi-Fi: SSID=$ssid, BSSID=$bssid")
                    handleWifiConnected(ssid, bssid)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ 현재 Wi-Fi 확인 실패: ${e.message}")
        }
    }

    private fun handleWifiConnected(ssid: String, bssid: String) {
        // 매칭되는 장소 찾기
        val matchedPlaces = alarmPlaces.filter { place ->
            place.wifiNetworks.any { wifi ->
                wifi.bssid.equals(bssid, ignoreCase = true) ||
                        (wifi.bssid.isEmpty() && wifi.ssid.equals(ssid, ignoreCase = true))
            }
        }

        for (place in matchedPlaces) {
            // ★ Wi-Fi 연결 이벤트 → EXIT 타이머 취소 (아직 나가지 않았음)
            cancelExitDebounce(place.id)

            if (!connectedPlaceIds.contains(place.id)) {
                connectedPlaceIds.add(place.id)

                // ★ ENTER 타이머가 없으면 15초 후 ENTER 확정 예약
                if (!enterDebounceRunnables.containsKey(place.id)) {
                    Log.d(TAG, "🎯 Wi-Fi 연결 감지: ${place.name} (SSID=$ssid) → ENTER 15초 타이머 시작")
                    startEnterDebounce(place.id)
                } else {
                    // 이미 ENTER 타이머 진행 중 → 그대로 둘 (순간 끊김 후 재연결)
                    Log.d(TAG, "📶 Wi-Fi 재연결: ${place.name} — ENTER 타이머 진행 중")
                }
            } else {
                Log.d(TAG, "📶 Wi-Fi 이미 연결 중: ${place.name}")
            }
        }
    }

    private fun handleWifiDisconnected() {
        // ★ Wi-Fi 끊김 이벤트 → 모든 연결 장소에 대해:
        //   - ENTER 타이머 취소 (끊겼으므로 진입 아님)
        //   - EXIT 타이머 시작 (15초 후 EXIT 확정)
        val placesToCheck = connectedPlaceIds.toSet()
        for (placeId in placesToCheck) {
            cancelEnterDebounce(placeId)

            // EXIT 타이머가 없으면 시작 (이미 진행 중이면 그대로)
            if (!exitDebounceRunnables.containsKey(placeId)) {
                startExitDebounce(placeId)
            }
        }
    }

    private fun handleWifiHardwareOff() {
        // Wi-Fi OFF도 연결 끊김과 동일하게 디바운스 처리
        // (의도적 OFF / 실수 / 신호 불안정은 끊긴 시점에 구분 불가 → 동일 처리)
        Log.d(TAG, "📶 Wi-Fi 하드웨어 OFF → EXIT 타이머 시작 (${DEBOUNCE_DURATION_MS}ms)")
        handleWifiDisconnected()
    }

    // ========== EXIT 디바운스 (15초 연속 끊김 → EXIT) ==========

    private fun startExitDebounce(placeId: String) {
        val place = alarmPlaces.find { it.id == placeId }
        Log.d(TAG, "📶 EXIT 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): ${place?.name ?: placeId}")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable

            // 15초 만료 — 연속 끊김 확정 → EXIT
            connectedPlaceIds.remove(placeId)
            exitDebounceRunnables.remove(placeId)
            val p = alarmPlaces.find { it.id == placeId }
            Log.d(TAG, "🚨 Wi-Fi EXIT 확정 (${DEBOUNCE_DURATION_MS}ms 연속 끊김): ${p?.name ?: placeId}")
            onWifiPlaceEvent?.invoke(placeId, false)
        }

        exitDebounceRunnables[placeId] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelExitDebounce(placeId: String) {
        exitDebounceRunnables[placeId]?.let {
            mainHandler.removeCallbacks(it)
            val place = alarmPlaces.find { p -> p.id == placeId }
            Log.d(TAG, "📶 EXIT 타이머 취소 (재연결): ${place?.name ?: placeId}")
        }
        exitDebounceRunnables.remove(placeId)
    }

    private fun cancelAllExitDebounce() {
        for ((_, runnable) in exitDebounceRunnables) {
            mainHandler.removeCallbacks(runnable)
        }
        exitDebounceRunnables.clear()
    }

    // ========== ENTER 디바운스 (15초 연속 연결 → ENTER) ==========

    private fun startEnterDebounce(placeId: String) {
        val place = alarmPlaces.find { it.id == placeId }
        Log.d(TAG, "📶 ENTER 타이머 시작 (${DEBOUNCE_DURATION_MS}ms): ${place?.name ?: placeId}")

        val runnable = Runnable {
            if (!isMonitoring) return@Runnable

            // 15초 만료 — 연속 연결 확정 → ENTER
            enterDebounceRunnables.remove(placeId)
            val p = alarmPlaces.find { it.id == placeId }
            Log.d(TAG, "🚨 Wi-Fi ENTER 확정 (${DEBOUNCE_DURATION_MS}ms 연속 연결): ${p?.name ?: placeId}")
            onWifiPlaceEvent?.invoke(placeId, true)
        }

        enterDebounceRunnables[placeId] = runnable
        mainHandler.postDelayed(runnable, DEBOUNCE_DURATION_MS)
    }

    private fun cancelEnterDebounce(placeId: String) {
        enterDebounceRunnables[placeId]?.let {
            mainHandler.removeCallbacks(it)
            val place = alarmPlaces.find { p -> p.id == placeId }
            Log.d(TAG, "📶 ENTER 타이머 취소 (끊김): ${place?.name ?: placeId}")
        }
        enterDebounceRunnables.remove(placeId)
    }

    private fun cancelAllEnterDebounce() {
        for ((_, runnable) in enterDebounceRunnables) {
            mainHandler.removeCallbacks(runnable)
        }
        enterDebounceRunnables.clear()
    }

    // ========== 유틸리티 ==========

    /** SSID에서 따옴표 제거 (Android가 SSID를 "..." 형태로 반환) */
    private fun cleanSsid(rawSsid: String?): String {
        if (rawSsid == null) return ""
        return rawSsid.removePrefix("\"").removeSuffix("\"")
    }

    /** Wi-Fi 하드웨어 활성 상태 */
    val isWifiEnabled: Boolean get() = wifiManager.isWifiEnabled

    /** 상태 정보 */
    fun getStatus(): Map<String, Any?> {
        return mapOf(
                "isMonitoring" to isMonitoring,
                "wifiPlaceCount" to alarmPlaces.size,
                "connectedPlaceIds" to connectedPlaceIds.toList(),
                "wifiEnabled" to isWifiEnabled,
                "pendingExitDebounce" to exitDebounceRunnables.keys.toList(),
                "pendingEnterDebounce" to enterDebounceRunnables.keys.toList(),
        )
    }
}

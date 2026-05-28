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
        for ((_, r) in enterCancelGraceRunnables) mainHandler.removeCallbacks(r)
        enterCancelGraceRunnables.clear()
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
            var ssid = cleanSsid(wifiInfo.ssid)

            // ★ Android 12+ unknown ssid 대응: WifiManager.connectionInfo fallback
            if (ssid.isEmpty() || ssid == "<unknown ssid>") {
                @Suppress("DEPRECATION")
                val fallbackSsid = cleanSsid(wifiManager.connectionInfo?.ssid)
                if (fallbackSsid.isNotEmpty() && fallbackSsid != "<unknown ssid>") {
                    ssid = fallbackSsid
                    Log.d(TAG, "📶 SSID fallback (WifiManager): $ssid")
                }
            }

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
                    var ssid = cleanSsid(wifiInfo.ssid)
                    // ★ Android 12+ unknown ssid 대응: WifiManager.connectionInfo fallback
                    if (ssid.isEmpty() || ssid == "<unknown ssid>") {
                        @Suppress("DEPRECATION")
                        val fallbackSsid = cleanSsid(wifiManager.connectionInfo?.ssid)
                        if (fallbackSsid.isNotEmpty() && fallbackSsid != "<unknown ssid>") {
                            ssid = fallbackSsid
                            Log.d(TAG, "📶 SSID fallback (WifiManager): $ssid")
                        }
                    }
                    Log.d(TAG, "📶 현재 Wi-Fi: SSID=$ssid, BSSID=$bssid")
                    handleWifiConnected(ssid, bssid)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ 현재 Wi-Fi 확인 실패: ${e.message}")
        }
    }

    private fun handleWifiConnected(ssid: String, bssid: String) {
        val isUnknownSsid = ssid.isEmpty() || ssid == "<unknown ssid>"
        // 매칭되는 장소 찾기
        // ★ BSSID 우선 매칭, BSSID 미매칭 시 SSID로도 매칭 (같은 SSID 다른 AP 지원)
        val matchedPlaces = alarmPlaces.filter { place ->
            place.wifiNetworks.any { wifi ->
                val bssidMatch = wifi.bssid.isNotEmpty() &&
                        wifi.bssid.equals(bssid, ignoreCase = true)
                val ssidMatch = !isUnknownSsid &&
                        wifi.ssid.isNotEmpty() &&
                        wifi.ssid.equals(ssid, ignoreCase = true)
                bssidMatch || ssidMatch
            }
        }
        if (matchedPlaces.isEmpty()) {
            Log.d(TAG, "📶 Wi-Fi 매칭 없음: SSID=${if (isUnknownSsid) "<unknown>" else ssid}, BSSID=$bssid")
        }

        for (place in matchedPlaces) {
            // ★ Wi-Fi 연결 이벤트 → EXIT 타이머 취소 (아직 나가지 않았음)
            cancelExitDebounce(place.id)

            // ★ ENTER 취소 유예 타이머가 있으면 취소 (재연결로 유예 해소)
            enterCancelGraceRunnables[place.id]?.let {
                mainHandler.removeCallbacks(it)
                enterCancelGraceRunnables.remove(place.id)
                Log.d(TAG, "📶 ENTER 취소 유예 해소 (재연결): ${place.name}")
            }

            if (!connectedPlaceIds.contains(place.id)) {
                connectedPlaceIds.add(place.id)

                // ★ ENTER 타이머가 없으면 15초 후 ENTER 확정 예약
                if (!enterDebounceRunnables.containsKey(place.id)) {
                    Log.d(TAG, "🎯 Wi-Fi 연결 감지: ${place.name} (SSID=$ssid, BSSID=$bssid) → ENTER 15초 타이머 시작")
                    startEnterDebounce(place.id)
                } else {
                    // 이미 ENTER 타이머 진행 중 → 그대로 둘 (순간 끊김 후 재연결)
                    Log.d(TAG, "📶 Wi-Fi 재연결: ${place.name} — ENTER 타이머 진행 중 (유지)")
                }
            } else {
                Log.d(TAG, "📶 Wi-Fi 이미 연결 중: ${place.name}")
            }
        }
    }

    /** AP 로밍/순간 끊김 유예 타이머: placeId → Runnable */
    private val enterCancelGraceRunnables = mutableMapOf<String, Runnable>()

    /** ENTER 디바운스 취소 유예 시간 (ms) — 이 시간 안에 재연결 시 ENTER 타이머 유지 */
    private val ENTER_CANCEL_GRACE_MS = 5000L

    private fun handleWifiDisconnected() {
        // ★ Wi-Fi 끊김 이벤트 → 모든 연결 장소에 대해:
        //   - ENTER 타이머: 5초 유예 후 취소 (AP 로밍/순간 끊김 대응)
        //   - EXIT 타이머 시작 (15초 후 EXIT 확정)
        val placesToCheck = connectedPlaceIds.toSet()
        for (placeId in placesToCheck) {
            // ★ ENTER 타이머가 진행 중이면 즉시 취소 대신 5초 유예
            if (enterDebounceRunnables.containsKey(placeId) &&
                    !enterCancelGraceRunnables.containsKey(placeId)) {
                val place = alarmPlaces.find { it.id == placeId }
                Log.d(TAG, "📶 ENTER 취소 유예 시작 (${ENTER_CANCEL_GRACE_MS}ms): ${place?.name ?: placeId}")
                val grace = Runnable {
                    enterCancelGraceRunnables.remove(placeId)
                    // 유예 만료 후에도 여전히 ENTER 타이머 중 → 취소
                    if (enterDebounceRunnables.containsKey(placeId)) {
                        cancelEnterDebounce(placeId)
                        Log.d(TAG, "📶 ENTER 유예 만료 → ENTER 취소: ${place?.name ?: placeId}")
                    }
                }
                enterCancelGraceRunnables[placeId] = grace
                mainHandler.postDelayed(grace, ENTER_CANCEL_GRACE_MS)
            } else if (!enterDebounceRunnables.containsKey(placeId)) {
                // ENTER 타이머 없는 경우만 즉시 처리
            }

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

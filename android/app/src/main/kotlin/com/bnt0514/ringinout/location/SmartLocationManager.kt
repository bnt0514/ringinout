package com.bnt0514.ringinout.location

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.bnt0514.ringinout.AlarmFullscreenActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * ✅ v2 SmartLocationManager — 단일 지오펜스 + ActivityTransition
 *
 * 역할:
 * 1. 단일 지오펜스 등록/관리 (반경 R, ENTER+EXIT)
 * 2. ActivityTransition 이벤트 수신 → MethodChannel로 Flutter에 전달
 * 3. 지오펜스 이벤트 수신 → MethodChannel로 Flutter에 전달
 */
class SmartLocationManager private constructor(private val context: Context) {

    companion object {
        private const val TAG = "SmartLocationMgr"
        private const val PREFS_NAME = "smart_location_prefs"
        private const val KEY_ALARM_PLACES = "alarm_places"
        private const val KEY_PENDING_EVENTS = "pending_geofence_events"
        private const val KEY_PENDING_WIFI_EVENTS = "pending_wifi_events"
        private const val KEY_PENDING_BT_EVENTS = "pending_bluetooth_events"
        private const val KEY_PENDING_TRANSITIONS = "pending_activity_transitions"

        @Volatile private var instance: SmartLocationManager? = null

        fun getInstance(context: Context): SmartLocationManager {
            return instance
                    ?: synchronized(this) {
                        instance
                                ?: SmartLocationManager(context.applicationContext).also {
                                    instance = it
                                    it.restoreAlarmPlaces()
                                }
                    }
        }

        // Flutter MethodChannel (MainActivity에서 설정)
        var flutterChannel: MethodChannel? = null
    }

    // SharedPreferences
    private val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // 매니저
    private val nativeGeofenceManager = NativeGeofenceManager(context)
    private val activityTransitionManager = ActivityTransitionManager(context)
    private val wifiMonitorManager = WifiMonitorManager(context)
    private val bluetoothMonitorManager = BluetoothMonitorManager(context)

    // 알람 장소
    val alarmPlaces = mutableMapOf<String, AlarmPlace>()
    private var isMonitoring = false

    // ========== 모니터링 시작/중지 ==========

    /**
     * v2 모니터링 시작
     * - 단일 지오펜스 등록 (반경 R, ENTER+EXIT)
     * - ActivityTransition 감시 시작
     * - Wi-Fi 기반 장소 감지 시작
     */
    fun startMonitoring(places: List<AlarmPlace>, deviceAlarmMacs: Set<String> = emptySet()) {
        Log.d(TAG, "🚀 v2 모니터링 시작 (${places.size}개 장소, 독립 기기: ${deviceAlarmMacs.size}개)")

        // 장소 저장
        alarmPlaces.clear()
        places.forEach { alarmPlaces[it.id] = it }
        saveAlarmPlaces()

        // 단일 지오펜스 등록
        if (places.isNotEmpty()) {
            nativeGeofenceManager.registerGeofences(places)
        }

        // ActivityTransition 감시 시작
        startActivityTransitionMonitoring()

        // Wi-Fi 모니터링 시작
        startWifiMonitoring(places)

        // ✅ 블루투스 모니터링 시작
        startBluetoothMonitoring(places, deviceAlarmMacs)

        isMonitoring = true
        Log.d(TAG, "✅ v2 지오펜스 + ActivityTransition + Wi-Fi + Bluetooth 가동 완료")
    }

    /** 모니터링 중지 */
    fun stopMonitoring() {
        Log.d(TAG, "🛑 v2 모니터링 중지")
        nativeGeofenceManager.removeAllGeofences()
        activityTransitionManager.stopMonitoring()
        wifiMonitorManager.stopMonitoring()
        bluetoothMonitorManager.stopMonitoring()
        isMonitoring = false
    }

    /** 알람 장소 업데이트 */
    fun updateAlarmPlaces(places: List<AlarmPlace>, deviceAlarmMacs: Set<String> = emptySet()) {
        Log.d(TAG, "🔄 장소 업데이트 (${places.size}개, 독립 기기: ${deviceAlarmMacs.size}개)")

        alarmPlaces.clear()
        places.forEach { alarmPlaces[it.id] = it }
        saveAlarmPlaces()

        // Wi-Fi 장소 업데이트
        wifiMonitorManager.updatePlaces(places)

        // ✅ 블루투스 장소 + 독립 기기 MAC 업데이트
        bluetoothMonitorManager.updatePlaces(places, deviceAlarmMacs)

        // 지오펜스 재등록
        nativeGeofenceManager.registerGeofences(places)
    }

    // ========== 이벤트 수신 → Flutter로 전달 ==========

    /** v2: 지오펜스 이벤트 수신 → Flutter LMS.onGeofenceEvent()로 전달 */
    fun onGeofenceEvent(placeId: String, isEnter: Boolean) {
        val place = alarmPlaces[placeId]
        val placeName = place?.name ?: placeId

        Log.d(TAG, "📡 지오펜스: $placeName ${if (isEnter) "ENTER" else "EXIT"}")

        if (flutterChannel == null) {
            Log.e(TAG, "❌ flutterChannel null — 보류 이벤트 저장")
            savePendingGeofenceEvent(placeId, placeName, isEnter)
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "geofence",
                                "placeId" to placeId,
                                "placeName" to placeName,
                                "isEnter" to isEnter,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 지오펜스 신호 전달 완료")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Flutter 지오펜스 신호 전달 실패: ${e.message}")
                savePendingGeofenceEvent(placeId, placeName, isEnter)
            }
        }
    }

    // ========== ActivityTransition ==========

    /** ActivityTransition 감시 시작 */
    private fun startActivityTransitionMonitoring() {
        // BroadcastReceiver 콜백 설정
        ActivityTransitionReceiver.onTransitionCallback = { isMoving ->
            onActivityTransition(isMoving)
        }

        activityTransitionManager.startMonitoring { isMoving -> onActivityTransition(isMoving) }

        Log.d(TAG, "✅ ActivityTransition 감시 시작")
    }

    // ========== Wi-Fi 모니터링 ==========

    /** Wi-Fi 감시 시작 — 장소에 등록된 Wi-Fi 네트워크 감지 */
    private fun startWifiMonitoring(places: List<AlarmPlace>) {
        wifiMonitorManager.onWifiPlaceEvent = { placeId, isEnter ->
            onWifiEvent(placeId, isEnter)
        }
        wifiMonitorManager.onWifiHardwareChanged = { isEnabled ->
            onWifiHardwareEvent(isEnabled)
        }
        wifiMonitorManager.startMonitoring(places)
        Log.d(TAG, "✅ Wi-Fi 감시 시작")
    }

    /** Wi-Fi 장소 진입/진출 이벤트 → Flutter로 전달, 실패 시 네이티브 폴백 */
    private fun onWifiEvent(placeId: String, isEnter: Boolean) {
        val place = alarmPlaces[placeId]
        val placeName = place?.name ?: placeId

        Log.d(TAG, "📶 Wi-Fi: $placeName ${if (isEnter) "ENTER" else "EXIT"}")

        if (flutterChannel == null) {
            Log.e(TAG, "❌ flutterChannel null — Wi-Fi 이벤트 보류 저장 + 네이티브 폴백")
            savePendingWifiEvent(placeId, placeName, isEnter)
            triggerNativeAlarmFallback(placeId, placeName, isEnter)
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "wifi",
                                "placeId" to placeId,
                                "placeName" to placeName,
                                "isEnter" to isEnter,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 Wi-Fi 신호 전달 완료")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Flutter Wi-Fi 신호 전달 실패 — 네이티브 폴백: ${e.message}")
                savePendingWifiEvent(placeId, placeName, isEnter)
                triggerNativeAlarmFallback(placeId, placeName, isEnter)
            }
        }
    }

    // ========== ✅ 블루투스 모니터링 ==========

    /** 블루투스 감시 시작 — 장소에 등록된 BT 기기 감지 */
    private fun startBluetoothMonitoring(places: List<AlarmPlace>, deviceAlarmMacs: Set<String> = emptySet()) {
        bluetoothMonitorManager.onBluetoothPlaceEvent = { placeId, isEnter ->
            onBluetoothEvent(placeId, isEnter)
        }
        bluetoothMonitorManager.onBluetoothDeviceEvent = { macAddress, deviceName, isConnected ->
            onBluetoothDeviceEvent(macAddress, deviceName, isConnected)
        }
        bluetoothMonitorManager.startMonitoring(places, deviceAlarmMacs)
        Log.d(TAG, "✅ 블루투스 감시 시작 (장소: ${places.size}개, 독립 기기: ${deviceAlarmMacs.size}개)")
    }

    /** 블루투스 장소 진입/진출 이벤트 → Flutter로 전달 */
    private fun onBluetoothEvent(placeId: String, isEnter: Boolean) {
        val place = alarmPlaces[placeId]
        val placeName = place?.name ?: placeId

        Log.d(TAG, "🔵 Bluetooth: $placeName ${if (isEnter) "ENTER" else "EXIT"}")

        if (flutterChannel == null) {
            Log.e(TAG, "❌ flutterChannel null — BT 이벤트 보류 저장 + 네이티브 폴백")
            savePendingBluetoothEvent(placeId, placeName, isEnter)
            triggerNativeAlarmFallback(placeId, placeName, isEnter)
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "bluetooth",
                                "placeId" to placeId,
                                "placeName" to placeName,
                                "isEnter" to isEnter,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 BT 신호 전달 완료")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Flutter BT 신호 전달 실패 — 네이티브 폴백: ${e.message}")
                savePendingBluetoothEvent(placeId, placeName, isEnter)
                triggerNativeAlarmFallback(placeId, placeName, isEnter)
            }
        }
    }

    /** 독립형 기기 BT 연결/해제 이벤트 → Flutter로 전달 */
    private fun onBluetoothDeviceEvent(macAddress: String, deviceName: String, isConnected: Boolean) {
        Log.d(TAG, "🔵 BT Device: $deviceName ($macAddress) ${if (isConnected) "CONNECTED" else "DISCONNECTED"}")

        if (flutterChannel == null) {
            Log.w(TAG, "⚠️ flutterChannel null — BT Device 이벤트 무시")
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "bluetoothDevice",
                                "macAddress" to macAddress,
                                "deviceName" to deviceName,
                                "isConnected" to isConnected,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 BT Device 신호 전달 완료")
            } catch (e: Exception) {
                Log.e(TAG, "❌ BT Device 신호 전달 실패: ${e.message}")
            }
        }
    }

    /** Wi-Fi 하드웨어 ON/OFF 이벤트 → Flutter로 전달 */
    private fun onWifiHardwareEvent(isEnabled: Boolean) {
        Log.d(TAG, "📶 Wi-Fi 하드웨어: ${if (isEnabled) "ON" else "OFF"}")

        if (flutterChannel == null) {
            Log.w(TAG, "⚠️ flutterChannel null — Wi-Fi 하드웨어 이벤트 무시")
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "wifiHardware",
                                "isEnabled" to isEnabled,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 Wi-Fi 하드웨어 상태 전달")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Wi-Fi 하드웨어 상태 전달 실패: ${e.message}")
            }
        }
    }

    /** ActivityTransition 이벤트 → Flutter로 전달 */
    private fun onActivityTransition(isMoving: Boolean) {
        Log.d(TAG, "🚶 ActivityTransition: ${if (isMoving) "이동 시작" else "정지"}")

        if (flutterChannel == null) {
            Log.w(TAG, "⚠️ flutterChannel null — ActivityTransition 보류 이벤트 저장")
            savePendingActivityTransition(isMoving)
            return
        }

        val mainHandler = Handler(Looper.getMainLooper())
        mainHandler.post {
            try {
                flutterChannel?.invokeMethod(
                        "onNativeSignal",
                        mapOf(
                                "type" to "activityTransition",
                                "isMoving" to isMoving,
                                "timestamp" to System.currentTimeMillis()
                        )
                )
                Log.d(TAG, "✅ Flutter에 ActivityTransition 신호 전달")
            } catch (e: Exception) {
                Log.e(TAG, "❌ ActivityTransition 전달 실패: ${e.message}")
            }
        }
    }

    // ========== 상태 조회 ==========

    fun getStatus(): Map<String, Any?> {
        return mapOf(
                "state" to if (isMonitoring) "MONITORING" else "IDLE",
                "alarmCount" to alarmPlaces.size,
                "places" to alarmPlaces.values.map { it.name },
                "wifi" to wifiMonitorManager.getStatus(),
                "bluetooth" to bluetoothMonitorManager.getStatus(),
        )
    }

    // ========== 장소 영속성 ==========

    private fun saveAlarmPlaces() {
        try {
            val jsonArray = JSONArray()
            for (place in alarmPlaces.values) {
                val obj =
                        JSONObject().apply {
                            put("id", place.id)
                            put("name", place.name)
                            put("latitude", place.latitude)
                            put("longitude", place.longitude)
                            put("radiusMeters", place.radiusMeters.toDouble())
                            put("triggerType", place.triggerType.name)
                            put("enabled", place.enabled)
                            put("isFirstOnly", place.isFirstOnly)
                            put("startTimeMs", place.startTimeMs)
                            put("isTimeSpecified", place.isTimeSpecified)
                            // Wi-Fi 네트워크 직렬화
                            val wifiArray = JSONArray()
                            for (wifi in place.wifiNetworks) {
                                wifiArray.put(JSONObject().apply {
                                    put("ssid", wifi.ssid)
                                    put("bssid", wifi.bssid)
                                })
                            }
                            put("wifiNetworks", wifiArray)
                            // ✅ 블루투스 기기 직렬화
                            val btArray = JSONArray()
                            for (bt in place.bluetoothDevices) {
                                btArray.put(JSONObject().apply {
                                    put("name", bt.name)
                                    put("macAddress", bt.macAddress)
                                    put("deviceType", bt.deviceType)
                                    put("alias", bt.alias)
                                })
                            }
                            put("bluetoothDevices", btArray)
                        }
                jsonArray.put(obj)
            }
            prefs.edit().putString(KEY_ALARM_PLACES, jsonArray.toString()).apply()
            Log.d(TAG, "💾 장소 저장: ${alarmPlaces.size}개")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 장소 저장 실패: ${e.message}")
        }
    }

    private fun restoreAlarmPlaces() {
        try {
            val json = prefs.getString(KEY_ALARM_PLACES, null) ?: return
            val jsonArray = JSONArray(json)

            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val place =
                        AlarmPlace(
                                id = obj.getString("id"),
                                name = obj.getString("name"),
                                latitude = obj.getDouble("latitude"),
                                longitude = obj.getDouble("longitude"),
                                radiusMeters = obj.getDouble("radiusMeters").toFloat(),
                                triggerType =
                                        try {
                                            AlarmTriggerType.valueOf(obj.getString("triggerType"))
                                        } catch (e: Exception) {
                                            AlarmTriggerType.ENTER
                                        },
                                enabled = obj.optBoolean("enabled", true),
                                isFirstOnly = obj.optBoolean("isFirstOnly", false),
                                startTimeMs = obj.optLong("startTimeMs", 0L),
                                isTimeSpecified = obj.optBoolean("isTimeSpecified", false),
                                wifiNetworks = try {
                                    val wifiArray = obj.optJSONArray("wifiNetworks")
                                    if (wifiArray != null) {
                                        (0 until wifiArray.length()).map { i ->
                                            val w = wifiArray.getJSONObject(i)
                                            WifiNetwork(
                                                    ssid = w.optString("ssid", ""),
                                                    bssid = w.optString("bssid", "")
                                            )
                                        }
                                    } else emptyList()
                                } catch (e: Exception) { emptyList() },
                                // ✅ 블루투스 기기 역직렬화
                                bluetoothDevices = try {
                                    val btArray = obj.optJSONArray("bluetoothDevices")
                                    if (btArray != null) {
                                        (0 until btArray.length()).map { i ->
                                            val b = btArray.getJSONObject(i)
                                            BluetoothDeviceInfo(
                                                    name = b.optString("name", ""),
                                                    macAddress = b.optString("macAddress", ""),
                                                    deviceType = b.optInt("deviceType", 0),
                                                    alias = b.optString("alias", "")
                                            )
                                        }
                                    } else emptyList()
                                } catch (e: Exception) { emptyList() },
                        )
                alarmPlaces[place.id] = place
            }
            Log.d(TAG, "📦 장소 복구: ${alarmPlaces.size}개")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 장소 복구 실패: ${e.message}")
        }
    }

    // ========== 보류 이벤트 저장/전달 ==========

    /** Flutter 엔진이 없을 때 지오펜스 이벤트를 SharedPreferences에 저장 */
    private fun savePendingGeofenceEvent(placeId: String, placeName: String, isEnter: Boolean) {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            val event =
                    JSONObject().apply {
                        put("placeId", placeId)
                        put("placeName", placeName)
                        put("isEnter", isEnter)
                        put("timestamp", System.currentTimeMillis())
                    }
            pendingArray.put(event)

            prefs.edit().putString(KEY_PENDING_EVENTS, pendingArray.toString()).apply()
            Log.d(TAG, "💾 보류 이벤트 저장: $placeName (총 ${pendingArray.length()}개)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 이벤트 저장 실패: ${e.message}")
        }
    }

    /**
     * Flutter 엔진 재연결 시 보류된 이벤트 전달 MainActivity.configureFlutterEngine()에서 flutterChannel 설정 후 호출
     */
    fun deliverPendingGeofenceEvents() {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            if (pendingArray.length() == 0) {
                Log.d(TAG, "📬 보류 지오펜스 이벤트 없음")
            } else {
                Log.d(TAG, "📬 보류 지오펜스 이벤트 ${pendingArray.length()}개 전달 시작")

                val totalEvents = pendingArray.length()
                val mainHandler = Handler(Looper.getMainLooper())
                for (i in 0 until totalEvents) {
                    val event = pendingArray.getJSONObject(i)
                    val isLast = (i == totalEvents - 1)
                    mainHandler.postDelayed(
                            {
                                try {
                                    flutterChannel?.invokeMethod(
                                            "onNativeSignal",
                                            mapOf(
                                                    "type" to "geofence",
                                                    "placeId" to event.getString("placeId"),
                                                    "placeName" to event.getString("placeName"),
                                                    "isEnter" to event.getBoolean("isEnter"),
                                                    "timestamp" to event.getLong("timestamp"),
                                                    "wasPending" to true
                                            )
                                    )
                                    Log.d(TAG, "✅ 보류 이벤트 전달: ${event.getString("placeName")}")
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ 보류 이벤트 전달 실패: ${e.message}")
                                }
                                // ✅ 마지막 이벤트 전달 후 보류 목록 삭제 (조기 삭제 방지)
                                if (isLast) {
                                    prefs.edit().remove(KEY_PENDING_EVENTS).apply()
                                    Log.d(TAG, "🗑️ 보류 지오펜스 이벤트 목록 초기화")
                                }
                            },
                            (i * 500L) + 1000L // 1초 후부터 0.5초 간격
                    )
                }
            }

            // ✅ Wi-Fi 보류 이벤트도 전달
            deliverPendingWifiEvents()

            // ✅ Bluetooth 보류 이벤트도 전달
            deliverPendingBluetoothEvents()

            // ✅ ActivityTransition 보류 이벤트도 전달
            deliverPendingActivityTransitions()
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 이벤트 전달 실패: ${e.message}")
        }
    }

    // ========== Wi-Fi 보류 이벤트 저장/전달 ==========

    /** Flutter 엔진이 없을 때 Wi-Fi 이벤트를 SharedPreferences에 저장 */
    private fun savePendingWifiEvent(placeId: String, placeName: String, isEnter: Boolean) {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_WIFI_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            val event = JSONObject().apply {
                put("placeId", placeId)
                put("placeName", placeName)
                put("isEnter", isEnter)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArray.put(event)

            prefs.edit().putString(KEY_PENDING_WIFI_EVENTS, pendingArray.toString()).apply()
            Log.d(TAG, "💾 보류 Wi-Fi 이벤트 저장: $placeName ${if (isEnter) "ENTER" else "EXIT"} (총 ${pendingArray.length()}개)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 Wi-Fi 이벤트 저장 실패: ${e.message}")
        }
    }

    /** Flutter 엔진 재연결 시 보류된 Wi-Fi 이벤트 전달 */
    fun deliverPendingWifiEvents() {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_WIFI_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            if (pendingArray.length() == 0) {
                Log.d(TAG, "📬 보류 Wi-Fi 이벤트 없음")
                return
            }

            Log.d(TAG, "📬 보류 Wi-Fi 이벤트 ${pendingArray.length()}개 전달 시작")

            val totalEvents = pendingArray.length()
            val mainHandler = Handler(Looper.getMainLooper())
            for (i in 0 until totalEvents) {
                val event = pendingArray.getJSONObject(i)
                val isLast = (i == totalEvents - 1)
                mainHandler.postDelayed(
                        {
                            try {
                                flutterChannel?.invokeMethod(
                                        "onNativeSignal",
                                        mapOf(
                                                "type" to "wifi",
                                                "placeId" to event.getString("placeId"),
                                                "placeName" to event.getString("placeName"),
                                                "isEnter" to event.getBoolean("isEnter"),
                                                "timestamp" to event.getLong("timestamp"),
                                                "wasPending" to true
                                        )
                                )
                                Log.d(TAG, "✅ 보류 Wi-Fi 이벤트 전달: ${event.getString("placeName")}")
                            } catch (e: Exception) {
                                Log.e(TAG, "❌ 보류 Wi-Fi 이벤트 전달 실패: ${e.message}")
                            }
                            if (isLast) {
                                prefs.edit().remove(KEY_PENDING_WIFI_EVENTS).apply()
                                Log.d(TAG, "🗑️ 보류 Wi-Fi 이벤트 목록 초기화")
                            }
                        },
                        (i * 500L) + 500L
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 Wi-Fi 이벤트 전달 실패: ${e.message}")
        }
    }

    // ========== 네이티브 알람 폴백 (Flutter 없이 직접 AlarmFullscreenActivity 실행) ==========

    /**
     * Flutter 엔진이 죽었을 때 네이티브에서 직접 알람을 울리는 폴백.
     * 알람 place의 triggerType과 실제 이벤트(isEnter)가 일치할 때만 실행.
     */
    private fun triggerNativeAlarmFallback(placeId: String, placeName: String, isEnter: Boolean) {
        val place = alarmPlaces[placeId]
        if (place == null) {
            Log.w(TAG, "⚠️ 네이티브 폴백: 장소 정보 없음 ($placeId)")
            return
        }

        if (!place.enabled) {
            Log.d(TAG, "⏭️ 네이티브 폴백: 알람 비활성 — $placeName")
            return
        }

        // triggerType과 이벤트 방향 확인
        val shouldTrigger = when (place.triggerType) {
            AlarmTriggerType.ENTER -> isEnter
            AlarmTriggerType.EXIT -> !isEnter
        }

        if (!shouldTrigger) {
            Log.d(TAG, "⏭️ 네이티브 폴백: 트리거 방향 불일치 (place=${place.triggerType}, event=${if (isEnter) "ENTER" else "EXIT"})")
            return
        }

        // 쿨다운 체크 (FlutterSharedPreferences)
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val cooldownUntil = flutterPrefs.getLong("flutter.cooldown_until_$placeId", 0L)
            if (cooldownUntil > System.currentTimeMillis()) {
                Log.d(TAG, "⏭️ 네이티브 폴백: 쿨다운 중 — $placeName")
                return
            }

            val todayStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date())
            val triggeredDate = flutterPrefs.getString("flutter.alarm_triggered_date_$placeId", "")
            if (triggeredDate == todayStr) {
                Log.d(TAG, "⏭️ 네이티브 폴백: 오늘 이미 트리거됨 — $placeName")
                return
            }

            val isDisabled = flutterPrefs.getBoolean("flutter.alarm_disabled_$placeId", false)
            if (isDisabled) {
                Log.d(TAG, "⏭️ 네이티브 폴백: 알람 비활성 (SharedPrefs) — $placeName")
                return
            }
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ 네이티브 폴백: 쿨다운/트리거 체크 실패 — 계속 진행: ${e.message}")
        }

        Log.d(TAG, "🚨 네이티브 폴백 알람 발동! $placeName (${if (isEnter) "ENTER" else "EXIT"})")

        // 쿨다운 설정 (10초)
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit()
                    .putLong("flutter.cooldown_until_$placeId", System.currentTimeMillis() + 10000)
                    .apply()
            val todayStr = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).format(java.util.Date())
            flutterPrefs.edit()
                    .putString("flutter.alarm_triggered_date_$placeId", todayStr)
                    .apply()
        } catch (e: Exception) {
            Log.w(TAG, "⚠️ 네이티브 폴백: 쿨다운 설정 실패: ${e.message}")
        }

        // AlarmFullscreenActivity 직접 실행
        try {
            val alarmIdHash = placeId.hashCode()
            val title = placeName
            val message = if (isEnter) "지정 장소에 도착했습니다" else "지정 장소에서 벗어났습니다"

            val intent = Intent(context, AlarmFullscreenActivity::class.java).apply {
                putExtra("title", title)
                putExtra("message", message)
                putExtra("alarmId", alarmIdHash)
                putExtra("alarmKey", placeId)
                putExtra("placeId", placeId)
                putExtra("isRepeat", !place.isFirstOnly)
                putExtra("isBackgroundAlarm", true)
                addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }

            context.startActivity(intent)
            Log.d(TAG, "✅ 네이티브 폴백 알람 Activity 시작 완료")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 네이티브 폴백 알람 실패: ${e.message}")
        }
    }

    // ========== ActivityTransition 보류 이벤트 저장/전달 ==========

    /** flutterChannel null일 때 ActivityTransition 이벤트 저장 */
    private fun savePendingActivityTransition(isMoving: Boolean) {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_TRANSITIONS, "[]")
            val pendingArray = JSONArray(pendingJson)

            val event = JSONObject().apply {
                put("isMoving", isMoving)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArray.put(event)

            prefs.edit().putString(KEY_PENDING_TRANSITIONS, pendingArray.toString()).apply()
            Log.d(TAG, "💾 보류 ActivityTransition 저장: isMoving=$isMoving (총 ${pendingArray.length()}개)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 ActivityTransition 저장 실패: ${e.message}")
        }
    }

    /** 보류된 ActivityTransition 이벤트 전달 — 가장 최신 것만 전달 (이동/정지 상태) */
    private fun deliverPendingActivityTransitions() {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_TRANSITIONS, "[]")
            val pendingArray = JSONArray(pendingJson)

            if (pendingArray.length() == 0) return

            // ✅ 가장 최신 이벤트만 전달 (중간 전이 상태는 무의미)
            val lastEvent = pendingArray.getJSONObject(pendingArray.length() - 1)
            Log.d(TAG, "📬 보류 ActivityTransition ${pendingArray.length()}개 중 최신 1개 전달")

            val mainHandler = Handler(Looper.getMainLooper())
            mainHandler.postDelayed({
                try {
                    flutterChannel?.invokeMethod(
                            "onNativeSignal",
                            mapOf(
                                    "type" to "activityTransition",
                                    "isMoving" to lastEvent.getBoolean("isMoving"),
                                    "timestamp" to lastEvent.getLong("timestamp"),
                                    "wasPending" to true
                            )
                    )
                    Log.d(TAG, "✅ 보류 ActivityTransition 전달: isMoving=${lastEvent.getBoolean("isMoving")}")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ 보류 ActivityTransition 전달 실패: ${e.message}")
                }
                prefs.edit().remove(KEY_PENDING_TRANSITIONS).apply()
                Log.d(TAG, "🗑️ 보류 ActivityTransition 목록 초기화")
            }, 2000L) // 지오펜스 이벤트 이후 전달
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 ActivityTransition 전달 실패: ${e.message}")
        }
    }

    // ========== ✅ Bluetooth 보류 이벤트 저장/전달 ==========

    /** Flutter 엔진이 없을 때 BT 이벤트를 SharedPreferences에 저장 */
    private fun savePendingBluetoothEvent(placeId: String, placeName: String, isEnter: Boolean) {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_BT_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            val event = JSONObject().apply {
                put("placeId", placeId)
                put("placeName", placeName)
                put("isEnter", isEnter)
                put("timestamp", System.currentTimeMillis())
            }
            pendingArray.put(event)

            prefs.edit().putString(KEY_PENDING_BT_EVENTS, pendingArray.toString()).apply()
            Log.d(TAG, "💾 보류 BT 이벤트 저장: $placeName ${if (isEnter) "ENTER" else "EXIT"} (총 ${pendingArray.length()}개)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 BT 이벤트 저장 실패: ${e.message}")
        }
    }

    /** Flutter 엔진 재연결 시 보류된 BT 이벤트 전달 */
    fun deliverPendingBluetoothEvents() {
        try {
            val pendingJson = prefs.getString(KEY_PENDING_BT_EVENTS, "[]")
            val pendingArray = JSONArray(pendingJson)

            if (pendingArray.length() == 0) {
                Log.d(TAG, "📬 보류 BT 이벤트 없음")
                return
            }

            Log.d(TAG, "📬 보류 BT 이벤트 ${pendingArray.length()}개 전달 시작")

            val totalEvents = pendingArray.length()
            val mainHandler = Handler(Looper.getMainLooper())
            for (i in 0 until totalEvents) {
                val event = pendingArray.getJSONObject(i)
                val isLast = (i == totalEvents - 1)
                mainHandler.postDelayed(
                        {
                            try {
                                flutterChannel?.invokeMethod(
                                        "onNativeSignal",
                                        mapOf(
                                                "type" to "bluetooth",
                                                "placeId" to event.getString("placeId"),
                                                "placeName" to event.getString("placeName"),
                                                "isEnter" to event.getBoolean("isEnter"),
                                                "timestamp" to event.getLong("timestamp"),
                                                "wasPending" to true
                                        )
                                )
                                Log.d(TAG, "✅ 보류 BT 이벤트 전달: ${event.getString("placeName")}")
                            } catch (e: Exception) {
                                Log.e(TAG, "❌ 보류 BT 이벤트 전달 실패: ${e.message}")
                            }
                            if (isLast) {
                                prefs.edit().remove(KEY_PENDING_BT_EVENTS).apply()
                                Log.d(TAG, "🗑️ 보류 BT 이벤트 목록 초기화")
                            }
                        },
                        (i * 500L) + 1500L
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 BT 이벤트 전달 실패: ${e.message}")
        }
    }
}

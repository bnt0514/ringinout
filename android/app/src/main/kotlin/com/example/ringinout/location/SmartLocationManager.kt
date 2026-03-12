package com.example.ringinout.location

import android.content.Context
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log
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

    // 알람 장소
    val alarmPlaces = mutableMapOf<String, AlarmPlace>()
    private var isMonitoring = false

    // ========== 모니터링 시작/중지 ==========

    /**
     * v2 모니터링 시작
     * - 단일 지오펜스 등록 (반경 R, ENTER+EXIT)
     * - ActivityTransition 감시 시작
     */
    fun startMonitoring(places: List<AlarmPlace>) {
        Log.d(TAG, "🚀 v2 모니터링 시작 (${places.size}개 장소)")

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

        isMonitoring = true
        Log.d(TAG, "✅ v2 지오펜스 + ActivityTransition 가동 완료")
    }

    /** 모니터링 중지 */
    fun stopMonitoring() {
        Log.d(TAG, "🛑 v2 모니터링 중지")
        nativeGeofenceManager.removeAllGeofences()
        activityTransitionManager.stopMonitoring()
        isMonitoring = false
    }

    /** 알람 장소 업데이트 */
    fun updateAlarmPlaces(places: List<AlarmPlace>) {
        Log.d(TAG, "🔄 장소 업데이트 (${places.size}개)")

        alarmPlaces.clear()
        places.forEach { alarmPlaces[it.id] = it }
        saveAlarmPlaces()

        // 지오펜스 재등록
        nativeGeofenceManager.removeAllGeofences()
        if (places.isNotEmpty()) {
            nativeGeofenceManager.registerGeofences(places)
        }
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

    /** ActivityTransition 이벤트 → Flutter로 전달 */
    private fun onActivityTransition(isMoving: Boolean) {
        Log.d(TAG, "🚶 ActivityTransition: ${if (isMoving) "이동 시작" else "정지"}")

        if (flutterChannel == null) {
            Log.w(TAG, "⚠️ flutterChannel null — ActivityTransition 전달 불가")
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

            if (pendingArray.length() == 0) return

            Log.d(TAG, "📬 보류 이벤트 ${pendingArray.length()}개 전달 시작")

            val mainHandler = Handler(Looper.getMainLooper())
            for (i in 0 until pendingArray.length()) {
                val event = pendingArray.getJSONObject(i)
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
                        },
                        (i * 500L) + 1000L // 1초 후부터 0.5초 간격
                )
            }

            // 전달 후 보류 이벤트 삭제
            prefs.edit().remove(KEY_PENDING_EVENTS).apply()
            Log.d(TAG, "🗑️ 보류 이벤트 목록 초기화")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 보류 이벤트 전달 실패: ${e.message}")
        }
    }
}

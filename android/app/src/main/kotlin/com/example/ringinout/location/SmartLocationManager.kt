package com.example.ringinout.location

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*
import org.json.JSONArray
import org.json.JSONObject

/**
 * 🏆 SmartLocationManager - 3단계 적응형 위치 모니터링
 *
 * IDLE (99% 시간): 배터리 ~0%
 * - Activity Transition API (이동 시작 감지)
 * - 큰 지오펜스 (1~2km)
 * - Passive 위치
 *
 * ARMED (1~5% 시간): 배터리 ~1%
 * - 작은 지오펜스 (150~300m)
 * - 저전력 위치 (30초 간격)
 *
 * HOT (0.1% 시간): 30~60초만
 * - 고정밀 GPS (5초 간격)
 * - 알람 확정 후 즉시 종료
 */
class SmartLocationManager private constructor(private val context: Context) {

    companion object {
        private const val TAG = "SmartLocationManager"
        private const val PREFS_NAME = "smart_location_prefs"
        private const val KEY_ALARM_PLACES = "alarm_places"

        @Volatile private var instance: SmartLocationManager? = null

        fun getInstance(context: Context): SmartLocationManager {
            return instance
                    ?: synchronized(this) {
                        instance
                                ?: SmartLocationManager(context.applicationContext).also {
                                    instance = it
                                    // 앱이 죽었다가 깨어난 경우 저장된 장소 복구
                                    it.restoreAlarmPlaces()
                                }
                    }
        }

        // Flutter MethodChannel (MainActivity에서 설정)
        var flutterChannel: MethodChannel? = null
    }

    // SharedPreferences (영구 저장)
    private val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // 상태
    private var currentState: LocationState = LocationState.IDLE
    private val handler = Handler(Looper.getMainLooper())

    // 알람 장소 목록 (Flutter에서 동기화)
    private val alarmPlaces = mutableMapOf<String, AlarmPlace>()

    // 장소별 inside 상태 추적
    private val insideStatus = mutableMapOf<String, Boolean>()

    // 과거에 inside였던 적이 있는지 추적 (진출 오탐 방지)
    private val hasEverInside = mutableMapOf<String, Boolean>()

    // 현재 ARMED/HOT 대상 장소
    private var targetPlace: AlarmPlace? = null

    // 매니저들
    private val activityTransitionManager = ActivityTransitionManager(context)
    private val nativeGeofenceManager = NativeGeofenceManager(context)
    private val passiveLocationProvider = PassiveLocationProvider(context)
    private val lowPowerLocationProvider = LowPowerLocationProvider(context)
    private val highAccuracyLocationProvider = HighAccuracyLocationProvider(context)

    // 타임아웃 Runnable
    private var armedTimeoutRunnable: Runnable? = null
    private var hotTimeoutRunnable: Runnable? = null

    // 진입/진출 확정을 위한 연속 체크 카운터
    private var consecutiveInsideCount = 0
    private var consecutiveOutsideCount = 0
    private val CONFIRM_COUNT = 2 // 연속 2회로 확정

    // 진입 dwell 시간 (inside 유지) 추적
    private val insideSince = mutableMapOf<String, Long>()
    private val ENTRY_DWELL_MS = 15_000L

    // 빠른 진입 감지를 위한 ARMED 기준
    private val ARMED_ENTRY_FAST_ACCURACY_MAX = 40f
    private val ARMED_ENTRY_FAST_MARGIN = 10f

    // HOT 정확도 허용치 (진입은 조금 더 관대)
    private val HOT_ENTRY_ACCURACY_MAX = 120f
    private val HOT_EXIT_ACCURACY_MAX = 80f

    // 알람 확정 진행 중 (중복 방지)
    private var confirmationInProgress = false

    // 트리거된 알람 ID 기록 (중복 알람 방지)
    private val triggeredAlarms = mutableSetOf<String>()

    // IDLE 상태에서 inside exit 감시용 저전력 가드
    private var idleInsideGuardActive = false
    private val IDLE_INSIDE_GUARD_INTERVAL_MS = 20000L
    private var idleGuardLastLocation: Location? = null
    private var idleGuardLastTimestamp: Long = 0L

    // IDLE/HOT 센서 기반 흔들림 감지
    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var motionListener: SensorEventListener? = null
    private var motionSensorActive = false
    private val gravity = FloatArray(3)
    private var lastMotionTimestamp: Long = 0L
    private var lastShakeTimestamp: Long = 0L
    private val SHAKE_TRIGGER = 2.2f
    private val STILL_THRESHOLD = 0.6f
    private val SHAKE_COOLDOWN_MS = 1500L
    private val HOT_STILL_TO_IDLE_MS = 8000L

    /** 알람 장소를 SharedPreferences에 저장 (앱이 죽어도 복구 가능) */
    private fun saveAlarmPlaces() {
        try {
            val jsonArray = JSONArray()
            alarmPlaces.values.forEach { place ->
                val json =
                        JSONObject().apply {
                            put("id", place.id)
                            put("name", place.name)
                            put("latitude", place.latitude)
                            put("longitude", place.longitude)
                            put("radiusMeters", place.radiusMeters)
                            put("triggerType", place.triggerType.name)
                            put("enabled", place.enabled)
                        }
                jsonArray.put(json)
            }
            prefs.edit().putString(KEY_ALARM_PLACES, jsonArray.toString()).apply()
            Log.d(TAG, "💾 알람 장소 저장: ${alarmPlaces.size}개")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 알람 장소 저장 실패: $e")
        }
    }

    /** SharedPreferences에서 알람 장소 복구 (앱이 죽었다가 깨어날 때) */
    private fun restoreAlarmPlaces() {
        try {
            val json = prefs.getString(KEY_ALARM_PLACES, null) ?: return
            val jsonArray = JSONArray(json)

            alarmPlaces.clear()
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
                                        AlarmTriggerType.valueOf(obj.getString("triggerType")),
                                enabled = obj.optBoolean("enabled", true)
                        )
                alarmPlaces[place.id] = place
            }
            Log.d(TAG, "📂 알람 장소 복구: ${alarmPlaces.size}개")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 알람 장소 복구 실패: $e")
        }
    }

    /** 모니터링 시작 */
    fun startMonitoring(places: List<AlarmPlace>) {
        Log.d(TAG, "🚀 SmartLocationManager 시작: ${places.size}개 장소")

        // 알람 장소 저장 (메모리 + SharedPreferences)
        alarmPlaces.clear()
        places.forEach { place -> alarmPlaces[place.id] = place }
        saveAlarmPlaces() // 💾 영구 저장 (앱이 죽어도 복구 가능)

        if (places.isEmpty()) {
            Log.d(TAG, "📭 활성 알람 없음 - 모니터링 중지")
            stopMonitoring()
            return
        }

        // 초기 inside 상태 확인
        initializeInsideStatus()

        // IDLE 모드로 시작
        switchToIdle()
    }

    /** 모니터링 중지 */
    fun stopMonitoring() {
        Log.d(TAG, "🛑 SmartLocationManager 중지")

        cancelAllTimeouts()

        activityTransitionManager.stopMonitoring()
        nativeGeofenceManager.removeAllGeofences()
        passiveLocationProvider.stopPassiveUpdates()
        lowPowerLocationProvider.stopUpdates()
        highAccuracyLocationProvider.stopBurst()
        stopIdleMotionSensor()

        currentState = LocationState.IDLE
        alarmPlaces.clear()
        insideStatus.clear()
        hasEverInside.clear()
        targetPlace = null

        // 💾 저장된 알람 장소도 삭제
        prefs.edit().remove(KEY_ALARM_PLACES).apply()
    }

    /** 알람 장소 업데이트 (Flutter에서 호출) */
    fun updateAlarmPlaces(places: List<AlarmPlace>) {
        Log.d(TAG, "🔄 알람 장소 업데이트: ${places.size}개")

        alarmPlaces.clear()
        places.forEach { place -> alarmPlaces[place.id] = place }
        Log.d(TAG, "🧾 업데이트된 장소 IDs: ${places.joinToString { it.id }}")
        saveAlarmPlaces() // 💾 영구 저장 (앱이 죽어도 복구 가능)

        insideStatus.clear()
        hasEverInside.clear()
        insideSince.clear()
        Log.d(TAG, "🧹 insideStatus/hasEverInside/insideSince 초기화")

        // 새로운 장소 목록으로 업데이트 시 트리거 기록 초기화
        // (새 알람이 등록되면 다시 트리거될 수 있도록)
        triggeredAlarms.clear()
        Log.d(TAG, "🔄 트리거 기록 초기화 완료")

        // 큰 지오펜스 재등록
        nativeGeofenceManager.registerLargeGeofences(places)

        // 새로운 ID 기준으로 inside 상태 재계산
        initializeInsideStatus()
    }

    // ========== 상태 전환 ==========

    /** IDLE 모드로 전환 */
    private fun switchToIdle() {
        Log.d(TAG, "💤 IDLE 모드 전환")
        currentState = LocationState.IDLE

        cancelAllTimeouts()

        // ARMED/HOT 리소스 정리
        lowPowerLocationProvider.stopUpdates()
        idleInsideGuardActive = false
        highAccuracyLocationProvider.stopBurst()
        nativeGeofenceManager.removeAllSmallGeofences()

        targetPlace = null
        consecutiveInsideCount = 0
        consecutiveOutsideCount = 0
        insideSince.clear()
        hasEverInside.clear()
        idleGuardLastLocation = null
        idleGuardLastTimestamp = 0L
        lastMotionTimestamp = 0L
        lastShakeTimestamp = 0L

        // IDLE 리소스 시작
        activityTransitionManager.startMonitoring { isMoving -> onActivityTransition(isMoving) }

        nativeGeofenceManager.registerLargeGeofences(alarmPlaces.values.toList())

        passiveLocationProvider.startPassiveUpdates { location ->
            onPassiveLocationUpdate(location)
        }

        updateIdleInsideGuard()

        // FGS 종료
        HotModeForegroundService.stop(context)
    }

    /**
     * ARMED 모드로 전환
     *
     * @param place 근접 감지된 장소
     */
    private fun switchToArmed(place: AlarmPlace) {
        if (currentState == LocationState.HOT) {
            Log.d(TAG, "⚠️ HOT 모드 중에는 ARMED로 전환하지 않음")
            return
        }

        Log.d(TAG, "⚡ ARMED 모드 전환: ${place.name} (${place.triggerType})")
        currentState = LocationState.ARMED
        targetPlace = place

        idleInsideGuardActive = false
        insideSince.clear()
        hasEverInside.remove(place.id)

        cancelAllTimeouts()

        // IDLE 리소스 유지 (Activity Transition, 큰 지오펜스)
        // Passive 위치는 중지 (저전력 위치로 대체)
        passiveLocationProvider.stopPassiveUpdates()

        // 작은 지오펜스 등록
        nativeGeofenceManager.registerSmallGeofence(place)

        // 저전력 위치 시작 (30초 간격)
        val intervalMs = if (place.triggerType == AlarmTriggerType.ENTER) 10000L else 30000L
        Log.d(TAG, "⏱️ ARMED 저전력 interval: ${intervalMs}ms")
        lowPowerLocationProvider.startUpdates(intervalMs) { location ->
            onLowPowerLocationUpdate(location, place)
        }

        // 10분 타임아웃 설정
        armedTimeoutRunnable = Runnable {
            Log.d(TAG, "⏰ ARMED 타임아웃 - IDLE로 복귀")
            switchToIdle()
        }
        handler.postDelayed(armedTimeoutRunnable!!, 10 * 60 * 1000) // 10분
    }

    /**
     * HOT 모드로 전환 - 고정밀 GPS 버스트
     *
     * @param place 확정 대상 장소
     */
    private fun switchToHot(place: AlarmPlace) {
        Log.d(TAG, "🔥 HOT 모드 전환: ${place.name} (${place.triggerType})")
        currentState = LocationState.HOT
        targetPlace = place

        idleInsideGuardActive = false
        insideSince.remove(place.id)
        hasEverInside[place.id] = hasEverInside[place.id] ?: false
        lastMotionTimestamp = System.currentTimeMillis()

        cancelAllTimeouts()

        // ARMED 리소스 정리
        lowPowerLocationProvider.stopUpdates()

        // FGS 시작 (짧은 수명)
        HotModeForegroundService.start(context)

        // 고정밀 GPS 버스트 시작 (5초 간격, 최대 60초)
        Log.d(TAG, "🎯 HOT 버스트 시작: 5000ms, max 60000ms")
        highAccuracyLocationProvider.startBurst(intervalMs = 5000, maxDurationMs = 60000) { location
            ->
            onHighAccuracyLocationUpdate(location, place)
        }

        startIdleMotionSensor()

        // 60초 타임아웃 (강제 IDLE 복귀)
        hotTimeoutRunnable = Runnable {
            Log.d(TAG, "⏰ HOT 타임아웃 - IDLE로 강제 복귀")
            // HOT 타임아웃 시 IDLE로 복귀 (ARMED로 가면 무한 루프 가능)
            switchToIdle()
        }
        handler.postDelayed(hotTimeoutRunnable!!, 60 * 1000) // 60초
    }

    // ========== 이벤트 핸들러 ==========

    /** Activity Transition 이벤트 처리 */
    fun onActivityTransition(isMoving: Boolean) {
        Log.d(TAG, "🚶 Activity Transition: ${if (isMoving) "이동 시작" else "정지"}")

        if (isMoving) {
            // 이동 시작 → 진출 알람이 있는 장소 체크
            val exitAlarms =
                    alarmPlaces.values.filter { place ->
                        place.triggerType == AlarmTriggerType.EXIT && place.enabled
                    }

            if (exitAlarms.isNotEmpty()) {
                // 이동 시작 시 현재 위치 한번 확인하여 inside 상태 최신화 (정확도 향상)
                Log.d(TAG, "🏃 이동 시작 감지: 진출 알람 장소 체크 위해 위치 확인 요청")
                highAccuracyLocationProvider.getCurrentLocation { location ->
                    if (location != null) {
                        // 각 진출 알람 장소에 대해 거리 계산 및 inside 상태 갱신
                        exitAlarms.forEach { place ->
                            val distance =
                                    calculateDistance(
                                            location.latitude,
                                            location.longitude,
                                            place.latitude,
                                            place.longitude
                                    )
                            val isInside = distance <= place.radiusMeters
                            insideStatus[place.id] = isInside

                            Log.d(TAG, "📍 ${place.name}: ${distance.toInt()}m, inside=$isInside")

                            // 내부에 있으면 즉시 HOT 모드로 전환 (빠른 진출 감지)
                            if (isInside &&
                                            (currentState == LocationState.IDLE ||
                                                    currentState == LocationState.ARMED)
                            ) {
                                Log.d(TAG, "🔥 진출 알람 장소 내부에서 이동 시작 → HOT 모드 직행!")
                                switchToHot(place)
                                return@getCurrentLocation
                            }
                        }
                    } else {
                        // 위치 확인 실패 시 기존 로직대로 insideStatus 믿고 진행
                        val exitAlarmsInside = exitAlarms.filter { insideStatus[it.id] == true }
                        if (exitAlarmsInside.isNotEmpty() &&
                                        (currentState == LocationState.IDLE ||
                                                currentState == LocationState.ARMED)
                        ) {
                            Log.d(
                                    TAG,
                                    "🏃 진출 알람 장소(기존 상태)에서 이동 시작: ${exitAlarmsInside.map { it.name }}"
                            )
                            switchToHot(exitAlarmsInside.first())
                        }
                    }
                }
            } else {
                // 일반 이동 → Passive 위치로 근접 체크
                Log.d(TAG, "🚗 일반 이동 시작 - Passive 위치 감시 중")
            }
        } else {
            // 정지 → 상태에 따라 처리
            when (currentState) {
                LocationState.ARMED -> {
                    // 5분 후 IDLE로 복귀 (기존 타임아웃 유지)
                    Log.d(TAG, "🛑 정지 감지 - ARMED 유지 (타임아웃 대기)")
                }
                LocationState.HOT -> {
                    // HOT에서 정지 → 계속 확정 시도
                    Log.d(TAG, "🛑 HOT 모드 중 정지 - 확정 계속 시도")
                }
                LocationState.IDLE -> {
                    // IDLE에서 정지 → 유지
                }
            }
        }
    }

    /** 지오펜스 이벤트 처리 */
    fun onGeofenceEvent(placeId: String, isEnter: Boolean, isLargeGeofence: Boolean) {
        val place =
                alarmPlaces[placeId]
                        ?: run {
                            Log.w(TAG, "⚠️ 알 수 없는 장소: $placeId")
                            return
                        }

        Log.d(TAG, "📍 지오펜스: ${place.name}, Enter=$isEnter, Large=$isLargeGeofence")

        if (isLargeGeofence) {
            // 큰 지오펜스 이벤트
            if (isEnter && place.triggerType == AlarmTriggerType.ENTER) {
                if (insideStatus[place.id] == true) {
                    Log.d(TAG, "⏭️ 큰 지오펜스 ENTER 무시(이미 내부): ${place.name}")
                    return
                }
                if (insideStatus[place.id] == null) {
                    passiveLocationProvider.getLastKnownLocation { location ->
                        if (location != null) {
                            val distance =
                                    calculateDistance(
                                            location.latitude,
                                            location.longitude,
                                            place.latitude,
                                            place.longitude
                                    )
                            val isInside = distance <= place.radiusMeters
                            insideStatus[place.id] = isInside
                            if (isInside) {
                                hasEverInside[place.id] = true
                                Log.d(TAG, "⏭️ 큰 지오펜스 ENTER 무시(내부 확인됨): ${place.name}")
                                return@getLastKnownLocation
                            }
                        }
                        // 진입 알람 장소에 접근 중 → ARMED
                        switchToArmed(place)
                    }
                } else {
                    // 진입 알람 장소에 접근 중 → ARMED
                    switchToArmed(place)
                }
            } else if (!isEnter && place.triggerType == AlarmTriggerType.EXIT) {
                // 진출 알람 장소에서 멀어짐 (IDLE 상태여도 감지해야 함)
                // "큰 지오펜스를 나갔다" = "이미 확실히 진출했다"는 신호일 수 있음
                // 하지만 안전하게 ARMED/HOT 과정을 거쳐 확정 로직을 태움
                val everInside = hasEverInside[place.id] == true
                if ((currentState == LocationState.IDLE || currentState == LocationState.ARMED) &&
                                everInside
                ) {
                    Log.d(TAG, "⚡ 큰 지오펜스 진출 감지(IDLE/ARMED) → HOT으로 바로 전환하여 즉시 확정 시도")
                    switchToHot(place)
                } else if (!everInside) {
                    Log.d(TAG, "🚫 큰 지오펜스 진출 무시(inside 이력 없음): ${place.name}")
                }
            }
        } else {
            // 작은 지오펜스 이벤트 → HOT 전환 또는 확정
            when {
                isEnter && place.triggerType == AlarmTriggerType.ENTER -> {
                    if (insideStatus[place.id] == true) {
                        Log.d(TAG, "⏭️ 작은 지오펜스 ENTER 무시(이미 내부): ${place.name}")
                        return
                    }
                    // 진입 알람 - 작은 지오펜스 진입 → HOT 모드로 확정 시도
                    switchToHot(place)
                }
                !isEnter && place.triggerType == AlarmTriggerType.EXIT -> {
                    // 진출 알람 - 작은 지오펜스 진출 → HOT 모드로 확정 시도
                    switchToHot(place)
                }
            }
        }
    }

    /** Passive 위치 업데이트 처리 (IDLE 모드) */
    private fun onPassiveLocationUpdate(location: Location) {
        if (currentState != LocationState.IDLE) return

        // 알람 장소와의 거리 계산
        alarmPlaces.values.forEach { place ->
            val distance =
                    calculateDistance(
                            location.latitude,
                            location.longitude,
                            place.latitude,
                            place.longitude
                    )
            val isInside = distance <= place.radiusMeters

            // 큰 지오펜스 반경 이내 접근 시 ARMED
            if (distance < place.largeGeofenceRadius) {
                Log.d(TAG, "📍 Passive: ${place.name} ${distance.toInt()}m 접근")

                when (place.triggerType) {
                    AlarmTriggerType.ENTER -> {
                        if (isInside) {
                            insideStatus[place.id] = true
                            hasEverInside[place.id] = true
                            Log.d(TAG, "⏭️ Passive 진입 무시(이미 내부): ${place.name}")
                        } else {
                            // 진입 알람 - 접근 중이면 ARMED
                            switchToArmed(place)
                        }
                    }
                    AlarmTriggerType.EXIT -> {
                        // 진출 알람 - inside 상태 업데이트
                        if (isInside) {
                            insideStatus[place.id] = true
                            hasEverInside[place.id] = true
                        }
                    }
                }
            }
        }

        updateIdleInsideGuard()
    }

    /** IDLE 상태에서 inside exit 감시용 저전력 위치 업데이트 처리 */
    private fun onIdleInsideLowPowerLocationUpdate(location: Location) {
        if (currentState != LocationState.IDLE) return

        val exitPlaces =
                alarmPlaces.values.filter { place ->
                    place.triggerType == AlarmTriggerType.EXIT && place.enabled
                }

        if (exitPlaces.isEmpty()) {
            updateIdleInsideGuard()
            return
        }

        val candidates = mutableListOf<Pair<AlarmPlace, Float>>()

        exitPlaces.forEach { place ->
            val distance =
                    calculateDistance(
                            location.latitude,
                            location.longitude,
                            place.latitude,
                            place.longitude
                    )
            val isInside = distance <= place.radiusMeters
            val wasInside = insideStatus[place.id] ?: false

            insideStatus[place.id] = isInside
            if (isInside) {
                hasEverInside[place.id] = true
            }

            if (wasInside && !isInside) {
                candidates.add(place to distance)
            }
        }

        val movementDetected = detectIdleGuardMovement(location)
        if (movementDetected) {
            val insideExitPlaces =
                    exitPlaces.filter { place ->
                        insideStatus[place.id] == true && !triggeredAlarms.contains(place.id)
                    }
            if (insideExitPlaces.isNotEmpty()) {
                val nearest =
                        insideExitPlaces.minByOrNull { place ->
                            calculateDistance(
                                    location.latitude,
                                    location.longitude,
                                    place.latitude,
                                    place.longitude
                            )
                        }
                if (nearest != null) {
                    Log.d(TAG, "🏃 IDLE inside-guard: 이동 감지 → HOT 전환 (${nearest.name})")
                    switchToHot(nearest)
                    return
                }
            }
        }

        if (candidates.isNotEmpty()) {
            val nearest = candidates.minByOrNull { it.second }?.first
            if (nearest != null) {
                Log.d(TAG, "🚪 IDLE inside-guard: 진출 감지 가능 → HOT 전환 (${nearest.name})")
                switchToHot(nearest)
                return
            }
        }

        updateIdleInsideGuard()
    }

    private fun detectIdleGuardMovement(location: Location): Boolean {
        val lastLocation = idleGuardLastLocation
        val now = System.currentTimeMillis()
        val lastTime = idleGuardLastTimestamp

        idleGuardLastLocation = location
        idleGuardLastTimestamp = now

        if (lastLocation == null || lastTime == 0L) {
            return false
        }

        val movedMeters =
                calculateDistance(
                        lastLocation.latitude,
                        lastLocation.longitude,
                        location.latitude,
                        location.longitude
                )
        val dtSeconds = ((now - lastTime).coerceAtLeast(1L)) / 1000.0f
        val speedMps = movedMeters / dtSeconds

        val movementDetected = movedMeters >= 12f || speedMps >= 1.0f
        if (movementDetected) {
            Log.d(
                    TAG,
                    "🏃 IDLE inside-guard 이동 감지: ${movedMeters.toInt()}m, ${String.format("%.2f", speedMps)}m/s"
            )
        }
        return movementDetected
    }

    /** 저전력 위치 업데이트 처리 (ARMED 모드) */
    private fun onLowPowerLocationUpdate(location: Location, targetPlace: AlarmPlace) {
        if (currentState != LocationState.ARMED) return

        val distance =
                calculateDistance(
                        location.latitude,
                        location.longitude,
                        targetPlace.latitude,
                        targetPlace.longitude
                )

        val wasInside = insideStatus[targetPlace.id] ?: false
        val isInside = distance <= targetPlace.radiusMeters
        insideStatus[targetPlace.id] = isInside
        if (isInside) {
            hasEverInside[targetPlace.id] = true
        }

        Log.d(
                TAG,
                "📍 저전력 위치: ${targetPlace.name}까지 ${distance.toInt()}m (acc=${location.accuracy.toInt()}m, inside=$isInside)"
        )

        if (targetPlace.triggerType == AlarmTriggerType.ENTER && isInside) {
            if (location.accuracy <= ARMED_ENTRY_FAST_ACCURACY_MAX &&
                            distance <= targetPlace.radiusMeters + ARMED_ENTRY_FAST_MARGIN
            ) {
                Log.d(TAG, "⚡ ARMED 진입 근접 감지(정확도 양호) → HOT 전환: ${targetPlace.name}")
                switchToHot(targetPlace)
                return
            }
        }

        // 작은 지오펜스 반경 접근 시 HOT 모드
        if (distance < targetPlace.smallGeofenceRadius) {
            if (targetPlace.triggerType == AlarmTriggerType.ENTER && wasInside) {
                Log.d(TAG, "⏭️ ARMED 진입 무시(이미 내부): ${targetPlace.name}")
                return
            }
            switchToHot(targetPlace)
        }
    }

    /** 고정밀 GPS 업데이트 처리 (HOT 모드) */
    private fun onHighAccuracyLocationUpdate(location: Location, place: AlarmPlace) {
        if (currentState != LocationState.HOT) return

        // 이미 알람 확정 진행 중이면 무시
        if (confirmationInProgress) {
            Log.d(TAG, "⏳ 알람 확정 진행 중 - GPS 업데이트 무시")
            return
        }

        // 이미 트리거된 알람이면 무시
        if (triggeredAlarms.contains(place.id)) {
            Log.d(TAG, "⏭️ 이미 트리거된 알람 - 무시: ${place.name}")
            switchToIdle() // HOT 모드 종료
            return
        }

        // 정확도 필터: 정확도가 너무 낮으면(오차가 크면) 판정 유보
        val maxAccuracy =
                if (place.triggerType == AlarmTriggerType.ENTER) {
                    HOT_ENTRY_ACCURACY_MAX
                } else {
                    HOT_EXIT_ACCURACY_MAX
                }

        if (location.accuracy > maxAccuracy) {
            Log.w(TAG, "⚠️ GPS 정확도 낮음(${location.accuracy}m) - 판정 유보")
            return
        }

        val distance =
                calculateDistance(
                        location.latitude,
                        location.longitude,
                        place.latitude,
                        place.longitude
                )

        // 정확도를 고려한 보수적 판단 (진입은 더 깊숙이, 진출은 더 확실히 멀어져야 함)
        // distance - accuracy <= radius : 확실히 안에 있음
        // distance + accuracy > radius : 확실히 밖에 있음

        // 하지만 너무 보수적이면 감지가 늦어지므로, 적절한 타협점 사용
        // 여기서는 그냥 distance만 쓰되, 위에서 accuracy 80m 컷을 했으므로 어느정도 신뢰 가능

        val isInside = distance <= place.radiusMeters
        val previousInside = insideStatus[place.id] ?: false
        if (isInside) {
            hasEverInside[place.id] = true
        }
        Log.d(TAG, "🧭 hasEverInside[${place.id}]=${hasEverInside[place.id]}")

        Log.d(
                TAG,
                "🎯 고정밀 GPS: ${place.name}까지 ${distance.toInt()}m (오차 ${location.accuracy.toInt()}m), inside=$isInside, trigger=${place.triggerType}"
        )

        // 연속 체크로 확정
        when (place.triggerType) {
            AlarmTriggerType.ENTER -> {
                if (isInside) {
                    if (insideSince[place.id] == null) {
                        insideSince[place.id] = System.currentTimeMillis()
                    }
                    val dwellMs = System.currentTimeMillis() - (insideSince[place.id] ?: 0L)
                    consecutiveInsideCount++
                    consecutiveOutsideCount = 0
                    Log.d(
                            TAG,
                            "📊 진입 체크: count=$consecutiveInsideCount/$CONFIRM_COUNT, previousInside=$previousInside"
                    )

                    // 진입 확정: 연속 N회 inside 확인 (previousInside 조건 제거 - 이미 ARMED에서 체크됨)
                    if (consecutiveInsideCount >= CONFIRM_COUNT && dwellMs >= ENTRY_DWELL_MS) {
                        // 진입 확정!
                        Log.d(TAG, "✅ 진입 조건 충족!")
                        confirmAlarm(place, AlarmTriggerType.ENTER)
                    }
                } else {
                    consecutiveOutsideCount++
                    consecutiveInsideCount = 0
                    insideSince.remove(place.id)
                }
            }
            AlarmTriggerType.EXIT -> {
                val everInside = hasEverInside[place.id] == true
                if (!everInside) {
                    Log.d(TAG, "🚫 진출 체크 무시(inside 이력 없음): ${place.name}")
                    consecutiveOutsideCount = 0
                    return
                }
                if (!isInside) {
                    consecutiveOutsideCount++
                    consecutiveInsideCount = 0
                    Log.d(
                            TAG,
                            "📊 진출 체크: count=$consecutiveOutsideCount/$CONFIRM_COUNT, previousInside=$previousInside"
                    )

                    // 진출 확정: 연속 N회 outside 확인 (previousInside 조건 제거)
                    if (consecutiveOutsideCount >= CONFIRM_COUNT) {
                        // 진출 확정!
                        Log.d(TAG, "✅ 진출 조건 충족!")
                        confirmAlarm(place, AlarmTriggerType.EXIT)
                    }
                } else {
                    consecutiveInsideCount++
                    consecutiveOutsideCount = 0
                }
            }
        }

        // inside 상태 업데이트
        insideStatus[place.id] = isInside
    }

    /** 알람 확정 및 트리거 */
    private fun confirmAlarm(place: AlarmPlace, triggerType: AlarmTriggerType) {
        // 중복 방지
        if (confirmationInProgress) {
            Log.d(TAG, "⚠️ 이미 알람 확정 진행 중")
            return
        }
        confirmationInProgress = true

        Log.d(TAG, "🚨 알람 확정! ${place.name} - ${triggerType.name}")

        // 이 알람을 트리거됨으로 표시 (같은 알람 재트리거 방지)
        triggeredAlarms.add(place.id)
        Log.d(TAG, "🔕 알람 트리거 기록: ${place.id}")

        // 카운터 리셋
        consecutiveInsideCount = 0
        consecutiveOutsideCount = 0

        // Flutter에 알람 전달
        handler.post {
            flutterChannel?.invokeMethod(
                    "onAlarmTriggered",
                    mapOf(
                            "placeId" to place.id,
                            "placeName" to place.name,
                            "triggerType" to triggerType.name.lowercase(),
                            "latitude" to place.latitude,
                            "longitude" to place.longitude
                    )
            )
        }

        // HOT 모드 종료 → IDLE로 복귀
        highAccuracyLocationProvider.stopBurst()

        // 잠시 대기 후 IDLE 복귀 (알람 처리 시간 확보)
        handler.postDelayed(
                {
                    confirmationInProgress = false
                    switchToIdle()
                },
                3000
        )
    }

    // ========== 유틸리티 ==========

    /** 초기 inside 상태 확인 */
    private fun initializeInsideStatus() {
        passiveLocationProvider.getLastKnownLocation { location ->
            location?.let { loc ->
                alarmPlaces.values.forEach { place ->
                    val distance =
                            calculateDistance(
                                    loc.latitude,
                                    loc.longitude,
                                    place.latitude,
                                    place.longitude
                            )
                    insideStatus[place.id] = distance <= place.radiusMeters
                    if (insideStatus[place.id] == true) {
                        hasEverInside[place.id] = true
                    }
                    Log.d(
                            TAG,
                            "📍 초기 상태: ${place.name} - inside=${insideStatus[place.id]}, dist=${distance.toInt()}m"
                    )
                }
            }
            if (location == null) {
                Log.w(TAG, "⚠️ 초기 위치 없음 - inside 상태 미결정")
            }
            updateIdleInsideGuard()
        }
    }

    /** IDLE 상태에서 inside exit 감시 가드 시작/중지 */
    private fun updateIdleInsideGuard() {
        if (currentState != LocationState.IDLE) return

        val hasInsideExit =
                alarmPlaces.values.any { place ->
                    place.triggerType == AlarmTriggerType.EXIT &&
                            place.enabled &&
                            insideStatus[place.id] == true
                }

        if (hasInsideExit && !idleInsideGuardActive) {
            Log.d(TAG, "🛡️ IDLE inside-guard 시작 (저전력 ${IDLE_INSIDE_GUARD_INTERVAL_MS}ms)")
            lowPowerLocationProvider.startUpdates(IDLE_INSIDE_GUARD_INTERVAL_MS) { location ->
                onIdleInsideLowPowerLocationUpdate(location)
            }
            idleInsideGuardActive = true
            startIdleMotionSensor()
        } else if (!hasInsideExit && idleInsideGuardActive) {
            Log.d(TAG, "🛡️ IDLE inside-guard 종료")
            lowPowerLocationProvider.stopUpdates()
            idleInsideGuardActive = false
            stopIdleMotionSensor()
        }
    }

    private fun startIdleMotionSensor() {
        if (motionSensorActive) return

        if (sensorManager == null) {
            sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        }
        if (accelerometer == null) {
            accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        }
        val accel = accelerometer
        if (accel == null) {
            Log.w(TAG, "⚠️ 가속도 센서 없음 - 흔들림 감지 비활성")
            return
        }

        motionListener =
                object : SensorEventListener {
                    override fun onSensorChanged(event: SensorEvent) {
                        val now = System.currentTimeMillis()

                        val alpha = 0.8f
                        gravity[0] = alpha * gravity[0] + (1 - alpha) * event.values[0]
                        gravity[1] = alpha * gravity[1] + (1 - alpha) * event.values[1]
                        gravity[2] = alpha * gravity[2] + (1 - alpha) * event.values[2]

                        val x = event.values[0] - gravity[0]
                        val y = event.values[1] - gravity[1]
                        val z = event.values[2] - gravity[2]
                        val magnitude = sqrt((x * x + y * y + z * z).toDouble()).toFloat()

                        if (magnitude >= SHAKE_TRIGGER) {
                            lastMotionTimestamp = now
                            if (now - lastShakeTimestamp >= SHAKE_COOLDOWN_MS) {
                                lastShakeTimestamp = now
                                handleShakeDetected()
                            }
                        } else if (magnitude <= STILL_THRESHOLD) {
                            handleStillDetected(now)
                        }
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

        sensorManager?.registerListener(motionListener, accel, SensorManager.SENSOR_DELAY_UI)
        motionSensorActive = true
        Log.d(TAG, "🎛️ 흔들림 센서 감지 시작")
    }

    private fun stopIdleMotionSensor() {
        if (!motionSensorActive) return
        motionListener?.let { sensorManager?.unregisterListener(it) }
        motionListener = null
        motionSensorActive = false
        Log.d(TAG, "🎛️ 흔들림 센서 감지 중지")
    }

    private fun handleShakeDetected() {
        if (currentState == LocationState.HOT) return

        val insideExitPlaces =
                alarmPlaces.values.filter { place ->
                    place.triggerType == AlarmTriggerType.EXIT &&
                            place.enabled &&
                            insideStatus[place.id] == true &&
                            !triggeredAlarms.contains(place.id)
                }

        if (insideExitPlaces.isEmpty()) return

        if (insideExitPlaces.size == 1) {
            Log.d(TAG, "🏃 흔들림 감지 → HOT 전환 (${insideExitPlaces.first().name})")
            switchToHot(insideExitPlaces.first())
            return
        }

        passiveLocationProvider.getLastKnownLocation { location ->
            val chosen =
                    if (location == null) {
                        insideExitPlaces.first()
                    } else {
                        insideExitPlaces.minByOrNull { place ->
                            calculateDistance(
                                    location.latitude,
                                    location.longitude,
                                    place.latitude,
                                    place.longitude
                            )
                        }
                    }
            if (chosen != null) {
                Log.d(TAG, "🏃 흔들림 감지 → HOT 전환 (${chosen.name})")
                switchToHot(chosen)
            }
        }
    }

    private fun handleStillDetected(now: Long) {
        if (currentState != LocationState.HOT) return
        if (confirmationInProgress) return

        if (lastMotionTimestamp == 0L) {
            lastMotionTimestamp = now
            return
        }

        if (now - lastMotionTimestamp >= HOT_STILL_TO_IDLE_MS) {
            Log.d(TAG, "🛑 흔들림 감소 감지 - HOT 종료 후 IDLE 복귀")
            switchToIdle()
        }
    }

    /** 모든 타임아웃 취소 */
    private fun cancelAllTimeouts() {
        armedTimeoutRunnable?.let { handler.removeCallbacks(it) }
        hotTimeoutRunnable?.let { handler.removeCallbacks(it) }
        armedTimeoutRunnable = null
        hotTimeoutRunnable = null
    }

    /** 두 좌표 사이 거리 계산 (미터) */
    private fun calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Float {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lon1, lat2, lon2, results)
        return results[0]
    }

    /** 현재 상태 정보 */
    fun getStatus(): Map<String, Any> {
        val insideByName =
                insideStatus
                        .mapNotNull { (placeId, isInside) ->
                            val name = alarmPlaces[placeId]?.name
                            if (name != null) {
                                "$name=$isInside"
                            } else {
                                null
                            }
                        }
                        .joinToString()
        return mapOf(
                "state" to currentState.name,
                "targetPlace" to (targetPlace?.name ?: "없음"),
                "alarmCount" to alarmPlaces.size,
                "insideStatus" to insideByName,
                "triggeredAlarms" to triggeredAlarms.joinToString()
        )
    }

    /** 특정 알람을 트리거됨으로 표시 (Flutter에서 호출 - 알람 종료 시) */
    fun markAlarmAsTriggered(placeId: String) {
        triggeredAlarms.add(placeId)
        Log.d(TAG, "🔕 알람 트리거 완료 표시: $placeId")
    }

    /** 특정 알람 트리거 기록 제거 (Flutter에서 호출 - 알람 재활성화 시) */
    fun clearTriggeredAlarm(placeId: String) {
        triggeredAlarms.remove(placeId)
        Log.d(TAG, "🔔 알람 트리거 기록 제거: $placeId")
    }

    /** 모든 트리거 기록 초기화 (Flutter에서 호출) */
    fun clearAllTriggeredAlarms() {
        triggeredAlarms.clear()
        Log.d(TAG, "🔄 모든 트리거 기록 초기화")
    }
}

/** HOT 모드용 짧은 수명 Foreground Service */
class HotModeForegroundService : Service() {

    companion object {
        private const val TAG = "HotModeFGS"
        private const val CHANNEL_ID = "hot_mode_channel"
        private const val NOTIFICATION_ID = 9999

        fun start(context: Context) {
            val intent = Intent(context, HotModeForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HotModeForegroundService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        Log.d(TAG, "🔥 HOT 모드 FGS 시작")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "🛑 HOT 모드 FGS 종료")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(CHANNEL_ID, "위치 확인 중", NotificationManager.IMPORTANCE_LOW)
                            .apply { setShowBadge(false) }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("위치 확인 중...")
                .setContentText("잠시만 기다려주세요")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()
    }
}

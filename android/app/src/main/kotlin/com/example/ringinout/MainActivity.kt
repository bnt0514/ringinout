package com.example.ringinout

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat
import com.example.ringinout.location.AlarmPlace
import com.example.ringinout.location.AlarmTriggerType
import com.example.ringinout.location.SmartLocationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

var flutterRingtone: Ringtone? = null

class MainActivity : FlutterActivity() {

    companion object {
        var pendingAlarmId: Int? = null
        var navigateToFullscreen: Boolean = false
        var startWithVoice: Boolean = false // 🎤 음성 알람 모드
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "🔥 onCreate 호출됨")

        // ✅ 앱 시작 시 포그라운드 알림 생성 (삭제 불가능)
        createPersistentForegroundNotification()

        // ✅ Watchdog 시작 (서비스 죽음 감지)
        ServiceWatchdogReceiver.startWatchdog(this)

        // ✅ Daily check 스케줄 시작 (하루 4회)
        ServiceWatchdogReceiver.startDailyChecks(this)

        // 🛡️ 앱 종료 감지 서비스 시작 (멀티태스킹 종료 즉시 감지)
        AppDeathDetectorService.start(this)

        navigateToFullscreen = intent.getBooleanExtra("navigate_to_fullscreen", false)
        pendingAlarmId = intent.getIntExtra("alarmId", -1)

        // 🎤 위젯에서 음성 알람 모드로 실행되었는지 확인
        handleVoiceAlarmIntent(intent)

        // ✅ Watchdog/스누즈에서 재시작된 경우 처리
        handleWatchdogRestart(intent)
    }

    // ✅ Watchdog 재시작 처리
    private fun handleWatchdogRestart(intent: Intent) {
        when (intent.action) {
            "RESTART_FROM_WATCHDOG" -> {
                Log.d("MainActivity", "🔧 Watchdog에서 앱 재시작됨")
                // 서비스 복구 알림 표시
            }
            "PLAY_SNOOZE_ALARM" -> {
                Log.d("MainActivity", "⏰ 스누즈 알람 재생 요청")
                // 벨소리 재생
                playDefaultRingtone(this)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        Log.d("MainActivity", "🔄 onNewIntent 호출됨")
        handleVoiceAlarmIntent(intent)
    }

    // 🎤 음성 알람 인텐트 처리
    private fun handleVoiceAlarmIntent(intent: Intent) {
        if (intent.action == MicWidgetProvider.ACTION_VOICE_ALARM ||
                        intent.getBooleanExtra("start_with_voice", false)
        ) {
            startWithVoice = true
            Log.d("MainActivity", "🎤 음성 알람 모드로 시작")
        }
    }

    override fun onDestroy() {
        Log.d("MainActivity", "⚠️ MainActivity onDestroy - 앱이 종료되려고 합니다")
        // ✅ Activity가 종료되어도 Flutter 엔진과 서비스는 계속 유지
        super.onDestroy()
    }

    // ✅ 뒤로가기 버튼 - 백그라운드로 이동 (종료 안 함)
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        Log.d("MainActivity", "🔙 뒤로가기 버튼 클릭 - 백그라운드로 이동")
        moveTaskToBack(true) // 백그라운드로 보내기
        // super.onBackPressed() 호출하지 않음 = 앱 종료 안 함
    }

    // ✅ 포그라운드 알림 생성 (삭제 불가능, 앱 종료 방지)
    private fun createPersistentForegroundNotification() {
        try {
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_alarm_foreground"

            // ✅ 포그라운드 알림 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "위치 알람 서비스 (상시 실행)",
                                        NotificationManager.IMPORTANCE_LOW
                                )
                                .apply {
                                    description = "위치 알람이 백그라운드에서 계속 실행됩니다"
                                    setSound(null, null)
                                    enableLights(false)
                                    enableVibration(false)
                                    setShowBadge(false)
                                    lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // ✅ 삭제 불가능한 포그라운드 알림 생성
            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setContentTitle("Ringinout 위치 알람")
                            .setContentText("백그라운드에서 위치를 모니터링하고 있습니다")
                            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                            .setOngoing(true) // ✅ 삭제 불가능
                            .setAutoCancel(false)
                            .setPriority(NotificationCompat.PRIORITY_LOW)
                            .setCategory(NotificationCompat.CATEGORY_SERVICE)
                            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
                            .setShowWhen(false)
                            .setSilent(true)
                            .build()

            notificationManager.notify(999, notification)
            Log.d("MainActivity", "✅ 포그라운드 알림 생성 완료 (ID: 999)")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 포그라운드 알림 생성 실패: ${e.message}")
        }
    }

    // ✅ 최적화된 위치 알림 (한 번만 표시, 조용함) - 제거 예정
    private fun createOptimizedLocationNotification() {
        try {
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_quiet"

            // ✅ 조용한 알림 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "위치 알람 서비스",
                                        NotificationManager.IMPORTANCE_LOW // LOW로 변경
                                )
                                .apply {
                                    description = "위치 기반 알람이 백그라운드에서 동작 중입니다"
                                    setSound(null, null)
                                    enableLights(false) // LED 끄기
                                    enableVibration(false) // 진동 끄기
                                    setShowBadge(false) // 배지 끄기
                                    lockscreenVisibility =
                                            NotificationCompat.VISIBILITY_SECRET // ✅ 잠금 화면에서 숨김
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // ✅ 조용한 알림 생성
            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setContentTitle("Ringinout 위치 알람")
                            .setContentText("백그라운드에서 위치를 모니터링하고 있습니다")
                            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                            .setOngoing(false) // ✅ 삭제 가능하게 변경
                            .setAutoCancel(true) // ✅ 터치하면 사라짐
                            .setPriority(NotificationCompat.PRIORITY_LOW)
                            .setCategory(NotificationCompat.CATEGORY_SERVICE)
                            .setVisibility(NotificationCompat.VISIBILITY_SECRET) // ✅ 잠금 화면에서 완전히 숨김
                            .setShowWhen(false)
                            .setSilent(true) // ✅ 완전히 조용하게
                            .build()

            // 알림 표시
            notificationManager.notify(778, notification) // ID 변경 (777과 구분)
            Log.d("MainActivity", "✅ 조용한 위치 알림 생성 완료")

            // ✅ 10초 후 자동으로 조용히 사라지게
            Handler(Looper.getMainLooper())
                    .postDelayed(
                            {
                                try {
                                    notificationManager.cancel(778)
                                    Log.d("MainActivity", "🔕 위치 알림 자동 제거")
                                } catch (e: Exception) {
                                    Log.e("MainActivity", "⚠️ 알림 제거 실패: ${e.message}")
                                }
                            },
                            10000
                    ) // 10초
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 조용한 위치 알림 생성 실패: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)

        // ✅ Watchdog heartbeat 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.ringinout/watchdog")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "sendHeartbeat" -> {
                            val activeAlarmsCount = call.argument<Int>("activeAlarmsCount") ?: 0
                            ServiceWatchdogReceiver.sendHeartbeat(this, activeAlarmsCount)
                            result.success(true)
                        }
                        "startWatchdog" -> {
                            ServiceWatchdogReceiver.startWatchdog(this)
                            result.success(true)
                        }
                        "stopWatchdog" -> {
                            ServiceWatchdogReceiver.stopWatchdog(this)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }

        // 🎤 음성 알람 모드 체크 채널
        MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.example.ringinout/voice_alarm"
                )
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "checkVoiceAlarmMode" -> {
                            val shouldStart = startWithVoice
                            startWithVoice = false // 한 번 체크 후 리셋
                            Log.d("MainActivity", "🎤 음성 알람 모드 체크: $shouldStart")
                            result.success(shouldStart)
                        }
                        else -> result.notImplemented()
                    }
                }

        // DND 권한 요청/확인
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ringinout/permissions")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "requestDndPermission" -> {
                            requestDndPermission()
                            result.success(null)
                        }
                        "checkDndPermission" -> {
                            val isGranted = checkDndPermission()
                            result.success(isGranted)
                        }
                        else -> result.notImplemented()
                    }
                }

        // ✅ 지속 알림 채널
        MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.example.ringinout/notification"
                )
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "createPersistentNotification" -> {
                            val content = call.argument<String>("content") ?: "알람 모니터링 중"
                            updatePersistentLocationNotification(content)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }

        // Native fullscreen alarm 호출
        MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.example.ringinout/fullscreen_native"
                )
                .setMethodCallHandler { call, result ->
                    if (call.method == "launchNativeAlarm") {
                        val alarmId = call.argument<Int>("alarmId") ?: -1

                        val prefs =
                                applicationContext.getSharedPreferences(
                                        "ringinout",
                                        Context.MODE_PRIVATE
                                )
                        val count = prefs.getInt("trigger_count_" + alarmId, 0) + 1
                        prefs.edit().putInt("trigger_count_" + alarmId, count).apply()

                        val intent =
                                Intent(applicationContext, AlarmFullscreenActivity::class.java)
                                        .apply {
                                            putExtra("alarmId", alarmId)
                                            putExtra("triggerCount", count)
                                            addFlags(
                                                    Intent.FLAG_ACTIVITY_NEW_TASK or
                                                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                                            )
                                        }
                        applicationContext.startActivity(intent)
                        result.success(null)
                    } else {
                        result.notImplemented()
                    }
                }

        // ✅ 백그라운드 알람 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.ringinout/alarm")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "showFullScreenAlarm" -> {
                            val title = call.argument<String>("title") ?: "알람"
                            val message = call.argument<String>("message") ?: "위치 알람"
                            val alarmIdRaw = call.argument<Any>("alarmId") // ✅ Any로 받아서 변환
                            val placeId = call.argument<String>("placeId") ?: ""

                            // ✅ String UUID를 hashCode로 변환
                            val alarmId =
                                    when (alarmIdRaw) {
                                        is Int -> alarmIdRaw
                                        is String -> alarmIdRaw.hashCode()
                                        else -> -1
                                    }

                            showBackgroundFullScreenAlarm(title, message, alarmId, placeId)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                }

        // 시스템 기본 벨소리 재생/정지 호출 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flutter.bell")
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "playSystemRingtone" -> {
                            playDefaultRingtone(applicationContext)
                            result.success(null)
                        }
                        "stopSystemRingtone" -> {
                            stopDefaultRingtone()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }

        // Flutter로 알람 페이지 진입 요청
        if (intent?.getBooleanExtra("fromAlarm", false) == true &&
                        navigateToFullscreen &&
                        pendingAlarmId != null &&
                        pendingAlarmId != -1
        ) {
            Handler(Looper.getMainLooper()).post {
                Log.d("Ringinout", "📨 Flutter invokeMethod 준비됨: navigateToFullScreenAlarm")
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ringinout_channel")
                        .invokeMethod(
                                "navigateToFullScreenAlarm",
                                mapOf("alarmId" to pendingAlarmId)
                        )
                Log.d("Ringinout", "✅ navigateToFullScreenAlarm 완료")
                pendingAlarmId = null
                navigateToFullscreen = false
            }
        }

        // 상태 보고 채널
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.ringinout/status")
                .invokeMethod("engineReady", null)

        // 🎯 SmartLocationManager 채널 (3단계 위치 모니터링)
        val smartLocationChannel =
                MethodChannel(
                        flutterEngine.dartExecutor.binaryMessenger,
                        "com.example.ringinout/smart_location"
                )

        // Flutter에서 알람 트리거 수신할 수 있도록 채널 연결
        SmartLocationManager.flutterChannel = smartLocationChannel

        // ✅ Flutter 엔진 재연결 시 보류된 지오펜스 이벤트 전달
        SmartLocationManager.getInstance(applicationContext).deliverPendingGeofenceEvents()

        smartLocationChannel.setMethodCallHandler { call, result ->
            val smartManager = SmartLocationManager.getInstance(applicationContext)

            when (call.method) {
                "startMonitoring" -> {
                    try {
                        val placesData =
                                call.argument<List<Map<String, Any>>>("places") ?: emptyList()
                        val places =
                                placesData.map { data ->
                                    AlarmPlace(
                                            id = data["id"] as String,
                                            name = data["name"] as String,
                                            latitude = (data["latitude"] as Number).toDouble(),
                                            longitude = (data["longitude"] as Number).toDouble(),
                                            radiusMeters =
                                                    (data["radiusMeters"] as Number).toFloat(),
                                            triggerType =
                                                    if (data["triggerType"] == "exit")
                                                            AlarmTriggerType.EXIT
                                                    else AlarmTriggerType.ENTER,
                                            enabled = data["enabled"] as? Boolean ?: true,
                                            isFirstOnly = data["isFirstOnly"] as? Boolean ?: false,
                                            startTimeMs = (data["startTimeMs"] as? Number)?.toLong()
                                                            ?: 0L,
                                            isTimeSpecified = data["isTimeSpecified"] as? Boolean
                                                            ?: false,
                                    )
                                }
                        smartManager.startMonitoring(places)
                        Log.d("MainActivity", "🎯 SmartLocationManager 시작: ${places.size}개 장소")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "❌ SmartLocationManager 시작 실패: ${e.message}")
                        result.error("ERROR", e.message, null)
                    }
                }
                "stopMonitoring" -> {
                    smartManager.stopMonitoring()
                    Log.d("MainActivity", "🛑 SmartLocationManager 중지")
                    result.success(true)
                }
                "updatePlaces" -> {
                    try {
                        val placesData =
                                call.argument<List<Map<String, Any>>>("places") ?: emptyList()
                        val places =
                                placesData.map { data ->
                                    AlarmPlace(
                                            id = data["id"] as String,
                                            name = data["name"] as String,
                                            latitude = (data["latitude"] as Number).toDouble(),
                                            longitude = (data["longitude"] as Number).toDouble(),
                                            radiusMeters =
                                                    (data["radiusMeters"] as Number).toFloat(),
                                            triggerType =
                                                    if (data["triggerType"] == "exit")
                                                            AlarmTriggerType.EXIT
                                                    else AlarmTriggerType.ENTER,
                                            enabled = data["enabled"] as? Boolean ?: true,
                                            isFirstOnly = data["isFirstOnly"] as? Boolean ?: false,
                                            startTimeMs = (data["startTimeMs"] as? Number)?.toLong()
                                                            ?: 0L,
                                            isTimeSpecified = data["isTimeSpecified"] as? Boolean
                                                            ?: false,
                                    )
                                }
                        smartManager.updateAlarmPlaces(places)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "clearTriggeredAlarm" -> {
                    // 린 하이브리드: 판정은 Flutter에서 관리, no-op
                    result.success(true)
                }
                "getStatus" -> {
                    val status = smartManager.getStatus()
                    result.success(status)
                }
                "passingAlarm" -> {
                    // 린 하이브리드: 판정은 Flutter에서 관리, no-op
                    result.success(true)
                }
                "dismissAlarm" -> {
                    // 린 하이브리드: 판정은 Flutter에서 관리, no-op
                    result.success(true)
                }
                "setAlarmMode" -> {
                    // 린 하이브리드: 항상 Flutter 모드
                    result.success(true)
                }
                "testAlarm" -> {
                    // 린 하이브리드: 테스트 알람은 Flutter에서 직접 처리
                    result.success(true)
                }
                "sendErrorReport" -> {
                    try {
                        val payload = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                        Log.d("MainActivity", "📝 에러 리포트 수신: ${payload.keys}")
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "injectSimulatedLocation" -> {
                    // 린 하이브리드: GPS 시뮬레이터 제거됨
                    result.success(true)
                }
                "stopSimulation" -> {
                    // 린 하이브리드: GPS 시뮬레이터 제거됨
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 기본 알람(시간 알람) 기능 폐기: 관련 채널 비활성화
    }

    // ✅ DND 권한 확인
    private fun checkDndPermission(): Boolean {
        val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else {
            true // M 이전 버전은 권한 필요 없음
        }
    }

    private fun requestDndPermission() {
        val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                        !notificationManager.isNotificationPolicyAccessGranted
        ) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    // ✅ 삭제 불가능한 위치 모니터링 알림 생성 (앱 시작 시)
    private fun createPersistentLocationNotification() {
        try {
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_persistent"

            // 알림 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "위치 모니터링 (지속)",
                                        NotificationManager.IMPORTANCE_LOW
                                )
                                .apply {
                                    description = "삭제할 수 없는 위치 모니터링 알림"
                                    setSound(null, null)
                                    enableVibration(false)
                                    setShowBadge(false)
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // ✅ 강력한 지속 알림 생성
            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setContentTitle("위치 알람 감시중")
                            .setContentText("백그라운드에서 위치를 모니터링하고 있습니다")
                            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                            .setOngoing(true) // 삭제 불가능
                            .setAutoCancel(false) // 터치해도 사라지지 않음
                            .setPriority(NotificationCompat.PRIORITY_LOW)
                            .setCategory(NotificationCompat.CATEGORY_SERVICE)
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .setShowWhen(false) // 시간 표시 안함
                            .build()

            // 알림 표시 (ID: 777)
            notificationManager.notify(777, notification)
            Log.d("MainActivity", "✅ 지속 위치 알림 생성 완료")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 지속 위치 알림 생성 실패: ${e.message}")
        }
    }

    // ✅ 지속 알림 업데이트 메서드
    private fun updatePersistentLocationNotification(content: String) {
        try {
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_persistent"

            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setContentTitle("위치 알람 감시중")
                            .setContentText(content)
                            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                            .setOngoing(true)
                            .setAutoCancel(false)
                            .setPriority(NotificationCompat.PRIORITY_LOW)
                            .setCategory(NotificationCompat.CATEGORY_SERVICE)
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .setShowWhen(false)
                            .build()

            notificationManager.notify(777, notification)
            Log.d("MainActivity", "✅ 지속 알림 업데이트: $content")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 지속 알림 업데이트 실패: ${e.message}")
        }
    }

    // ✅ 백그라운드 전체화면 알람 표시
    private fun showBackgroundFullScreenAlarm(
            title: String,
            message: String,
            alarmId: Int,
            placeId: String = ""
    ) {
        try {
            Log.d("MainActivity", "📱 백그라운드 전체화면 알람 표시: $title (ID: $alarmId, placeId: $placeId)")

            // ✅ SharedPreferences에서 triggerCount 가져오기
            val prefs = applicationContext.getSharedPreferences("ringinout", Context.MODE_PRIVATE)
            val count = prefs.getInt("trigger_count_$alarmId", 0) + 1
            prefs.edit().putInt("trigger_count_$alarmId", count).apply()

            val intent =
                    Intent(applicationContext, AlarmFullscreenActivity::class.java).apply {
                        putExtra("title", title)
                        putExtra("message", message)
                        putExtra("alarmId", alarmId) // ✅ alarmId 전달
                        putExtra("placeId", placeId) // ✅ placeId 전달 (passing버튼용)
                        putExtra("isBackgroundAlarm", true)
                        addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                        Intent.FLAG_ACTIVITY_NO_HISTORY
                        )
                    }

            applicationContext.startActivity(intent)
            Log.d("MainActivity", "✅ 백그라운드 전체화면 알람 시작 (triggerCount: $count)")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 백그라운드 전체화면 알람 실패: ${e.message}")
        }
    }

    // 기존 두 함수만 교체

    // MainActivity.kt의 playDefaultRingtone 메서드에서 수정

    private fun playDefaultRingtone(context: Context) {
        try {
            // ✅ 중복 재생 방지 - 이미 울리고 있으면 무시
            if (flutterRingtone?.isPlaying == true) {
                Log.d("MainActivity", "⚠️ 벨소리가 이미 재생 중 - 중복 재생 방지")
                return
            }

            // ✅ 기존 벨소리 정리 (안전을 위해)
            stopDefaultRingtone()

            val alarmUri: Uri =
                    RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            flutterRingtone = RingtoneManager.getRingtone(context, alarmUri)

            // 🔁 루프 재생 강제
            flutterRingtone?.isLooping = true

            // 🔊 무음/방해금지 모드 무시하고 강제 울리도록 설정
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                val attrs =
                        android.media.AudioAttributes.Builder()
                                .setUsage(android.media.AudioAttributes.USAGE_ALARM) // 알람 용도
                                .setContentType(
                                        android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION
                                )
                                // ✅ FLAG_BYPASS_INTERRUPTION_POLICY 제거 (호환성 문제)
                                .build()
                flutterRingtone?.audioAttributes = attrs
            }

            flutterRingtone?.play()
            Log.d("MainActivity", "🔔 무한 알람 벨소리 재생 시작 (루프: ${flutterRingtone?.isLooping})")

            // ✅ 재생 상태 확인 로그
            android.os.Handler(android.os.Looper.getMainLooper())
                    .postDelayed(
                            {
                                if (flutterRingtone?.isPlaying == true) {
                                    Log.d("MainActivity", "✅ 벨소리 정상 재생 중 - 무한 루프 활성")
                                } else {
                                    Log.e("MainActivity", "❌ 벨소리 재생 실패 또는 정지됨")
                                }
                            },
                            2000
                    )
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 벨소리 재생 실패: ${e.message}")
        }
    }

    private fun stopDefaultRingtone() {
        try {
            if (flutterRingtone?.isPlaying == true) {
                flutterRingtone?.stop()
                Log.d("MainActivity", "🔕 무한 벨소리 정지 완료")
            } else {
                Log.d("MainActivity", "🔕 정지할 벨소리 없음")
            }
            flutterRingtone = null
        } catch (e: Exception) {
            Log.e("MainActivity", "⚠️ 벨소리 정지 실패: ${e.message}")
            flutterRingtone = null // 강제 초기화
        }
    }
} // ✅ 이 괄호는 그대로 유지 (MainActivity 클래스의 끝)

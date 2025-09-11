package com.example.ringinout

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

var flutterRingtone: Ringtone? = null

class MainActivity : FlutterActivity() {

    companion object {
        var pendingAlarmId: Int? = null
        var navigateToFullscreen: Boolean = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("MainActivity", "🔥 onCreate 호출됨")

        // ✅ 앱 시작 시 한 번만 알림 생성 (5초 후 조용하게)
        createOptimizedLocationNotification()

        navigateToFullscreen = intent.getBooleanExtra("navigate_to_fullscreen", false)
        pendingAlarmId = intent.getIntExtra("alarmId", -1)
    }

    // ✅ 최적화된 위치 알림 (한 번만 표시, 조용함)
    private fun createOptimizedLocationNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_quiet"
            
            // ✅ 조용한 알림 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "위치 알람 서비스",
                    NotificationManager.IMPORTANCE_LOW  // LOW로 변경
                ).apply {
                    description = "위치 기반 알람이 백그라운드에서 동작 중입니다"
                    setSound(null, null)
                    enableLights(false)  // LED 끄기
                    enableVibration(false)  // 진동 끄기
                    setShowBadge(false)  // 배지 끄기
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // ✅ 조용한 알림 생성
            val notification = NotificationCompat.Builder(this, channelId)
                .setContentTitle("Ringinout 위치 알람")
                .setContentText("백그라운드에서 위치를 모니터링하고 있습니다")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(false)  // ✅ 삭제 가능하게 변경
                .setAutoCancel(true)  // ✅ 터치하면 사라짐
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setShowWhen(false)
                .build()
            
            // 알림 표시
            notificationManager.notify(778, notification)  // ID 변경 (777과 구분)
            Log.d("MainActivity", "✅ 조용한 위치 알림 생성 완료")
            
            // ✅ 10초 후 자동으로 조용히 사라지게
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    notificationManager.cancel(778)
                    Log.d("MainActivity", "🔕 위치 알림 자동 제거")
                } catch (e: Exception) {
                    Log.e("MainActivity", "⚠️ 알림 제거 실패: ${e.message}")
                }
            }, 10000) // 10초
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 조용한 위치 알림 생성 실패: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)

        // DND 권한 요청
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ringinout/permissions"
        ).setMethodCallHandler { call, result ->
            if (call.method == "requestDndPermission") {
                requestDndPermission()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // ✅ 지속 알림 채널
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.ringinout/notification"
        ).setMethodCallHandler { call, result ->
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
        ).setMethodCallHandler { call, result ->
            if (call.method == "launchNativeAlarm") {
                val alarmId = call.argument<Int>("alarmId") ?: -1

                val prefs = applicationContext.getSharedPreferences("ringinout", Context.MODE_PRIVATE)
                val count = prefs.getInt("trigger_count_" + alarmId, 0) + 1
                prefs.edit().putInt("trigger_count_" + alarmId, count).apply()

                val intent = Intent(applicationContext, AlarmFullscreenActivity::class.java).apply {
                    putExtra("alarmId", alarmId)
                    putExtra("triggerCount", count)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                applicationContext.startActivity(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // ✅ 백그라운드 알람 채널
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.ringinout/alarm"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showFullScreenAlarm" -> {
                    val title = call.argument<String>("title") ?: "알람"
                    val message = call.argument<String>("message") ?: "위치 알람"
                    showBackgroundFullScreenAlarm(title, message)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 시스템 기본 벨소리 재생/정지 호출 채널
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "flutter.bell"
        ).setMethodCallHandler { call, result ->
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
        if (navigateToFullscreen && pendingAlarmId != null && pendingAlarmId != -1) {
            Handler(Looper.getMainLooper()).post {
                Log.d("Ringinout", "📨 Flutter invokeMethod 준비됨: navigateToFullScreenAlarm")
                MethodChannel(
                    flutterEngine.dartExecutor.binaryMessenger,
                    "ringinout_channel"
                ).invokeMethod(
                    "navigateToFullScreenAlarm",
                    mapOf("alarmId" to pendingAlarmId)
                )
                Log.d("Ringinout", "✅ navigateToFullScreenAlarm 완료")
                pendingAlarmId = null
                navigateToFullscreen = false
            }
        }

        // 상태 보고 채널
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.ringinout/status"
        ).invokeMethod("engineReady", null)
    }

    private fun requestDndPermission() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !notificationManager.isNotificationPolicyAccessGranted) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    // ✅ 삭제 불가능한 위치 모니터링 알림 생성 (앱 시작 시)
    private fun createPersistentLocationNotification() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_persistent"
            
            // 알림 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    channelId,
                    "위치 모니터링 (지속)",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "삭제할 수 없는 위치 모니터링 알림"
                    setSound(null, null)
                    enableVibration(false)
                    setShowBadge(false)
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // ✅ 강력한 지속 알림 생성
            val notification = NotificationCompat.Builder(this, channelId)
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
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channelId = "location_monitoring_persistent"
            
            val notification = NotificationCompat.Builder(this, channelId)
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
    private fun showBackgroundFullScreenAlarm(title: String, message: String) {
        try {
            Log.d("MainActivity", "📱 백그라운드 전체화면 알람 표시: $title")
            
            val intent = Intent(applicationContext, AlarmFullscreenActivity::class.java).apply {
                putExtra("title", title)
                putExtra("message", message)
                putExtra("isBackgroundAlarm", true)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or 
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_HISTORY
                )
            }
            
            applicationContext.startActivity(intent)
            Log.d("MainActivity", "✅ 백그라운드 전체화면 알람 시작")
            
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 백그라운드 전체화면 알람 실패: ${e.message}")
        }
    }

    private fun playDefaultRingtone(context: Context) {
        try {
            val alarmUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            flutterRingtone = RingtoneManager.getRingtone(context, alarmUri)
            flutterRingtone?.play()
            Log.d("MainActivity", "🔔 시스템 벨소리 재생 시작")
        } catch (e: Exception) {
            Log.e("MainActivity", "❌ 벨소리 재생 실패: ${e.message}")
        }
    }

    private fun stopDefaultRingtone() {
        try {
            flutterRingtone?.stop()
            flutterRingtone = null
            Log.d("MainActivity", "🔕 시스템 벨소리 정지")
        } catch (e: Exception) {
            Log.e("MainActivity", "⚠️ 벨소리 정지 실패: ${e.message}")
        }
    }
}
package com.example.ringinout

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * 앱 강제 종료 감지 서비스
 *
 * 사용자가 멀티태스킹에서 앱을 밀어서 종료하면 onTaskRemoved()가 호출되어 즉시 알림을 표시합니다.
 */
class AppDeathDetectorService : Service() {

    companion object {
        private const val CHANNEL_ID = "app_death_detector"
        private const val NOTIFICATION_ID = 7778
        private const val PREFS_NAME = "ringinout_watchdog"
        private const val KEY_ACTIVE_ALARMS = "active_alarms_count"
        private const val ALIVE_LOG_INTERVAL_MS = 30_000L

        fun start(context: Context) {
            val intent = Intent(context, AppDeathDetectorService::class.java)
            // 일반 서비스로 시작 (FGS 권한 충돌 회피)
            context.startService(intent)
            Log.d("AppDeathDetector", "🛡️ 앱 종료 감지 서비스 시작")
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, AppDeathDetectorService::class.java))
            Log.d("AppDeathDetector", "🛑 앱 종료 감지 서비스 중지")
        }
    }

    private val aliveLogHandler = Handler(Looper.getMainLooper())
    private var aliveLogStarted = false
    private val aliveLogRunnable =
            object : Runnable {
                override fun run() {
                    logAliveTick()
                    aliveLogHandler.postDelayed(this, ALIVE_LOG_INTERVAL_MS)
                }
            }

    override fun onCreate() {
        super.onCreate()
        // FGS 아님 - 알림 표시 안 함
        Log.d("AppDeathDetector", "🛡️ onCreate - 서비스 생성됨")
        startAliveLoggingIfNeeded()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppDeathDetector", "🛡️ onStartCommand")
        startAliveLoggingIfNeeded()
        return START_STICKY // 죽으면 시스템이 재시작
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /** 🎯 핵심! 멀티태스킹에서 앱을 밀어서 종료하면 호출됨 */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.d("AppDeathDetector", "⚠️ onTaskRemoved - 앱이 강제 종료됨!")

        // 활성 알람이 있는지 확인
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val activeAlarms = prefs.getInt(KEY_ACTIVE_ALARMS, 0)

        if (activeAlarms > 0) {
            Log.d("AppDeathDetector", "🚨 활성 알람 $activeAlarms 개 있음 - 알림 표시!")
            showDeathNotification(activeAlarms)

            // 앱 재시작 시도
            tryRestartApp()
        } else {
            Log.d("AppDeathDetector", "✅ 활성 알람 없음 - 알림 생략")
        }
    }

    override fun onDestroy() {
        stopAliveLogging()
        Log.d("AppDeathDetector", "🛑 onDestroy - 생존 로그 중지")
        super.onDestroy()
    }

    private fun startAliveLoggingIfNeeded() {
        if (aliveLogStarted) return
        aliveLogStarted = true
        aliveLogHandler.post(aliveLogRunnable)
        Log.d("AppDeathDetector", "💓 30초 주기 생존 로그 시작")
    }

    private fun stopAliveLogging() {
        aliveLogHandler.removeCallbacks(aliveLogRunnable)
        aliveLogStarted = false
    }

    private fun logAliveTick() {
        val processInfo = ActivityManager.RunningAppProcessInfo()
        ActivityManager.getMyMemoryState(processInfo)

        val stateLabel =
                when (processInfo.importance) {
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND -> "foreground"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE -> "visible"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE -> "service"
                    ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED -> "cached"
                    else -> "background"
                }

        Log.d(
                "AppAlive",
                "💓 alive tick - importance=${processInfo.importance}, state=$stateLabel, serviceRunning=true"
        )
    }

    private fun showDeathNotification(activeAlarms: Int) {
        try {
            val channelId = "service_watchdog_critical"
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 고우선순위 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "⚠️ 앱 종료 감지",
                                        NotificationManager.IMPORTANCE_HIGH
                                )
                                .apply {
                                    description = "앱이 강제 종료되었을 때 알림"
                                    enableVibration(true)
                                    vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // 앱 열기 Intent
            val clickIntent =
                    Intent(this, MainActivity::class.java).apply {
                        action = "RESTART_FROM_DEATH_DETECTOR"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            val pendingIntent =
                    PendingIntent.getActivity(
                            this,
                            8889,
                            clickIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setSmallIcon(android.R.drawable.stat_notify_error)
                            .setContentTitle("⚠️ 위치 알람이 중지되었습니다!")
                            .setContentText("$activeAlarms 개의 알람이 작동하지 않습니다. 터치하여 복구하세요.")
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(
                                                    "앱이 종료되어 $activeAlarms 개의 위치 알람이 작동하지 않습니다.\n\n터치하여 앱을 열고 알람을 다시 활성화하세요."
                                            )
                            )
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setCategory(NotificationCompat.CATEGORY_ERROR)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .setColor(0xFFFF0000.toInt())
                            .build()

            notificationManager.notify(7777, notification)
            Log.d("AppDeathDetector", "🚨 종료 알림 표시 완료")
        } catch (e: Exception) {
            Log.e("AppDeathDetector", "❌ 알림 표시 실패: ${e.message}")
        }
    }

    private fun tryRestartApp() {
        try {
            val intent =
                    Intent(this, MainActivity::class.java).apply {
                        action = "RESTART_FROM_DEATH_DETECTOR"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            startActivity(intent)
            Log.d("AppDeathDetector", "🔄 앱 재시작 시도")
        } catch (e: Exception) {
            Log.e("AppDeathDetector", "❌ 앱 재시작 실패: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel =
                    NotificationChannel(
                                    CHANNEL_ID,
                                    "앱 보호 서비스",
                                    NotificationManager.IMPORTANCE_MIN // 최소 중요도 (사용자에게 거의 안 보임)
                            )
                            .apply {
                                description = "앱 종료 감지를 위한 서비스"
                                setShowBadge(false)
                            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createSilentNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setContentTitle("")
                .setContentText("")
                .setPriority(NotificationCompat.PRIORITY_MIN)
                .setOngoing(true)
                .build()
    }
}

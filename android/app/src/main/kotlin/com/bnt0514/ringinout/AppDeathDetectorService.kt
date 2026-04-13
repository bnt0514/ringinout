package com.bnt0514.ringinout

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.bnt0514.ringinout.location.SmartLocationManager

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
            try {
                val intent = Intent(context, AppDeathDetectorService::class.java)
                context.startService(intent)
                Log.d("AppDeathDetector", "🛡️ 앱 종료 감지 서비스 시작")
            } catch (e: Exception) {
                // Android 12+: 백그라운드에서 시작 불가 예외 — 무시하고 계속 진행
                Log.w("AppDeathDetector", "⚠️ 서비스 시작 실패 (백그라운드 제한): ${e.message}")
            }
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
        Log.d("AppDeathDetector", "⚠️ onTaskRemoved - 태스크 제거 감지!")

        // ✅ Flutter 엔진이 죽었으므로 flutterChannel 무효화
        //   이후 Wi-Fi/지오펜스 이벤트가 pending 저장 + 네이티브 폴백으로 전환됨
        SmartLocationManager.flutterChannel = null
        Log.d("AppDeathDetector", "🔌 flutterChannel = null (Flutter 엔진 무효화)")

        // ✅ 알람 정상 종료(종료/오발동/스누즈) 중이면 알림 생략
        //   ⚠️ 단, alarm_dismissing 플래그가 5초 이상 지속되면 stale로 간주하여 무시
        val watchdogPrefs = getSharedPreferences("ringinout_watchdog", Context.MODE_PRIVATE)
        val isDismissing = watchdogPrefs.getBoolean("alarm_dismissing", false)
        val dismissingTimestamp = watchdogPrefs.getLong("alarm_dismissing_timestamp", 0L)
        val dismissingAge = System.currentTimeMillis() - dismissingTimestamp
        if (isDismissing && dismissingAge < 5000L) {
            watchdogPrefs.edit().remove("alarm_dismissing").remove("alarm_dismissing_timestamp").apply()
            Log.d("AppDeathDetector", "✅ 알람 정상 종료 중 (${dismissingAge}ms) — onTaskRemoved 알림 생략")
            return
        } else if (isDismissing) {
            // stale 플래그 정리
            watchdogPrefs.edit().remove("alarm_dismissing").remove("alarm_dismissing_timestamp").apply()
            Log.w("AppDeathDetector", "⚠️ alarm_dismissing 플래그가 stale (${dismissingAge}ms) — 무시하고 복구 진행")
        }

        // 활성 알람이 있는지 확인
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val activeAlarms = prefs.getInt(KEY_ACTIVE_ALARMS, 0)

        if (activeAlarms <= 0) {
            Log.d("AppDeathDetector", "✅ 활성 알람 없음 - 알림 생략")
            return
        }

        Log.d("AppDeathDetector", "🚨 활성 알람 $activeAlarms 개 있음 - 앱 자동 복구 시도!")

        // ✅ 전략: 2단계 복구
        //   1단계: 알림 표시 (Full-screen Intent 포함 — 백업용)
        //   2단계: 직접 startActivity로 앱 강제 실행 (onTaskRemoved 시점에서는 프로세스 생존)
        //
        //   Android 14+에서 USE_FULL_SCREEN_INTENT 권한이 기본 거부되므로
        //   Full-screen Intent가 헤드업 알림으로 다운그레이드될 수 있음
        //   → 직접 startActivity가 핵심, 알림은 백업
        showDeathNotification(activeAlarms)
        tryDirectRestart()
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

            // ✅ 기존 알림 취소 후 재생성 → 소리+진동 매번 재발동
            notificationManager.cancel(7777)

            // 고우선순위 채널 생성 (소리+진동 강제)
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
                                    setSound(
                                            android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                                            android.media.AudioAttributes.Builder()
                                                    .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                                                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                                    .build()
                                    )
                                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // ✅ Full-screen Intent: MainActivity 강제 실행
            //   - 화면이 켜져 있을 때: 전체화면 알림이 화면을 덮어씌움
            //   - 화면이 꺼져 있을 때: 화면 켜고 앱 시작 (turnScreenOn + showWhenLocked)
            //   - Android 10+ 백그라운드 Activity 제한을 알림 Full-screen Intent가 합법적으로 우회
            val fullScreenIntent =
                    Intent(this, MainActivity::class.java).apply {
                        action = "RESTART_FROM_DEATH_DETECTOR"
                        addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                    }
            val fullScreenPendingIntent =
                    PendingIntent.getActivity(
                            this,
                            8888,
                            fullScreenIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            // 탭 Intent (사용자가 알림을 직접 터치할 때)
            val clickIntent =
                    Intent(this, MainActivity::class.java).apply {
                        action = "RESTART_FROM_DEATH_DETECTOR"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            val clickPendingIntent =
                    PendingIntent.getActivity(
                            this,
                            8889,
                            clickIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            val notification =
                    NotificationCompat.Builder(this, channelId)
                            .setSmallIcon(android.R.drawable.ic_popup_reminder)
                            .setContentTitle("🔄 활성 알람이 있어 앱을 복구합니다")
                            .setContentText("활성 알람 ${activeAlarms}개 — 앱을 자동으로 복구 중입니다.")
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(
                                                    "멀티태스킹에서 앱이 종료되었습니다.\n\n" +
                                                            "활성 알람 ${activeAlarms}개가 있으므로 앱을 자동으로 복구합니다.\n" +
                                                            "잠시 후 앱이 자동으로 열립니다."
                                            )
                            )
                            .setPriority(NotificationCompat.PRIORITY_MAX)  // HIGH → MAX로 상향
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setAutoCancel(true)
                            .setContentIntent(clickPendingIntent)
                            .setFullScreenIntent(fullScreenPendingIntent, true)  // ✅ 핵심: 화면 강제 표시
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .setOnlyAlertOnce(false)
                            .setColor(0xFFFF0000.toInt())
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)  // 잠금화면에도 표시
                            .build()

            notificationManager.notify(7777, notification)
            Log.d("AppDeathDetector", "🚨 Full-screen 알림 표시 완료 (앱 자동 실행 시도)")
        } catch (e: Exception) {
            Log.e("AppDeathDetector", "❌ 알림 표시 실패: ${e.message}")
        }
    }

    /**
     * ✅ onTaskRemoved 시점에서 직접 MainActivity를 시작
     *
     * onTaskRemoved는 아직 앱 프로세스가 살아있는 시점이므로
     * Service에서 startActivity()가 가능합니다.
     *
     * Android 14+에서 Full-screen Intent가 권한 부족으로 실패할 수 있으므로
     * 이것이 실질적인 앱 복구 메커니즘입니다.
     */
    private fun tryDirectRestart() {
        try {
            val restartIntent = Intent(this, MainActivity::class.java).apply {
                action = "RESTART_FROM_DEATH_DETECTOR"
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            startActivity(restartIntent)
            Log.d("AppDeathDetector", "✅ 직접 startActivity 성공 — 앱 복구 시작")
        } catch (e: Exception) {
            Log.e("AppDeathDetector", "❌ 직접 startActivity 실패: ${e.message} — 알림 터치로 복구 필요")
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

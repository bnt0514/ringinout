package com.example.ringinout

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * 백그라운드 서비스 감시 및 복구를 담당하는 Watchdog Receiver
 *
 * 1. 주기적으로 서비스 상태 확인 (AlarmManager)
 * 2. 서비스가 죽으면 자동 재시작 시도
 * 3. 재시작 실패 시 사용자에게 강력한 알림
 */
class ServiceWatchdogReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_CHECK_SERVICE = "com.example.ringinout.ACTION_CHECK_SERVICE"
        const val ACTION_RESTART_SERVICE = "com.example.ringinout.ACTION_RESTART_SERVICE"
        private const val WATCHDOG_INTERVAL_MS = 5 * 60 * 1000L // 5분마다 체크 (백업용, 메인은 onTaskRemoved)
        private const val PREFS_NAME = "ringinout_watchdog"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat"
        private const val KEY_ACTIVE_ALARMS = "active_alarms_count"
        private const val HEARTBEAT_TIMEOUT_MS = 3 * 60 * 1000L // 3분간 heartbeat 없으면 죽은 것으로 판단

        /** Watchdog 스케줄 시작 */
        fun startWatchdog(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent =
                    Intent(context, ServiceWatchdogReceiver::class.java).apply {
                        action = ACTION_CHECK_SERVICE
                    }
            val pendingIntent =
                    PendingIntent.getBroadcast(
                            context,
                            9999, // Watchdog 전용 ID
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            // 5분마다 반복 체크
            alarmManager.setRepeating(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + WATCHDOG_INTERVAL_MS,
                    WATCHDOG_INTERVAL_MS,
                    pendingIntent
            )

            Log.d("Watchdog", "🐕 Watchdog 스케줄 시작 (${WATCHDOG_INTERVAL_MS / 60000}분 간격)")
        }

        /** Watchdog 스케줄 중지 */
        fun stopWatchdog(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent =
                    Intent(context, ServiceWatchdogReceiver::class.java).apply {
                        action = ACTION_CHECK_SERVICE
                    }
            val pendingIntent =
                    PendingIntent.getBroadcast(
                            context,
                            9999,
                            intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
            alarmManager.cancel(pendingIntent)
            Log.d("Watchdog", "🛑 Watchdog 스케줄 중지")
        }

        /** 서비스에서 주기적으로 호출하여 살아있음을 알림 */
        fun sendHeartbeat(context: Context, activeAlarmsCount: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putLong(KEY_LAST_HEARTBEAT, System.currentTimeMillis())
                putInt(KEY_ACTIVE_ALARMS, activeAlarmsCount)
                apply()
            }
            Log.d("Watchdog", "💓 Heartbeat 전송 (활성 알람: $activeAlarmsCount)")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("Watchdog", "🐕 Watchdog 수신: ${intent.action}")

        when (intent.action) {
            ACTION_CHECK_SERVICE -> checkServiceHealth(context)
            ACTION_RESTART_SERVICE -> restartService(context)
            Intent.ACTION_BOOT_COMPLETED -> {
                // 부팅 완료 시 서비스 시작 및 Watchdog 활성화
                Log.d("Watchdog", "📱 부팅 완료 - 서비스 복구 시작")
                restartService(context)
                startWatchdog(context)
            }
        }
    }

    private fun checkServiceHealth(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastHeartbeat = prefs.getLong(KEY_LAST_HEARTBEAT, 0)
        val activeAlarms = prefs.getInt(KEY_ACTIVE_ALARMS, 0)
        val now = System.currentTimeMillis()

        Log.d(
                "Watchdog",
                "🔍 서비스 상태 체크 - 마지막 heartbeat: ${(now - lastHeartbeat) / 1000}초 전, 활성 알람: $activeAlarms"
        )

        // 활성 알람이 없으면 체크 불필요
        if (activeAlarms == 0) {
            Log.d("Watchdog", "✅ 활성 알람 없음 - 체크 종료")
            return
        }

        // ✅ 앱 프로세스가 실행 중인지 확인
        if (isAppProcessRunning(context)) {
            Log.d("Watchdog", "✅ 앱 프로세스 실행 중 - 재시작 불필요")
            return
        }

        // Heartbeat가 너무 오래됐고 앱도 실행 중이 아니면 서비스가 죽은 것
        if (now - lastHeartbeat > HEARTBEAT_TIMEOUT_MS) {
            Log.w("Watchdog", "⚠️ 서비스 죽음 감지! 마지막 heartbeat: ${(now - lastHeartbeat) / 1000}초 전")
            handleServiceDeath(context, activeAlarms)
        } else {
            Log.d("Watchdog", "✅ 서비스 정상 작동 중")
        }
    }

    // ✅ 앱 프로세스가 실행 중인지 확인
    private fun isAppProcessRunning(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val packageName = context.packageName

        // 실행 중인 앱 프로세스 목록 확인
        val runningProcesses = activityManager.runningAppProcesses ?: return false

        for (processInfo in runningProcesses) {
            if (processInfo.processName == packageName) {
                // IMPORTANCE_FOREGROUND, IMPORTANCE_VISIBLE, IMPORTANCE_SERVICE 등은 살아있는 것
                val importance = processInfo.importance
                val isAlive = importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE

                Log.d("Watchdog", "📱 앱 프로세스 상태: importance=$importance, isAlive=$isAlive")
                return isAlive
            }
        }

        Log.d("Watchdog", "📱 앱 프로세스 목록에 없음 - 죽은 것으로 판단")
        return false
    }

    private fun handleServiceDeath(context: Context, activeAlarms: Int) {
        Log.d("Watchdog", "🔧 서비스 복구 시도...")

        // 1. 먼저 앱 재시작 시도
        val restartSuccess = restartService(context)

        // 2. 재시작 실패 또는 추가로 사용자에게 알림
        if (!restartSuccess || activeAlarms > 0) {
            showCriticalNotification(context, activeAlarms)
        }
    }

    private fun restartService(context: Context): Boolean {
        return try {
            // MainActivity 시작으로 앱 복구
            val intent =
                    Intent(context, MainActivity::class.java).apply {
                        action = "RESTART_FROM_WATCHDOG"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            context.startActivity(intent)

            Log.d("Watchdog", "✅ 앱 재시작 요청 완료")
            true
        } catch (e: Exception) {
            Log.e("Watchdog", "❌ 앱 재시작 실패: ${e.message}")
            false
        }
    }

    private fun showCriticalNotification(context: Context, activeAlarms: Int) {
        try {
            val channelId = "service_watchdog_critical"
            val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 고우선순위 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "⚠️ 서비스 복구 필요",
                                        NotificationManager.IMPORTANCE_HIGH
                                )
                                .apply {
                                    description = "위치 알람 서비스가 중지되었을 때 알림"
                                    enableVibration(true)
                                    vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // 앱 열기 Intent
            val clickIntent =
                    Intent(context, MainActivity::class.java).apply {
                        action = "OPEN_FROM_WATCHDOG"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            val pendingIntent =
                    PendingIntent.getActivity(
                            context,
                            8888,
                            clickIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            val notification =
                    NotificationCompat.Builder(context, channelId)
                            .setSmallIcon(android.R.drawable.stat_notify_error)
                            .setContentTitle("⚠️ 위치 알람이 중지되었습니다!")
                            .setContentText("$activeAlarms 개의 알람이 작동하지 않을 수 있습니다. 터치하여 앱을 복구하세요.")
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(
                                                    "$activeAlarms 개의 위치 알람이 설정되어 있지만, 백그라운드 서비스가 중지되었습니다.\n\n터치하여 앱을 열고 알람을 다시 활성화하세요."
                                            )
                            )
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setCategory(NotificationCompat.CATEGORY_ERROR)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .setColor(0xFFFF0000.toInt()) // 빨간색
                            .build()

            notificationManager.notify(7777, notification)
            Log.d("Watchdog", "🚨 긴급 알림 표시 완료")
        } catch (e: Exception) {
            Log.e("Watchdog", "❌ 긴급 알림 실패: ${e.message}")
        }
    }
}

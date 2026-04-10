package com.bnt0514.ringinout

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
import androidx.core.content.ContextCompat
import id.flutter.flutter_background_service.BackgroundService
import java.util.Calendar

/**
 * 백그라운드 서비스 감시 및 복구를 담당하는 Watchdog Receiver
 *
 * 1. 주기적으로 서비스 상태 확인 (AlarmManager)
 * 2. 서비스가 죽으면 자동 재시작 시도
 * 3. 재시작 실패 시 사용자에게 강력한 알림
 */
class ServiceWatchdogReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_CHECK_SERVICE = "com.bnt0514.ringinout.ACTION_CHECK_SERVICE"
        const val ACTION_RESTART_SERVICE = "com.bnt0514.ringinout.ACTION_RESTART_SERVICE"
        const val ACTION_DAILY_CHECK = "com.bnt0514.ringinout.ACTION_DAILY_CHECK"
        const val ACTION_BOOT_RECOVERY_REMIND = "com.bnt0514.ringinout.ACTION_BOOT_RECOVERY_REMIND"
        private const val WATCHDOG_INTERVAL_MS = 60 * 60 * 1000L // 1시간마다 체크
        private const val BOOT_REMIND_INTERVAL_MS = 60 * 1000L // 부팅 복구 리마인더 1분 간격
        private const val BOOT_REMIND_MAX_STACK = 3 // 최대 알림 스택 수
        private const val DAILY_CHECK_REQUEST_CODE_BASE = 9990
        private const val BOOT_REMIND_REQUEST_CODE = 9980
        private val DAILY_CHECK_HOURS = listOf(0, 6, 12, 18)
        private const val PREFS_NAME = "ringinout_watchdog"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat"
        private const val KEY_ACTIVE_ALARMS = "active_alarms_count"
        private const val KEY_BOOT_REMIND_COUNT = "boot_remind_count"
        private const val KEY_BOOT_FOREGROUND_SEEN = "boot_foreground_seen"
        private const val HEARTBEAT_TIMEOUT_MS = 65 * 60 * 1000L // 65분간 heartbeat 없으면 죽은 것으로 판단

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

        /** 매일 4회 체크 스케줄 시작 (00:05, 06:05, 12:05, 18:05) */
        fun startDailyChecks(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            DAILY_CHECK_HOURS.forEachIndexed { index, hour ->
                val intent =
                        Intent(context, ServiceWatchdogReceiver::class.java).apply {
                            action = ACTION_DAILY_CHECK
                            putExtra("daily_check_hour", hour)
                        }
                val pendingIntent =
                        PendingIntent.getBroadcast(
                                context,
                                DAILY_CHECK_REQUEST_CODE_BASE + index,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                val calendar =
                        Calendar.getInstance().apply {
                            timeInMillis = System.currentTimeMillis()
                            set(Calendar.HOUR_OF_DAY, hour)
                            set(Calendar.MINUTE, 5)
                            set(Calendar.SECOND, 0)
                            set(Calendar.MILLISECOND, 0)
                            if (timeInMillis <= System.currentTimeMillis()) {
                                add(Calendar.DAY_OF_YEAR, 1)
                            }
                        }

                val triggerAt = calendar.timeInMillis
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            triggerAt,
                            pendingIntent
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
                }

                Log.d("Watchdog", "🗓️ Daily check scheduled: ${calendar.time}")
            }
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

        /**
         * 부팅 복구 리마인더 완전 중지 (AlarmManager 취소 + 알림 정리 + 플래그 리셋)
         * MainActivity 등 외부에서 호출 가능
         */
        fun stopBootRecoveryFull(context: Context) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, ServiceWatchdogReceiver::class.java).apply {
                action = ACTION_BOOT_RECOVERY_REMIND
            }
            val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    BOOT_REMIND_REQUEST_CODE,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)

            // 스택 알림 정리
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(7777)
            notificationManager.cancel(7778)
            notificationManager.cancel(7779)

            // 플래그 리셋
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit()
                    .putInt(KEY_BOOT_REMIND_COUNT, 0)
                    .putBoolean(KEY_BOOT_FOREGROUND_SEEN, true)
                    .apply()

            Log.d("Watchdog", "🛑 부팅 복구 리마인더 완전 중지 + 알림 정리")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("Watchdog", "🐕 Watchdog 수신: ${intent.action}")

        when (intent.action) {
            ACTION_CHECK_SERVICE -> checkServiceHealth(context)
            ACTION_RESTART_SERVICE -> restartService(context)
            ACTION_DAILY_CHECK -> handleDailyCheck(context, intent)
            ACTION_BOOT_RECOVERY_REMIND -> handleBootRecoveryRemind(context)
            Intent.ACTION_BOOT_COMPLETED -> {
                // 부팅 완료 시 서비스 시작 및 Watchdog 활성화
                Log.d("Watchdog", "📱 부팅 완료 - 서비스 복구 시작")
                startWatchdog(context)
                startDailyChecks(context)
                handleBootRecovery(context)
            }
        }
    }

    private fun handleBootRecovery(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val activeAlarms = prefs.getInt(KEY_ACTIVE_ALARMS, 0)

        Log.d("Watchdog", "📱 부팅 복구 - 활성 알람: $activeAlarms")

        if (activeAlarms <= 0) {
            Log.d("Watchdog", "✅ 활성 알람 없음 — 부팅 복구 스킵")
            return
        }

        // 리마인더 카운트 + 포그라운드 플래그 초기화
        prefs.edit()
                .putInt(KEY_BOOT_REMIND_COUNT, 0)
                .putBoolean(KEY_BOOT_FOREGROUND_SEEN, false)
                .apply()

        Log.d("Watchdog", "🚨 활성 알람 ${activeAlarms}개 — Full-screen 알림 + 1분 반복 리마인더 시작!")
        showBootRecoveryNotification(context, activeAlarms, 0)
        startBootRecoveryReminder(context)
    }

    /**
     * 부팅 복구 1분 반복 리마인더 AlarmManager 등록
     */
    private fun startBootRecoveryReminder(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ServiceWatchdogReceiver::class.java).apply {
            action = ACTION_BOOT_RECOVERY_REMIND
        }
        val pendingIntent = PendingIntent.getBroadcast(
                context,
                BOOT_REMIND_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + BOOT_REMIND_INTERVAL_MS,
                    pendingIntent
            )
        } else {
            alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + BOOT_REMIND_INTERVAL_MS,
                    pendingIntent
            )
        }
        Log.d("Watchdog", "⏰ 부팅 복구 리마인더 1분 후 예약")
    }

    /**
     * 부팅 복구 리마인더 중지
     */
    private fun stopBootRecoveryReminderInternal(context: Context) {
        stopBootRecoveryFull(context)
    }

    /**
     * 1분마다 호출 — 앱이 복구될 때까지 반복 알림
     */
    private fun handleBootRecoveryRemind(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val activeAlarms = prefs.getInt(KEY_ACTIVE_ALARMS, 0)

        // 활성 알람이 없으면 리마인더 중지
        if (activeAlarms <= 0) {
            Log.d("Watchdog", "✅ 활성 알람 없음 — 부팅 복구 리마인더 중지")
            stopBootRecoveryReminderInternal(context)
            return
        }

        // 앱이 한 번이라도 포그라운드에 진입했으면 (사용자가 앱을 열었으면) 리마인더 중지
        val foregroundSeen = prefs.getBoolean(KEY_BOOT_FOREGROUND_SEEN, false)
        if (foregroundSeen) {
            Log.d("Watchdog", "✅ 앱 포그라운드 진입 이력 확인 — 부팅 복구 리마인더 중지")
            stopBootRecoveryReminderInternal(context)
            return
        }

        val remindCount = prefs.getInt(KEY_BOOT_REMIND_COUNT, 0) + 1
        prefs.edit().putInt(KEY_BOOT_REMIND_COUNT, remindCount).apply()

        Log.d("Watchdog", "🔔 부팅 복구 리마인더 #$remindCount (활성 알람: $activeAlarms)")
        showBootRecoveryNotification(context, activeAlarms, remindCount)

        // 다음 1분 후 다시 예약 (setExactAndAllowWhileIdle는 단발성)
        startBootRecoveryReminder(context)
    }

    /**
     * 부팅 후 활성 알람이 있을 때 Full-screen Intent로 앱을 자동 실행하는 알림
     * remindCount: 0=최초, 1+=리마인더 회차
     * 스택 3개까지 쌓고, 이후에는 ID 7777만 갱신하며 계속 알림
     */
    private fun showBootRecoveryNotification(context: Context, activeAlarms: Int, remindCount: Int) {
        try {
            val channelId = "service_watchdog_critical"
            val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 고우선순위 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "⚠️ 앱 복구 알림",
                                        NotificationManager.IMPORTANCE_HIGH
                                )
                                .apply {
                                    description = "부팅 후 앱 자동 복구 알림"
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

            // Full-screen Intent: MainActivity 강제 실행
            val fullScreenIntent =
                    Intent(context, MainActivity::class.java).apply {
                        action = "RESTART_FROM_BOOT_RECOVERY"
                        addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                    }
            val fullScreenPendingIntent =
                    PendingIntent.getActivity(
                            context,
                            8890,
                            fullScreenIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            // 탭 Intent
            val clickIntent =
                    Intent(context, MainActivity::class.java).apply {
                        action = "RESTART_FROM_BOOT_RECOVERY"
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            val clickPendingIntent =
                    PendingIntent.getActivity(
                            context,
                            8891,
                            clickIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            val titleText = if (remindCount == 0)
                "🔄 기기 재부팅 감지 — 앱을 열어주세요"
            else
                "🔔 앱 복구 필요 (#$remindCount)"

            val bodyText = if (remindCount == 0)
                "기기가 재부팅되었습니다.\n\n" +
                        "활성 알람 ${activeAlarms}개가 작동하지 않습니다.\n" +
                        "터치하여 앱을 열어주세요."
            else
                "활성 알람 ${activeAlarms}개가 아직 작동하지 않습니다.\n\n" +
                        "앱을 터치해서 열어주세요.\n" +
                        "(앱을 열기 전까지 1분마다 반복 알림)"

            val notification =
                    NotificationCompat.Builder(context, channelId)
                            .setSmallIcon(android.R.drawable.ic_popup_reminder)
                            .setContentTitle(titleText)
                            .setContentText("활성 알람 ${activeAlarms}개 — 터치하여 앱을 복구하세요.")
                            .setStyle(NotificationCompat.BigTextStyle().bigText(bodyText))
                            .setPriority(NotificationCompat.PRIORITY_MAX)
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setAutoCancel(true)
                            .setContentIntent(clickPendingIntent)
                            .setFullScreenIntent(fullScreenPendingIntent, true)
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .setOnlyAlertOnce(false) // 매번 소리+진동
                            .setColor(0xFFFF0000.toInt())
                            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                            .build()

            // 스택 3개까지 별도 ID, 이후에는 ID 7777만 갱신
            val notificationId = when {
                remindCount < BOOT_REMIND_MAX_STACK -> 7777 + remindCount  // 7777, 7778, 7779
                else -> 7777  // 이후에는 첫 알림만 계속 갱신
            }

            // 스택 3개 초과 시, 기존 알림은 그대로 두고 ID 7777만 소리+진동 재발동
            if (remindCount >= BOOT_REMIND_MAX_STACK) {
                notificationManager.cancel(7777)
            }

            notificationManager.notify(notificationId, notification)
            Log.d("Watchdog", "🚨 부팅 복구 알림 #$remindCount (ID=$notificationId)")
        } catch (e: Exception) {
            Log.e("Watchdog", "❌ 부팅 복구 알림 실패: ${e.message}")
            startBackgroundService(context)
        }
    }

    private fun handleDailyCheck(context: Context, intent: Intent) {
        val hour = intent.getIntExtra("daily_check_hour", -1)
        Log.d("Watchdog", "🗓️ Daily check triggered (hour=$hour)")
        startDailyChecks(context)
        startBackgroundService(context)
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

    // ✅ 앱 프로세스가 실행 중인지 확인 (서비스 포함)
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

    /**
     * 앱이 실제로 포그라운드(사용자가 화면을 보고 있음)인지 확인
     * IMPORTANCE_FOREGROUND(100)만 포그라운드로 판단
     * IMPORTANCE_FOREGROUND_SERVICE(125)는 백그라운드 서비스일 뿐이므로 제외
     */
    private fun isAppInForeground(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val packageName = context.packageName
        val runningProcesses = activityManager.runningAppProcesses ?: return false

        for (processInfo in runningProcesses) {
            if (processInfo.processName == packageName) {
                val importance = processInfo.importance
                val isForeground = importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
                Log.d("Watchdog", "📱 포그라운드 체크: importance=$importance, isForeground=$isForeground")
                return isForeground
            }
        }

        Log.d("Watchdog", "📱 앱 프로세스 없음 — 포그라운드 아님")
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

    private fun isBackgroundServiceRunning(context: Context): Boolean {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val runningServices = activityManager.getRunningServices(Integer.MAX_VALUE)
        for (service in runningServices) {
            if (service.service.className == BackgroundService::class.java.name) {
                Log.d("Watchdog", "✅ BackgroundService running")
                return true
            }
        }
        return false
    }

    private fun startBackgroundService(context: Context) {
        try {
            val intent = Intent(context, BackgroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ContextCompat.startForegroundService(context, intent)
            } else {
                context.startService(intent)
            }
            Log.d("Watchdog", "✅ Daily background service start requested")
        } catch (e: Exception) {
            Log.e("Watchdog", "❌ Daily background service start failed: ${e.message}")
        }
    }

    private fun showCriticalNotification(context: Context, activeAlarms: Int) {
        try {
            val channelId = "service_watchdog_critical"
            val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // ✅ 기존 알림 삭제 후 재생성 → 소리+진동이 매번 다시 울림
            notificationManager.cancel(7777)

            // 고우선순위 채널 생성 (소리+진동 강제)
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
                                    setSound(
                                            android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                                            android.media.AudioAttributes.Builder()
                                                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                                                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                                    .build()
                                    )
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

            // ✅ 매번 진동+소리가 울리도록 DEFAULT_ALL + PRIORITY_HIGH
            val notification =
                    NotificationCompat.Builder(context, channelId)
                            .setSmallIcon(android.R.drawable.ic_popup_reminder)
                            .setContentTitle("🔄 활성 알람이 있어 앱을 복구합니다")
                            .setContentText("활성 알람 ${activeAlarms}개 — 터치하여 앱을 복구하세요.")
                            .setStyle(
                                    NotificationCompat.BigTextStyle()
                                            .bigText(
                                                    "앱이 종료되어 활성 알람 ${activeAlarms}개가 작동하지 않습니다.\n\n" +
                                                    "터치하여 앱을 열어주세요.\n" +
                                                    "(앱을 열기 전까지 반복 알림)"
                                            )
                            )
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .setColor(0xFFFF0000.toInt())
                            .setOnlyAlertOnce(false) // ✅ 매번 소리+진동 재발동
                            .build()

            notificationManager.notify(7777, notification)
            Log.d("Watchdog", "🚨 긴급 알림 표시 완료 (소리+진동 재알림)")
        } catch (e: Exception) {
            Log.e("Watchdog", "❌ 긴급 알림 실패: ${e.message}")
        }
    }
}

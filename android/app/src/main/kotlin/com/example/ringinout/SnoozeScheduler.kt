package com.example.ringinout

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/** AlarmManager를 사용한 스누즈 스케줄링 앱이 죽어도 정확한 시간에 알람이 울림! */
object SnoozeScheduler {

    /**
     * 스누즈 알람 스케줄링
     * @param context Context
     * @param alarmId 알람 ID
     * @param alarmTitle 알람 제목
     * @param delayMinutes 몇 분 후에 울릴지
     */
    fun scheduleSnooze(context: Context, alarmId: Int, alarmTitle: String, delayMinutes: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent =
                Intent(context, SnoozeReceiver::class.java).apply {
                    action = SnoozeReceiver.ACTION_SNOOZE_ALARM
                    putExtra(SnoozeReceiver.EXTRA_ALARM_ID, alarmId)
                    putExtra(SnoozeReceiver.EXTRA_ALARM_TITLE, alarmTitle)
                }

        val pendingIntent =
                PendingIntent.getBroadcast(
                        context,
                        alarmId, // 알람 ID를 request code로 사용
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        val triggerTime = System.currentTimeMillis() + (delayMinutes * 60 * 1000L)

        // ✅ 정확한 시간에 알람 울리도록 설정 (Doze 모드에서도 작동)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerTime,
                    pendingIntent
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent)
        }

        // SharedPreferences에도 백업 저장 (디버깅/확인용)
        val prefs = context.getSharedPreferences("ringinout_snooze", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putLong("snooze_time_$alarmId", triggerTime)
            putString("snooze_title_$alarmId", alarmTitle)
            apply()
        }

        val triggerTimeFormatted =
                java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
                        .format(java.util.Date(triggerTime))
        Log.d(
                "SnoozeScheduler",
                "✅ 스누즈 스케줄 완료: $alarmTitle (${delayMinutes}분 후 = $triggerTimeFormatted)"
        )
    }

    /** 스누즈 알람 취소 */
    fun cancelSnooze(context: Context, alarmId: Int) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent =
                Intent(context, SnoozeReceiver::class.java).apply {
                    action = SnoozeReceiver.ACTION_SNOOZE_ALARM
                }

        val pendingIntent =
                PendingIntent.getBroadcast(
                        context,
                        alarmId,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        alarmManager.cancel(pendingIntent)

        // SharedPreferences에서도 삭제
        val prefs = context.getSharedPreferences("ringinout_snooze", Context.MODE_PRIVATE)
        prefs.edit().apply {
            remove("snooze_time_$alarmId")
            remove("snooze_title_$alarmId")
            apply()
        }

        Log.d("SnoozeScheduler", "🗑️ 스누즈 취소: ID=$alarmId")
    }

    /** 모든 스누즈 알람 취소 */
    fun cancelAllSnoozes(context: Context) {
        val prefs = context.getSharedPreferences("ringinout_snooze", Context.MODE_PRIVATE)
        val allEntries = prefs.all

        for (key in allEntries.keys) {
            if (key.startsWith("snooze_time_")) {
                val alarmId = key.removePrefix("snooze_time_").toIntOrNull() ?: continue
                cancelSnooze(context, alarmId)
            }
        }

        Log.d("SnoozeScheduler", "🗑️ 모든 스누즈 취소 완료")
    }

    /** 스누즈가 예약되어 있는지 확인 */
    fun isSnoozeScheduled(context: Context, alarmId: Int): Boolean {
        val prefs = context.getSharedPreferences("ringinout_snooze", Context.MODE_PRIVATE)
        val snoozeTime = prefs.getLong("snooze_time_$alarmId", 0)
        return snoozeTime > System.currentTimeMillis()
    }
}

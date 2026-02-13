package com.example.ringinout.basic

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object BasicAlarmScheduler {
    private const val TAG = "BasicAlarmScheduler"
    private const val PREFS = "basic_alarm_prefs"
    private const val KEY_ALARMS = "alarms_json"

    fun scheduleAlarm(context: Context, alarm: Map<String, Any?>) {
        val id = alarm["id"] as? String ?: return
        val enabled = alarm["enabled"] as? Boolean ?: true
        if (!enabled) {
            cancelAlarm(context, id)
            return
        }

        val hour = (alarm["hour"] as? Number)?.toInt() ?: 7
        val minute = (alarm["minute"] as? Number)?.toInt() ?: 0
        val label = (alarm["label"] as? String)?.ifBlank { "알람" } ?: "알람"
        val repeat = alarm["repeat"] as? List<*>
        val repeatDays = repeat?.mapNotNull { it?.toString() } ?: emptyList()

        persistAlarm(context, id, alarm)

        val nextAt = NextOccurrence.computeNextTimeMillis(hour, minute, repeatDays)
        if (nextAt <= 0L) {
            Log.w(TAG, "nextAt 계산 실패: $id")
            return
        }

        val requestCode = id.hashCode()
        val intent =
                Intent(context, BasicAlarmReceiver::class.java).apply {
                    action = "com.example.ringinout.ACTION_BASIC_ALARM"
                    putExtra("id", id)
                    putExtra("label", label)
                    putExtra("hour", hour)
                    putExtra("minute", minute)
                    putStringArrayListExtra("repeatDays", ArrayList(repeatDays))
                }

        val pi =
                PendingIntent.getBroadcast(
                        context,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextAt, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, nextAt, pi)
        }

        Log.d(TAG, "✅ 기본 알람 예약: $label ($id) -> $nextAt")
    }

    fun cancelAlarm(context: Context, alarmId: String) {
        val requestCode = alarmId.hashCode()
        val intent =
                Intent(context, BasicAlarmReceiver::class.java).apply {
                    action = "com.example.ringinout.ACTION_BASIC_ALARM"
                    putExtra("id", alarmId)
                }
        val pi =
                PendingIntent.getBroadcast(
                        context,
                        requestCode,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi)
        pi.cancel()
        Log.d(TAG, "🗑️ 기본 알람 취소: $alarmId")
    }

    fun rescheduleAll(context: Context, alarms: List<Map<String, Any?>>) {
        alarms.forEach { scheduleAlarm(context, it) }
    }

    private fun persistAlarm(context: Context, id: String, alarm: Map<String, Any?>) {
        // 최소 구현: SharedPreferences에 단일 알람 JSON 저장 대신, Dart가 rescheduleAll을 호출하게 유지
        // (추후 리시버에서 반복 재예약을 원하면 여기서 전체 JSON으로 확장 가능)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putString("alarm_$id", alarm.toString()).apply()
    }
}

object NextOccurrence {
    private val weekdays = listOf('일', '월', '화', '수', '목', '금', '토')

    fun computeNextTimeMillis(hour: Int, minute: Int, repeatDays: List<String>): Long {
        val now = java.util.Calendar.getInstance()
        val target = java.util.Calendar.getInstance()
        target.set(java.util.Calendar.SECOND, 0)
        target.set(java.util.Calendar.MILLISECOND, 0)
        target.set(java.util.Calendar.HOUR_OF_DAY, hour)
        target.set(java.util.Calendar.MINUTE, minute)

        if (repeatDays.isEmpty()) {
            if (target.timeInMillis <= now.timeInMillis) {
                target.add(java.util.Calendar.DAY_OF_YEAR, 1)
            }
            return target.timeInMillis
        }

        // repeatDays는 ['월','화'...] 형태
        val todayIdx = (now.get(java.util.Calendar.DAY_OF_WEEK) - 1) // 0=일

        for (offset in 0..7) {
            val idx = (todayIdx + offset) % 7
            val dayStr = weekdays[idx].toString()
            if (!repeatDays.contains(dayStr)) continue

            val candidate = java.util.Calendar.getInstance()
            candidate.set(java.util.Calendar.SECOND, 0)
            candidate.set(java.util.Calendar.MILLISECOND, 0)
            candidate.add(java.util.Calendar.DAY_OF_YEAR, offset)
            candidate.set(java.util.Calendar.HOUR_OF_DAY, hour)
            candidate.set(java.util.Calendar.MINUTE, minute)

            if (candidate.timeInMillis > now.timeInMillis) {
                return candidate.timeInMillis
            }
        }

        // 폴백: 1주 후
        target.add(java.util.Calendar.DAY_OF_YEAR, 7)
        return target.timeInMillis
    }
}

package com.example.ringinout.basic

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import com.example.ringinout.AlarmFullscreenActivity
import com.example.ringinout.flutterRingtone

class BasicAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BasicAlarmReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        val label = intent.getStringExtra("label") ?: "알람"
        val hour = intent.getIntExtra("hour", 7)
        val minute = intent.getIntExtra("minute", 0)
        val repeatDays = intent.getStringArrayListExtra("repeatDays")?.toList() ?: emptyList()
        val alarmIdInt = id.hashCode()

        Log.d(TAG, "⏰ 기본 알람 트리거: $label ($id)")

        // 벨소리 시작 (MainActivity 채널 없이도 동작)
        try {
            if (flutterRingtone?.isPlaying == true) {
                Log.d(TAG, "⚠️ 벨소리 이미 재생 중")
            } else {
                val alarmUri =
                        RingtoneManager.getActualDefaultRingtoneUri(
                                context,
                                RingtoneManager.TYPE_ALARM
                        )
                                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

                flutterRingtone = RingtoneManager.getRingtone(context, alarmUri)
                flutterRingtone?.isLooping = true

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    val attrs =
                            AudioAttributes.Builder()
                                    .setUsage(AudioAttributes.USAGE_ALARM)
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .build()
                    flutterRingtone?.audioAttributes = attrs
                }
                flutterRingtone?.play()
                Log.d(TAG, "🔔 기본 알람 벨소리 재생 시작")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 벨소리 재생 실패: ${e.message}")
        }

        // 전체화면 액티비티
        val fsIntent =
                Intent(context, AlarmFullscreenActivity::class.java).apply {
                    putExtra("title", label)
                    putExtra("message", "알람")
                    putExtra("alarmId", alarmIdInt)
                    putExtra("isBackgroundAlarm", true)
                    addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                    Intent.FLAG_ACTIVITY_NO_HISTORY
                    )
                }

        try {
            context.startActivity(fsIntent)
        } catch (e: Exception) {
            Log.e(TAG, "❌ 전체화면 실행 실패: ${e.message}")
        }

        // 반복 알람이면 여기서 다음 회차를 즉시 재예약 (앱이 죽어 있어도 반복 동작)
        if (repeatDays.isNotEmpty()) {
            try {
                val nextAt = NextOccurrence.computeNextTimeMillis(hour, minute, repeatDays)
                val requestCode = id.hashCode()

                val nextIntent =
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
                                nextIntent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )

                val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextAt, pi)
                } else {
                    am.setExact(AlarmManager.RTC_WAKEUP, nextAt, pi)
                }

                Log.d(TAG, "🔁 반복 알람 재예약: $label ($id) -> $nextAt")
            } catch (e: Exception) {
                Log.e(TAG, "❌ 반복 알람 재예약 실패: ${e.message}")
            }
        }
    }
}

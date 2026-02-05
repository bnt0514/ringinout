package com.example.ringinout

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/** AlarmManager에서 호출되어 스누즈 알람을 트리거하는 BroadcastReceiver 앱이 죽어 있어도 작동함! */
class SnoozeReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_SNOOZE_ALARM = "com.example.ringinout.ACTION_SNOOZE_ALARM"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_DATA = "alarm_data"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SnoozeReceiver", "⏰ 스누즈 알람 수신!")

        if (intent.action == ACTION_SNOOZE_ALARM) {
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            val alarmTitle = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "위치 알람"

            Log.d("SnoozeReceiver", "📢 스누즈 알람 트리거: $alarmTitle (ID: $alarmId)")

            // 1. 전체화면 알람 Activity 시작
            launchFullScreenAlarm(context, alarmId, alarmTitle)

            // 2. 벨소리 재생 (서비스에서 처리)
            startAlarmService(context, alarmId, alarmTitle)
        }
    }

    private fun launchFullScreenAlarm(context: Context, alarmId: Int, title: String) {
        try {
            val intent =
                    Intent(context, AlarmFullscreenActivity::class.java).apply {
                        putExtra("title", title)
                        putExtra("message", "스누즈 알람이 울립니다")
                        putExtra("alarmId", alarmId)
                        putExtra("isSnoozeAlarm", true)
                        addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                        )
                    }
            context.startActivity(intent)
            Log.d("SnoozeReceiver", "✅ 전체화면 알람 시작")
        } catch (e: Exception) {
            Log.e("SnoozeReceiver", "❌ 전체화면 알람 시작 실패: ${e.message}")
            // 실패 시 알림이라도 표시
            showFallbackNotification(context, alarmId, title)
        }
    }

    private fun startAlarmService(context: Context, alarmId: Int, title: String) {
        try {
            // MainActivity로 알람 재생 요청
            val serviceIntent =
                    Intent(context, MainActivity::class.java).apply {
                        action = "PLAY_SNOOZE_ALARM"
                        putExtra("alarmId", alarmId)
                        putExtra("title", title)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
            context.startActivity(serviceIntent)
        } catch (e: Exception) {
            Log.e("SnoozeReceiver", "❌ 알람 서비스 시작 실패: ${e.message}")
        }
    }

    private fun showFallbackNotification(context: Context, alarmId: Int, title: String) {
        try {
            val channelId = "snooze_alarm_channel"
            val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 채널 생성
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel =
                        NotificationChannel(
                                        channelId,
                                        "스누즈 알람",
                                        NotificationManager.IMPORTANCE_HIGH
                                )
                                .apply {
                                    description = "스누즈 알람 알림"
                                    enableVibration(true)
                                }
                notificationManager.createNotificationChannel(channel)
            }

            // 알림 클릭 시 앱 열기
            val clickIntent =
                    Intent(context, MainActivity::class.java).apply {
                        putExtra("fromSnooze", true)
                        putExtra("alarmId", alarmId)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    }
            val pendingIntent =
                    PendingIntent.getActivity(
                            context,
                            alarmId,
                            clickIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )

            val notification =
                    NotificationCompat.Builder(context, channelId)
                            .setSmallIcon(android.R.drawable.ic_popup_reminder)
                            .setContentTitle("⏰ $title")
                            .setContentText("스누즈 알람이 울립니다! 터치하여 확인하세요.")
                            .setPriority(NotificationCompat.PRIORITY_HIGH)
                            .setCategory(NotificationCompat.CATEGORY_ALARM)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)
                            .setDefaults(NotificationCompat.DEFAULT_ALL)
                            .build()

            notificationManager.notify(alarmId + 1000, notification)
            Log.d("SnoozeReceiver", "✅ 폴백 알림 표시")
        } catch (e: Exception) {
            Log.e("SnoozeReceiver", "❌ 폴백 알림도 실패: ${e.message}")
        }
    }
}

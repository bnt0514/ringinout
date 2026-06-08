package com.bnt0514.ringinout

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
        const val ACTION_SNOOZE_ALARM = "com.bnt0514.ringinout.ACTION_SNOOZE_ALARM"
        const val EXTRA_ALARM_ID = "alarm_id"
        const val EXTRA_ALARM_TITLE = "alarm_title"
        const val EXTRA_ALARM_DATA = "alarm_data"
        const val EXTRA_ALARM_KEY = "alarm_key"
        const val EXTRA_PLACE_ID = "place_id"
        const val EXTRA_OWNER_UID = "owner_uid"
        const val EXTRA_IS_REPEAT = "is_repeat"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d("SnoozeReceiver", "⏰ 스누즈 알람 수신!")

        if (intent.action == ACTION_SNOOZE_ALARM) {
            val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
            val alarmTitle = intent.getStringExtra(EXTRA_ALARM_TITLE) ?: "위치 알람"
            val alarmKey = intent.getStringExtra(EXTRA_ALARM_KEY) ?: ""
            val placeId = intent.getStringExtra(EXTRA_PLACE_ID) ?: ""
            val ownerUid = intent.getStringExtra(EXTRA_OWNER_UID) ?: ""
            val isRepeat = intent.getBooleanExtra(EXTRA_IS_REPEAT, false)

            Log.d(
                    "SnoozeReceiver",
                    "📢 스누즈 알람 트리거: $alarmTitle (ID: $alarmId, alarmKey: $alarmKey, placeId: $placeId, isRepeat: $isRepeat)"
            )

            if (!isCurrentOwner(context, ownerUid)) {
                Log.w("SnoozeReceiver", "⛔ 스누즈 폐기 — 현재 계정 알람 아님: $alarmKey")
                return
            }

            // 1. 전체화면 알람 Activity 시작 (벨소리도 Activity 내에서 재생)
            launchFullScreenAlarm(context, alarmId, alarmTitle, alarmKey, placeId, ownerUid, isRepeat)

            // ✅ 제거: startAlarmService()가 MainActivity를 띄워서
            //    AlarmFullscreenActivity를 가리는 문제 해결
            //    벨소리는 AlarmFullscreenActivity.onCreate에서 직접 재생
        }
    }

    private fun launchFullScreenAlarm(
            context: Context,
            alarmId: Int,
            title: String,
            alarmKey: String,
            placeId: String,
            ownerUid: String,
            isRepeat: Boolean = false
    ) {
        try {
            val intent =
                    Intent(context, AlarmFullscreenActivity::class.java).apply {
                        putExtra("title", title)
                        putExtra("message", "스누즈 알람이 울립니다")
                        putExtra("alarmId", alarmId)
                        putExtra("alarmKey", alarmKey)
                        putExtra("placeId", placeId)
                        putExtra("ownerUid", ownerUid)
                        putExtra("isSnoozeAlarm", true)
                        putExtra("isRepeat", isRepeat) // ✅ 반복 알람 여부 전달
                        // ✅ 스택 호환: CLEAR_TOP 제거
                        addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
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

    // ✅ startAlarmService 제거 — MainActivity를 띄우면 AlarmFullscreenActivity를 가림
    // 벨소리는 AlarmFullscreenActivity.onCreate에서 직접 재생

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

    private fun isCurrentOwner(context: Context, ownerUid: String): Boolean {
        if (ownerUid.isEmpty()) {
            Log.w("SnoozeReceiver", "⛔ ownerUid 없는 스누즈 폐기")
            return false
        }

        val nativePrefs = context.getSharedPreferences("smart_location_prefs", Context.MODE_PRIVATE)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val current = (nativePrefs.getString("active_owner_uid", "") ?: "")
                .ifEmpty { flutterPrefs.getString("flutter.active_owner_uid", "") ?: "" }
        if (current.isEmpty()) return false

        return current == ownerUid
    }
}

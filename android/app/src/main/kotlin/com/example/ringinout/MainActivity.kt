package com.example.ringinout

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ Android 8.0 이상에서 알림 채널 필수
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ringinout_channel", // ⚠️ 이 ID는 foregroundService 설정에서 썼던 것과 같아야 해
                "Ringinout Alarm",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Ringinout 위치 기반 알람 알림 채널"
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}

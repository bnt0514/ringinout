package com.example.ringinout

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ✅ 알림 채널 생성
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "ringinout_channel",
                "Ringinout Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Ringinout 위치 기반 알람 알림 채널"
                setSound(null, null) // ✅ 시스템 기본 벨소리 제거
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        // ✅ MethodChannel: 벨소리 강제 재생
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.ringinout/audio")
            .setMethodCallHandler { call, result ->
                if (call.method == "playRingtoneLoud") {
                    playRingtoneLoud()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // ✅ MethodChannel: DND 권한 요청
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ringinout/permissions")
            .setMethodCallHandler { call, result ->
                if (call.method == "requestDndPermission") {
                    requestDndPermission()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // ✅ MethodChannel: 전체화면 알람 페이지 실행
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.ringinout/fullscreen")
            .setMethodCallHandler { call, result ->
                if (call.method == "launchAlarmPage") {
                    val title = call.argument<String>("title") ?: "Ringinout 알람"
                    val sound = call.argument<String>("soundPath") ?: "assets/sounds/thoughtfulringtone.mp3"
                    launchAlarmPage(title, sound)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun playRingtoneLoud() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // ✅ 벨소리 모드 최대 볼륨으로 설정
        audioManager.ringerMode = AudioManager.RINGER_MODE_NORMAL
        audioManager.setStreamVolume(
            AudioManager.STREAM_RING,
            audioManager.getStreamMaxVolume(AudioManager.STREAM_RING),
            0
        )

        val notificationUri: Uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
        ringtone = RingtoneManager.getRingtone(applicationContext, notificationUri)
        ringtone?.play()
    }

    private fun requestDndPermission() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !notificationManager.isNotificationPolicyAccessGranted) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        }
    }

    private fun launchAlarmPage(title: String, soundPath: String) {
        Handler(Looper.getMainLooper()).post {
            val intent = Intent(this, AlarmFullscreenActivity::class.java).apply {
                putExtra("title", title)
                putExtra("soundPath", soundPath)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        ringtone?.stop()
    }
}

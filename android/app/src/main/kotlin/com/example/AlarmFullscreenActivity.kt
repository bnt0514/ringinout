package com.example.ringinout

import android.app.Activity
import android.media.MediaPlayer
import android.os.Bundle
import android.view.WindowManager
import android.os.PowerManager
import android.content.Context
import android.view.Window
import android.content.Intent

class AlarmFullscreenActivity : Activity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ 화면이 꺼져 있어도 알람 창을 켜도록 설정
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        // ✅ 화면 밝기 잠금 해제
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "ringinout:AlarmWakeLock"
        )
        wakeLock.acquire(10 * 60 * 1000L /*10 minutes*/)

        // ✅ 알람 화면 구성 (필요 시 레이아웃 xml 만들어서 setContentView로 연결 가능)
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)

        // ✅ 벨소리 재생
        playAlarmSound()
    }

    private fun playAlarmSound() {
        val assetFileDescriptor = assets.openFd("sounds/thoughtfulringtone.mp3")
        mediaPlayer = MediaPlayer()
        mediaPlayer?.apply {
            setDataSource(
                assetFileDescriptor.fileDescriptor,
                assetFileDescriptor.startOffset,
                assetFileDescriptor.length
            )
            isLooping = true
            prepare()
            start()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }
}

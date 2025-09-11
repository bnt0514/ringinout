package com.example.ringinout

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmFullscreenActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 화면을 깨우고 전체화면으로 표시
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        // 전달받은 alarmId 넘겨서 Flutter로 이동시키기 (MainActivity)
        val alarmId = intent.getIntExtra("alarmId", -1)
        val flutterIntent = Intent(this, MainActivity::class.java).apply {
            putExtra("alarmId", alarmId)
            putExtra("navigate_to_fullscreen", true)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        startActivity(flutterIntent)
        finish()
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // 터치 이벤트는 무시 (화면 전환 전용이므로)
        return super.onTouchEvent(event)
    }
}

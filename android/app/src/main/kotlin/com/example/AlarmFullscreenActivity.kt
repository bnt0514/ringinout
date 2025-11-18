package com.example.ringinout

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.util.Log

class AlarmFullscreenActivity : Activity() {
    
    private var alarmId: Int = -1
    private var alarmTitle: String = "위치 알람"
    private var triggerCount: Int = 0
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d("AlarmFullscreen", "🔔 전체화면 알람 Activity 시작")

        // 화면을 깨우고 전체화면으로 표시
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )

        // Intent에서 데이터 가져오기
        alarmId = intent.getIntExtra("alarmId", -1)
        alarmTitle = intent.getStringExtra("title") ?: "위치 알람"
        
        // SharedPreferences에서 triggerCount 가져오기
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        triggerCount = prefs.getInt("trigger_count_$alarmId", 0)
        
        Log.d("AlarmFullscreen", "📋 알람 정보: ID=$alarmId, 제목=$alarmTitle, 트리거=$triggerCount")
        
        // ✅ 네이티브 UI 생성
        setupNativeUI()
    }
    
    private fun setupNativeUI() {
        // 전체 레이아웃 (검은색 배경)
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.BLACK)
            gravity = Gravity.CENTER
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        }
        
        // 알람 제목 텍스트
        val titleText = TextView(this).apply {
            text = alarmTitle
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(40, 100, 40, 100)
        }
        mainLayout.addView(titleText)
        
        // 버튼 컨테이너
        val buttonContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(0, 200, 0, 0)
        }
        
        // "다시 울림" 버튼 (파란색)
        val snoozeButton = Button(this).apply {
            text = "다시 울림"
            textSize = 20f
            setTextColor(Color.WHITE)
            setBackgroundColor(Color.parseColor("#2196F3"))
            layoutParams = LinearLayout.LayoutParams(750, 180).apply {
                bottomMargin = 40
            }
            setOnClickListener {
                Log.d("AlarmFullscreen", "🔵 다시 울림 버튼 클릭")
                showSnoozeOptions()
            }
        }
        buttonContainer.addView(snoozeButton)
        
        // "알람 종료" 버튼 (빨간색) - triggerCount >= 2일 때만 표시
        if (triggerCount >= 2) {
            val dismissButton = Button(this).apply {
                text = "알람 종료"
                textSize = 20f
                setTextColor(Color.WHITE)
                setBackgroundColor(Color.parseColor("#F44336"))
                layoutParams = LinearLayout.LayoutParams(750, 180)
                setOnClickListener {
                    Log.d("AlarmFullscreen", "🔴 알람 종료 버튼 클릭")
                    dismissAlarm()
                }
            }
            buttonContainer.addView(dismissButton)
        }
        
        mainLayout.addView(buttonContainer)
        setContentView(mainLayout)
        
        Log.d("AlarmFullscreen", "✅ 네이티브 UI 생성 완료")
    }
    
    private fun showSnoozeOptions() {
        // 스누즈 시간 선택 다이얼로그
        val options = arrayOf("1분 후", "3분 후", "5분 후", "10분 후", "30분 후")
        val minutes = arrayOf(1, 3, 5, 10, 30)
        
        val builder = android.app.AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
        builder.setTitle("다시 울림 시간 선택")
        builder.setItems(options) { dialog, which ->
            val selectedMinutes = minutes[which]
            scheduleSnooze(selectedMinutes)
            stopAlarmAndGoHome()
        }
        builder.setOnCancelListener {
            // 취소하면 그냥 홈으로
            stopAlarmAndGoHome()
        }
        builder.show()
    }
    
    private fun scheduleSnooze(minutes: Int) {
        Log.d("AlarmFullscreen", "⏰ 스누즈 설정: ${minutes}분 후")
        
        // SharedPreferences에 스누즈 정보 저장
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        val snoozeTime = System.currentTimeMillis() + (minutes * 60 * 1000)
        
        prefs.edit().apply {
            putLong("snooze_time_$alarmId", snoozeTime)
            putInt("snooze_minutes_$alarmId", minutes)
            putString("snooze_alarm_title_$alarmId", alarmTitle)
            apply()
        }
        
        Log.d("AlarmFullscreen", "✅ 스누즈 저장 완료: ${minutes}분 후")
    }
    
    private fun dismissAlarm() {
        Log.d("AlarmFullscreen", "🔴 알람 종료 처리")
        
        // triggerCount 초기화
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        prefs.edit().remove("trigger_count_$alarmId").apply()
        
        // 목표 달성 기록 (Flutter에 전달)
        val intent = Intent("com.example.ringinout.ALARM_DISMISSED").apply {
            putExtra("alarmId", alarmId)
            putExtra("achieved", true)
        }
        sendBroadcast(intent)
        
        stopAlarmAndGoHome()
    }
    
    private fun stopAlarmAndGoHome() {
        // 벨소리 정지
        try {
            // ✅ MainActivity의 전역 변수 사용
            flutterRingtone?.stop()
            flutterRingtone = null
            Log.d("AlarmFullscreen", "🔕 벨소리 정지")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 벨소리 정지 실패: ${e.message}")
        }
        
        // 홈 화면으로 이동
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        
        // Activity 종료
        finish()
        
        Log.d("AlarmFullscreen", "✅ 홈 화면으로 복귀")
    }
    
    override fun onBackPressed() {
        // 뒤로가기 버튼 - 알람 정지하고 홈으로
        Log.d("AlarmFullscreen", "🔙 뒤로가기 버튼 클릭")
        stopAlarmAndGoHome()
    }
    
    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // 화면 터치는 허용 (버튼 클릭 가능하도록)
        return super.onTouchEvent(event)
    }
}

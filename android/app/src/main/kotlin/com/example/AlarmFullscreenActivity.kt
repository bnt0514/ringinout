package com.example.ringinout

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmFullscreenActivity : Activity() {

    private var alarmId: Int = -1
    private var alarmTitle: String = "위치 알람"
    private var triggerCount: Int = 0
    private var placeId: String = ""

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
        placeId = intent.getStringExtra("placeId") ?: ""

        // SharedPreferences에서 triggerCount 가져오기
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        triggerCount = prefs.getInt("trigger_count_$alarmId", 0)

        Log.d("AlarmFullscreen", "📋 알람 정보: ID=$alarmId, 제목=$alarmTitle, 트리거=$triggerCount")

        // 스누즈 알람이 실제로 울리기 시작하면 snoozed + disabled 플래그 해제
        val isSnoozeAlarm = intent.getBooleanExtra("isSnoozeAlarm", false)
        if (isSnoozeAlarm && placeId.isNotEmpty()) {
            val flutterPrefs =
                    getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                remove("flutter.alarm_snoozed_$placeId")
                remove("flutter.alarm_disabled_$placeId")
                apply()
            }
            Log.d("AlarmFullscreen", "✅ 스누즈 플래그 + 비활성화 해제: $placeId")
        }

        // ✅ 네이티브 UI 생성
        setupNativeUI()

        // ✅ 벨소리 직접 재생 (SnoozeReceiver/일반 알람 모두 여기서 재생)
        playAlarmRingtone()
    }

    /// 알람 벨소리 직접 재생 (MainActivity 의존 제거)
    private fun playAlarmRingtone() {
        try {
            // 이미 울리고 있으면 중복 방지
            if (flutterRingtone?.isPlaying == true) {
                Log.d("AlarmFullscreen", "⚠️ 벨소리 이미 재생 중")
                return
            }

            flutterRingtone?.stop()
            flutterRingtone = null

            val alarmUri =
                    RingtoneManager.getActualDefaultRingtoneUri(this, RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

            flutterRingtone = RingtoneManager.getRingtone(this, alarmUri)
            flutterRingtone?.isLooping = true

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val attrs =
                        AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                flutterRingtone?.audioAttributes = attrs
            }

            flutterRingtone?.play()
            Log.d("AlarmFullscreen", "🔔 알람 벨소리 직접 재생 시작")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 벨소리 재생 실패: ${e.message}")
        }
    }

    private fun setupNativeUI() {
        // 전체 레이아웃 (검은색 배경)
        val mainLayout =
                LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    setBackgroundColor(Color.BLACK)
                    gravity = Gravity.CENTER
                    layoutParams =
                            ViewGroup.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT
                            )
                }

        // 알람 제목 텍스트
        val titleText =
                TextView(this).apply {
                    text = alarmTitle
                    textSize = 28f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    setPadding(40, 100, 40, 100)
                }
        mainLayout.addView(titleText)

        // 버튼 컨테이너
        val buttonContainer =
                LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setPadding(0, 200, 0, 0)
                }

        // "다시 울림" 버튼 (파란색)
        val snoozeButton =
                Button(this).apply {
                    text = "다시 울림"
                    textSize = 20f
                    setTextColor(Color.WHITE)
                    setBackgroundColor(Color.parseColor("#2196F3"))
                    layoutParams = LinearLayout.LayoutParams(750, 180).apply { bottomMargin = 40 }
                    setOnClickListener {
                        Log.d("AlarmFullscreen", "🔵 다시 울림 버튼 클릭")
                        showSnoozeOptions()
                    }
                }
        buttonContainer.addView(snoozeButton)

        // "알람 종료" 버튼 (빨간색) - ✅ 항상 표시
        val dismissButton =
                Button(this).apply {
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

        mainLayout.addView(buttonContainer)
        setContentView(mainLayout)

        Log.d("AlarmFullscreen", "✅ 네이티브 UI 생성 완료")
    }

    private fun showSnoozeOptions() {
        // 스누즈 시간 선택 다이얼로그
        val options = arrayOf("1분 후", "3분 후", "5분 후", "10분 후", "30분 후")
        val minutes = arrayOf(1, 3, 5, 10, 30)

        val builder =
                android.app.AlertDialog.Builder(
                        this,
                        android.R.style.Theme_DeviceDefault_Dialog_Alert
                )
        builder.setTitle("다시 울림 시간 선택")
        builder.setItems(options) { dialog, which ->
            val selectedMinutes = minutes[which]
            scheduleSnooze(selectedMinutes)
            stopAlarmAndGoHome()
        }
        // ✅ 취소 버튼 추가 — 알람 화면으로 돌아감
        builder.setNegativeButton("취소") { dialog, _ ->
            Log.d("AlarmFullscreen", "🔙 스누즈 취소 → 알람 화면으로 복귀")
            dialog.dismiss()
            // 벨소리가 꺼져있으면 다시 재생
            if (flutterRingtone?.isPlaying != true) {
                playAlarmRingtone()
            }
        }
        builder.setCancelable(false) // ✅ 바깥 터치로 닫기 방지 (취소 버튼으로만 닫기)
        builder.show()
    }

    private fun scheduleSnooze(minutes: Int) {
        Log.d("AlarmFullscreen", "⏰ 스누즈 설정: ${minutes}분 후")

        // ✅ 스누즈 시 알람 비활성화 + 재트리거 방지 플래그 설정
        if (placeId.isNotEmpty()) {
            val flutterPrefs =
                    getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                putBoolean("flutter.alarm_snoozed_$placeId", true)
                putBoolean("flutter.alarm_disabled_$placeId", true)
                apply()
            }
            Log.d("AlarmFullscreen", "🔕 스누즈 플래그 + 비활성화 설정: $placeId")
        }

        // ✅ AlarmManager 기반 스누즈 스케줄링 (앱이 죽어도 작동!)
        SnoozeScheduler.scheduleSnooze(this, alarmId, alarmTitle, minutes, placeId)

        Log.d("AlarmFullscreen", "✅ AlarmManager 스누즈 스케줄 완료: ${minutes}분 후")
    }

    private fun dismissAlarm() {
        Log.d("AlarmFullscreen", "🔴 알람 종료 처리")

        // triggerCount 초기화
        // ✅ FlutterSharedPreferences에 기록 (Flutter shared_preferences 플러그인과 일치)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            putBoolean("flutter.alarm_disabled_$placeId", true)
            apply()
        }

        // ✅ 알람 해제 처리는 Flutter 측 LocationMonitorService에서 관리
        // (네이티브 SmartLocationManager는 신호 전달만 담당)
        if (placeId.isNotEmpty()) {
            Log.d("AlarmFullscreen", "✅ 알람 해제 완료: $placeId (Flutter 측 관리)")
        }

        // ✅ 스누즈 스케줄도 취소
        SnoozeScheduler.cancelSnooze(this, alarmId)

        // 목표 달성 기록 (Flutter에 전달)
        val intent =
                Intent("com.example.ringinout.ALARM_DISMISSED").apply {
                    putExtra("alarmId", alarmId)
                    putExtra("achieved", true)
                    putExtra("disabled", true) // ✅ 비활성화됨
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

        // ✅ 영구 푸쉬 알림 제거 (ID: 999)
        try {
            val notificationManager =
                    getSystemService(Context.NOTIFICATION_SERVICE) as
                            android.app.NotificationManager
            notificationManager.cancel(999)
            Log.d("AlarmFullscreen", "🔕 영구 알림 제거")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 영구 알림 제거 실패: ${e.message}")
        }

        // ✅ 앱 메인화면(MainActivity)으로 복귀
        val mainIntent =
                Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
        startActivity(mainIntent)

        // Activity 종료
        finish()

        Log.d("AlarmFullscreen", "✅ 앱 메인화면으로 복귀")
    }

    override fun onBackPressed() {
        // ✅ 뒤로가기 차단 — 사용자가 반드시 다시 울림 또는 알람 종료를 선택해야 함
        Log.d("AlarmFullscreen", "🔙 뒤로가기 차단됨 — 선택 필요")
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // 화면 터치는 허용 (버튼 클릭 가능하도록)
        return super.onTouchEvent(event)
    }
}

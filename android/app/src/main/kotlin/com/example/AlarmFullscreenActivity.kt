package com.example.ringinout

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView

class AlarmFullscreenActivity : Activity() {

    companion object {
        /** AlarmFullscreenActivity가 현재 화면에 표시 중인지 여부.
         *  MainActivity.playDefaultRingtone()에서 이중 재생 방지에 사용. */
        var isActive: Boolean = false
    }

    private var alarmId: Int = -1
    private var alarmTitle: String = "위치 알람"
    private var triggerCount: Int = 0
    private var placeId: String = ""

    // ✅ 알람 종료 중 플래그 — stopAlarmAndGoHome()에서 startActivity() 호출 시
    // onUserLeaveHint()가 트리거되어 native_alarm_active를 다시 true로 설정하는 것을 방지
    private var isAlarmDismissing: Boolean = false

    // ✅ 볼륨 에스컬레이션
    private var originalVolume: Int = -1
    private val volumeHandler = Handler(Looper.getMainLooper())
    private var volumeEscalationRunnable: Runnable? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d("AlarmFullscreen", "🔔 전체화면 알람 Activity 시작")
        AlarmFullscreenActivity.isActive = true

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

        // ✅ 뒤로가기 완전 차단 (Android 13+ onBackPressedDispatcher)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                    android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT
            ) {
                Log.d("AlarmFullscreen", "🔙 뒤로가기 차단됨 (OnBackInvoked) — 선택 필요")
                // 아무것도 안 함 → 뒤로가기 무시
            }
        }

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

        // ✅ 볼륨 에스컬레이션 시작
        startVolumeEscalation()
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

    /// 볼륨 단계적 증가 — 현재 볼륨 5 이하인 경우에만 동작
    /// 10초 후 → 5, 15초 후 → 7, 20초 후 → 10 (최대)
    private fun startVolumeEscalation() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            originalVolume = audioManager.getStreamVolume(AudioManager.STREAM_ALARM)

            // 볼륨 스케일 변환: 기기 최대볼륨 기준으로 1~10 범위 계산
            val currentLevel = if (maxVolume > 0) (originalVolume * 10 / maxVolume) else 10

            Log.d("AlarmFullscreen", "🔊 현재 볼륨: $originalVolume/$maxVolume (레벨: $currentLevel)")

            if (currentLevel > 5) {
                Log.d("AlarmFullscreen", "✅ 볼륨 충분 — 에스컬레이션 생략")
                return
            }

            Log.d("AlarmFullscreen", "📈 볼륨 에스컬레이션 시작 (10초 후 5→7→10)")

            val step5 = (maxVolume * 5 / 10)
            val step7 = (maxVolume * 7 / 10)
            val step10 = maxVolume

            volumeEscalationRunnable = Runnable {
                // 10초 후: 레벨 5
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, step5, 0)
                Log.d("AlarmFullscreen", "🔊 볼륨 → 5/10")

                volumeHandler.postDelayed({
                    // 15초 후: 레벨 7
                    audioManager.setStreamVolume(AudioManager.STREAM_ALARM, step7, 0)
                    Log.d("AlarmFullscreen", "🔊 볼륨 → 7/10")

                    volumeHandler.postDelayed({
                        // 20초 후: 레벨 10 (최대)
                        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, step10, 0)
                        Log.d("AlarmFullscreen", "🔊 볼륨 → 최대 (10/10)")
                    }, 5000L)
                }, 5000L)
            }
            volumeHandler.postDelayed(volumeEscalationRunnable!!, 10000L)
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 볼륨 에스컬레이션 실패: ${e.message}")
        }
    }

    /// 볼륨 에스컬레이션 취소 및 원래 볼륨 복원
    private fun restoreVolume() {
        try {
            volumeEscalationRunnable?.let { volumeHandler.removeCallbacks(it) }
            volumeHandler.removeCallbacksAndMessages(null)
            if (originalVolume >= 0) {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, originalVolume, 0)
                Log.d("AlarmFullscreen", "🔊 볼륨 원래대로 복원: $originalVolume")
            }
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 볼륨 복원 실패: ${e.message}")
        }
    }

    private fun setupNativeUI() {
        // ✅ Flutter FullScreenAlarmPage와 동일한 디자인
        // AppColors: textPrimary=#1A1A1A, primary=#FF5A1F, danger=#E53935, textOnPrimary=#FFFFFF

        val dp = { value: Int ->
            TypedValue.applyDimension(
                    TypedValue.COMPLEX_UNIT_DIP,
                    value.toFloat(),
                    resources.displayMetrics
            ).toInt()
        }

        // 전체 레이아웃 (AppColors.textPrimary 배경 — 거의 검정)
        val rootLayout =
                FrameLayout(this).apply {
                    setBackgroundColor(Color.parseColor("#1A1A1A"))
                    layoutParams =
                            ViewGroup.LayoutParams(
                                    ViewGroup.LayoutParams.MATCH_PARENT,
                                    ViewGroup.LayoutParams.MATCH_PARENT
                            )
                }

        // 알람 제목 (상단 10% 위치)
        val titleText =
                TextView(this).apply {
                    text = alarmTitle
                    textSize = 28f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    setPadding(dp(20), 0, dp(20), 0)
                }

        val titleParams =
                FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                )
        val screenHeight = resources.displayMetrics.heightPixels
        titleParams.topMargin = (screenHeight * 0.10).toInt()
        titleParams.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
        rootLayout.addView(titleText, titleParams)

        // 버튼 컨테이너 (화면 중앙~하단)
        val buttonContainer =
                LinearLayout(this).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER_HORIZONTAL
                }

        // "다시 울림" 버튼 (AppColors.primary = #FF5A1F 주황)
        val snoozeButton = createStyledButton(
                text = "다시 울림",
                bgColor = "#FF5A1F",
                dp = dp
        ) {
            Log.d("AlarmFullscreen", "🔵 다시 울림 버튼 클릭")
            showSnoozeOptions()
        }
        buttonContainer.addView(snoozeButton)

        // 간격
        val spacer = Space(this)
        spacer.layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(20)
        )
        buttonContainer.addView(spacer)

        // "알람 종료" 버튼 (AppColors.danger = #E53935 빨강)
        val dismissButton = createStyledButton(
                text = "알람 종료",
                bgColor = "#E53935",
                dp = dp
        ) {
            Log.d("AlarmFullscreen", "🔴 알람 종료 버튼 클릭")
            dismissAlarm()
        }
        buttonContainer.addView(dismissButton)

        // 간격
        val spacer2 = Space(this)
        spacer2.layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(24)
        )
        buttonContainer.addView(spacer2)

        // "⚡ 오발동" 버튼 (amber — GPS 오류로 잘못 울린 경우)
        val falseTriggerButton = Button(this).apply {
            text = "⚡ 오발동"
            textSize = 15f
            setTextColor(Color.parseColor("#FFD54F")) // amber.shade300
            isAllCaps = false
            val shape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(24).toFloat()
                setStroke(dp(2), Color.parseColor("#FFB300")) // amber.shade400
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(dp(210), dp(46))
            gravity = Gravity.CENTER
            setOnClickListener {
                Log.d("AlarmFullscreen", "⚡ 오발동 버튼 클릭")
                handleFalseTrigger()
            }
        }
        buttonContainer.addView(falseTriggerButton)

        val buttonParams =
                FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT
                )
        buttonParams.gravity = Gravity.CENTER
        // 다시울림 버튼을 화면 40% 위치에, 알람종료를 25% 위치에 맞추기 위해
        // 버튼 컨테이너를 화면 중앙보다 약간 위로
        buttonParams.topMargin = (screenHeight * 0.30).toInt()
        rootLayout.addView(buttonContainer, buttonParams)

        setContentView(rootLayout)

        Log.d("AlarmFullscreen", "✅ 네이티브 UI 생성 완료 (Flutter 디자인)")
    }

    /// 둥근 모서리 스타일 버튼 생성 (Flutter ElevatedButton과 동일)
    private fun createStyledButton(
            text: String,
            bgColor: String,
            dp: (Int) -> Int,
            onClick: () -> Unit
    ): Button {
        return Button(this).apply {
            this.text = text
            textSize = 20f
            setTextColor(Color.WHITE)
            isAllCaps = false // Flutter처럼 대문자 변환 안 함

            // 둥근 모서리 배경
            val shape = GradientDrawable().apply {
                setColor(Color.parseColor(bgColor))
                cornerRadius = dp(24).toFloat()
            }
            background = shape

            // 크기
            layoutParams = LinearLayout.LayoutParams(dp(250), dp(60))
            gravity = Gravity.CENTER

            setOnClickListener { onClick() }
        }
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

    /// ⚡ 오발동 처리 — 소리만 끄고 알람 enabled=true 유지 (트리거 카운트 -1)
    private fun handleFalseTrigger() {
        Log.d("AlarmFullscreen", "⚡ 오발동 처리 — 소리만 끄고 알람 유지")

        // triggerCount -1 (오발동이므로 카운트 원복)
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        val current = prefs.getInt("trigger_count_$alarmId", 0)
        if (current > 0) {
            prefs.edit().putInt("trigger_count_$alarmId", current - 1).apply()
            Log.d("AlarmFullscreen", "⚡ 트리거 카운트 원복: $current → ${current - 1}")
        }

        // alarm_disabled 플래그 설정 안 함 — 알람 enabled 유지
        // native_alarm_active 플래그만 클리어
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            remove("flutter.native_alarm_active")
            remove("flutter.native_alarm_title")
            remove("flutter.native_alarm_place_id")
            remove("flutter.native_alarm_id")
            apply()
        }

        stopAlarmAndGoHome()
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
        // ✅ 볼륨 에스컬레이션 취소 및 원래 볼륨 복원
        restoreVolume()

        // ✅ 네이티브 알람 활성 플래그 해제
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            remove("flutter.native_alarm_active")
            remove("flutter.native_alarm_title")
            remove("flutter.native_alarm_place_id")
            remove("flutter.native_alarm_id")
            apply()
        }
        Log.d("AlarmFullscreen", "✅ 알람 상태 플래그 클리어 완료")

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
        // ⚠️ startActivity() 호출 시 onUserLeaveHint()가 트리거되므로
        // isAlarmDismissing 플래그로 native_alarm_active 재설정 방지
        isAlarmDismissing = true

        val mainIntent =
                Intent(this, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
        startActivity(mainIntent)

        // Activity 종료
        finish()

        Log.d("AlarmFullscreen", "✅ 앱 메인화면으로 복귀")
    }

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        // ✅ 뒤로가기 완전 차단 — super.onBackPressed() 호출하지 않음!
        // 사용자가 반드시 다시 울림 또는 알람 종료를 선택해야 함
        Log.d("AlarmFullscreen", "🔙 뒤로가기 차단됨 — 선택 필요")
    }

    // ✅ 홈 버튼으로 백그라운드 갔을 때 — SharedPreferences에 활성 상태 기록
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()

        // ⚠️ stopAlarmAndGoHome()에서 startActivity() 호출 시에도 onUserLeaveHint()가 트리거됨
        // 알람 종료 중이면 native_alarm_active를 다시 설정하지 않음
        if (isAlarmDismissing) {
            Log.d("AlarmFullscreen", "🏠 onUserLeaveHint — 알람 종료 중이므로 상태 저장 생략")
            return
        }

        Log.d("AlarmFullscreen", "🏠 홈 버튼 감지 — 알람 활성 상태 유지")
        // Flutter SharedPreferences 플러그인이 자동으로 'flutter.' 접두사를 붙이므로
        // Kotlin에서도 'flutter.' 접두사를 사용해야 Flutter에서 올바르게 읽을 수 있음
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            putBoolean("flutter.native_alarm_active", true)
            putString("flutter.native_alarm_title", alarmTitle)
            putString("flutter.native_alarm_place_id", placeId)
            putString("flutter.native_alarm_id", alarmId.toString())
            apply()
        }
        Log.d("AlarmFullscreen", "✅ 알람 상태 저장 완료: title=$alarmTitle, placeId=$placeId, alarmId=$alarmId")
    }

    // ✅ 멀티태스킹에서 다시 돌아올 때 — 알람 화면 유지
    override fun onRestart() {
        super.onRestart()
        Log.d("AlarmFullscreen", "🔄 알람 화면 복귀 (onRestart)")
        // 벨소리가 꺼져있으면 다시 재생
        if (flutterRingtone?.isPlaying != true) {
            playAlarmRingtone()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        AlarmFullscreenActivity.isActive = false
        Log.d("AlarmFullscreen", "🛑 AlarmFullscreenActivity 종료 — isActive = false")
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // 화면 터치는 허용 (버튼 클릭 가능하도록)
        return super.onTouchEvent(event)
    }
}

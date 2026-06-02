package com.bnt0514.ringinout

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
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
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

        /** 알람 큐 최대 크기 */
        private const val MAX_QUEUE_SIZE = 5
    }

    // ═══════════════════════════════════════════════════════════
    //  알람 큐 시스템 — 동시 다발 알람을 순차 처리
    // ═══════════════════════════════════════════════════════════

    /** 대기 중인 알람 데이터 큐 */
    private data class AlarmData(
        val alarmId: Int,
        val alarmTitle: String,
        val alarmKey: String,
        val placeId: String,
        val ownerUid: String,
        val isRepeat: Boolean,
        val isSnoozeAlarm: Boolean
    )
    private val pendingAlarms = ArrayDeque<AlarmData>()

    private var alarmId: Int = -1
    private var alarmTitle: String = "위치 알람"
    private var triggerCount: Int = 0
    private var alarmKey: String = ""
    private var placeId: String = ""
    private var ownerUid: String = ""
    private var isRepeat: Boolean = false // ✅ 반복 알람 여부
    private var triggerType: String = "entry" // ✅ entry / exit

    // ✅ 알람 종료 중 플래그 — stopAlarmAndGoHome()에서 startActivity() 호출 시
    // onUserLeaveHint()가 트리거되어 native_alarm_active를 다시 true로 설정하는 것을 방지
    private var isAlarmDismissing: Boolean = false

    // ✅ 볼륨 에스컬레이션
    private var originalVolume: Int = -1
    private val volumeHandler = Handler(Looper.getMainLooper())
    private var volumeEscalationRunnable: Runnable? = null

    // ✅ 진동
    private var alarmVibrator: Vibrator? = null
    private var soundEnabled: Boolean = true
    private var vibrationEnabled: Boolean = true

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
        alarmKey = intent.getStringExtra("alarmKey") ?: ""
        placeId = intent.getStringExtra("placeId") ?: ""
        ownerUid = intent.getStringExtra("ownerUid") ?: ""
        isRepeat = intent.getBooleanExtra("isRepeat", false) // ✅ 반복 알람 여부
        triggerType = intent.getStringExtra("trigger") ?: "entry"
        soundEnabled = intent.getBooleanExtra("soundEnabled", true)
        vibrationEnabled = intent.getBooleanExtra("vibrationEnabled", true)
        if (alarmKey.isEmpty()) {
            alarmKey = placeId
        }

        // SharedPreferences에서 triggerCount 가져오기
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        triggerCount = prefs.getInt("trigger_count_$alarmId", 0)

        Log.d("AlarmFullscreen", "📋 알람 정보: ID=$alarmId, 제목=$alarmTitle, 트리거=$triggerCount, 반복=$isRepeat")

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
        if (isSnoozeAlarm && alarmKey.isNotEmpty()) {
            val flutterPrefs =
                    getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                remove("flutter.alarm_snoozed_$alarmKey")
                remove("flutter.alarm_disabled_$alarmKey")
                apply()
            }
            Log.d("AlarmFullscreen", "✅ 스누즈 플래그 + 비활성화 해제: $alarmKey")
        }

        // ✅ 네이티브 UI 생성
        setupNativeUI()

        // ✅ 벨소리 직접 재생 (SnoozeReceiver/일반 알람 모두 여기서 재생)
        playAlarmRingtone()

        // ✅ 볼륨 에스컬레이션 시작
        startVolumeEscalation()
    }

    // ═══════════════════════════════════════════════════════════
    //  ✅ onNewIntent — 이미 알람 화면이 떠 있을 때 새 알람이 도착한 경우
    //  현재 알람을 큐에 저장하고, 새 알람으로 UI 교체
    // ═══════════════════════════════════════════════════════════
    override fun onNewIntent(newAlarmIntent: Intent?) {
        super.onNewIntent(newAlarmIntent)
        if (newAlarmIntent == null) return

        Log.d("AlarmFullscreen", "🔔 onNewIntent — 새 알람 도착 (현재: $alarmTitle)")

        // 현재 알람을 큐에 저장 (최대 MAX_QUEUE_SIZE)
        if (pendingAlarms.size < MAX_QUEUE_SIZE) {
            pendingAlarms.addLast(
                AlarmData(
                    alarmId = this.alarmId,
                    alarmTitle = this.alarmTitle,
                    alarmKey = this.alarmKey,
                    placeId = this.placeId,
                    ownerUid = this.ownerUid,
                    isRepeat = this.isRepeat,
                    isSnoozeAlarm = false
                )
            )
            Log.d("AlarmFullscreen", "📥 현재 알람 큐에 저장: $alarmTitle (큐 크기: ${pendingAlarms.size})")
        } else {
            Log.w("AlarmFullscreen", "⚠️ 알람 큐 가득 참 (${MAX_QUEUE_SIZE}개) — 현재 알람 버림: $alarmTitle")
        }

        // 새 알람 데이터로 교체
        alarmId = newAlarmIntent.getIntExtra("alarmId", -1)
        alarmTitle = newAlarmIntent.getStringExtra("title") ?: "위치 알람"
        alarmKey = newAlarmIntent.getStringExtra("alarmKey") ?: ""
        placeId = newAlarmIntent.getStringExtra("placeId") ?: ""
        ownerUid = newAlarmIntent.getStringExtra("ownerUid") ?: ""
        isRepeat = newAlarmIntent.getBooleanExtra("isRepeat", false)
        triggerType = newAlarmIntent.getStringExtra("trigger") ?: "entry"
        if (alarmKey.isEmpty()) alarmKey = placeId

        // 스누즈 알람이면 플래그 해제
        val isSnoozeAlarm = newAlarmIntent.getBooleanExtra("isSnoozeAlarm", false)
        if (isSnoozeAlarm && alarmKey.isNotEmpty()) {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                remove("flutter.alarm_snoozed_$alarmKey")
                remove("flutter.alarm_disabled_$alarmKey")
                apply()
            }
        }

        // triggerCount 갱신
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        triggerCount = prefs.getInt("trigger_count_$alarmId", 0)

        Log.d("AlarmFullscreen", "📋 새 알람으로 교체: $alarmTitle (ID=$alarmId, 반복=$isRepeat)")

        // UI 교체 (기존 벨소리는 그대로 유지 — 이미 울리고 있으므로)
        setupNativeUI()

        // Intent 업데이트
        intent = newAlarmIntent
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

            // 링거 모드 확인: 무음/진동이면 소리는 안 냄 (USAGE_ALARM은 무음 무시하지만 명시적으로 처리)
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val ringerMode = audioManager.ringerMode
            if (soundEnabled &&
                ringerMode != AudioManager.RINGER_MODE_SILENT &&
                ringerMode != AudioManager.RINGER_MODE_VIBRATE) {
                flutterRingtone?.play()
                Log.d("AlarmFullscreen", "🔔 알람 벨소리 재생 시작 (ringerMode=$ringerMode)")
            } else {
                Log.d("AlarmFullscreen", "🔕 무음/진동 모드 — 벨소리 생략 (ringerMode=$ringerMode)")
            }

            // 진동 시작 (무음·진동 모드 모두에서 항상 울림)
            if (vibrationEnabled) {
                startAlarmVibration()
            }
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 벨소리 재생 실패: ${e.message}")
        }
    }

    /// 알람 진동 시작 — 무음/진동 모드 모두에서 동작
    private fun startAlarmVibration() {
        try {
            stopAlarmVibration() // 중복 방지
            alarmVibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            // 패턴: 대기0ms → 진동500ms → 쉬기500ms → 반복 (-1=한번, 0=처음부터 반복)
            val pattern = longArrayOf(0, 500, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0) // 0=index 0부터 반복
                alarmVibrator?.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                alarmVibrator?.vibrate(pattern, 0)
            }
            Log.d("AlarmFullscreen", "📳 진동 시작")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 진동 시작 실패: ${e.message}")
        }
    }

    /// 알람 진동 정지
    private fun stopAlarmVibration() {
        try {
            alarmVibrator?.cancel()
            alarmVibrator = null
            Log.d("AlarmFullscreen", "📴 진동 정지")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 진동 정지 실패: ${e.message}")
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

        // "⏸ 잠시 멈춤" + "⚡ 오발동" 보조 버튼 행 (weight=1 균등 분할로 잘림 방지)
        val auxRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(32), 0, dp(32), 0) // 화면 가장자리와 여백
        }

        val pauseButton = Button(this).apply {
            text = "⏸ 잠시 멈춤"
            textSize = 14f
            setTextColor(Color.parseColor("#81D4FA"))
            isAllCaps = false
            val shape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(24).toFloat()
                setStroke(dp(2), Color.parseColor("#4FC3F7"))
            }
            background = shape
            val lp = LinearLayout.LayoutParams(0, dp(46), 1f) // weight=1
            lp.marginEnd = dp(8)
            layoutParams = lp
            gravity = Gravity.CENTER
            setOnClickListener {
                Log.d("AlarmFullscreen", "⏸ 잠시 멈춤 버튼 클릭")
                showPauseOptions()
            }
        }
        auxRow.addView(pauseButton)

        val falseTriggerButton2 = Button(this).apply {
            text = "⚡ 오발동"
            textSize = 14f
            setTextColor(Color.parseColor("#FFD54F"))
            isAllCaps = false
            val shape = android.graphics.drawable.GradientDrawable().apply {
                setColor(Color.TRANSPARENT)
                cornerRadius = dp(24).toFloat()
                setStroke(dp(2), Color.parseColor("#FFB300"))
            }
            background = shape
            layoutParams = LinearLayout.LayoutParams(0, dp(46), 1f) // weight=1
            gravity = Gravity.CENTER
            setOnClickListener {
                Log.d("AlarmFullscreen", "⚡ 오발동 버튼 클릭")
                handleFalseTrigger()
            }
        }
        auxRow.addView(falseTriggerButton2)

        buttonContainer.addView(auxRow)

        // 힌트 텍스트
        val hintText = android.widget.TextView(this).apply {
            text = "잠시 멈춤: 일정 시간 동안 안 울림  ·  오발동: GPS 오류"
            textSize = 11f
            setTextColor(Color.argb(153, 255, 255, 255)) // 60% white
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(6), dp(16), 0)
        }
        buttonContainer.addView(hintText)

        val buttonParams =
                FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT, // 전체 너비 → 버튼 잘림 방지
                        FrameLayout.LayoutParams.WRAP_CONTENT
                )
        buttonParams.gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
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
        val options = arrayOf("1분 후", "3분 후", "5분 후", "10분 후", "30분 후", "직접 입력...")
        val minutes = arrayOf(1, 3, 5, 10, 30, -1)

        val builder =
                android.app.AlertDialog.Builder(
                        this,
                        android.R.style.Theme_DeviceDefault_Dialog_Alert
                )
        builder.setTitle("다시 울림 시간 선택")
        builder.setItems(options) { dialog, which ->
            val selectedMinutes = minutes[which]
            if (selectedMinutes == -1) {
                // 직접 입력
                showCustomSnoozeInput()
            } else {
                scheduleSnooze(selectedMinutes)
                // ✅ 큐에 대기 중인 알람이 있으면 다음 알람으로 전환
                if (pendingAlarms.isNotEmpty()) {
                    showNextQueuedAlarm()
                } else {
                    stopAlarmAndGoHome()
                }
            }
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

    private fun showCustomSnoozeInput() {
        val editText = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            hint = "분 입력 (1~720)"
            setPadding(40, 24, 40, 24)
        }
        val dialog = android.app.AlertDialog.Builder(
                this,
                android.R.style.Theme_DeviceDefault_Dialog_Alert
        )
                .setTitle("직접 입력")
                .setView(editText)
                .setPositiveButton("확인") { _, _ ->
                    val v = editText.text.toString().toIntOrNull()
                    if (v != null && v in 1..720) {
                        scheduleSnooze(v)
                        if (pendingAlarms.isNotEmpty()) {
                            showNextQueuedAlarm()
                        } else {
                            stopAlarmAndGoHome()
                        }
                    } else {
                        // 잘못된 값 → 다시 옵션 표시
                        showSnoozeOptions()
                    }
                }
                .setNegativeButton("취소") { _, _ ->
                    // 취소 → 원래 목록으로 복귀
                    showSnoozeOptions()
                }
                .create()
        dialog.show()
        // 키보드 자동 열기
        editText.requestFocus()
        dialog.window?.setSoftInputMode(
                android.view.WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
        )
    }

    private fun scheduleSnooze(minutes: Int) {
        Log.d("AlarmFullscreen", "⏰ 스누즈 설정: ${minutes}분 후 (반복알람: $isRepeat)")

        // ✅ 스누즈 시 플래그 설정
        if (alarmKey.isNotEmpty()) {
            val flutterPrefs =
                    getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            flutterPrefs.edit().apply {
                putBoolean("flutter.alarm_snoozed_$alarmKey", true)
                // ✅ 반복 알람이면 alarm_disabled_ 플래그 설정하지 않음!
                if (!isRepeat) {
                    putBoolean("flutter.alarm_disabled_$alarmKey", true)
                }
                apply()
            }
            if (isRepeat) {
                Log.d("AlarmFullscreen", "🔄 반복 알람 — 스누즈 중 alarm_disabled 스킵 (enabled 유지)")
            } else {
                Log.d("AlarmFullscreen", "🔕 일회성 알람 — 스누즈 플래그 + 비활성화 설정: $alarmKey")
            }
        }

        // ✅ AlarmManager 기반 스누즈 스케줄링 (앱이 죽어도 작동!)
        SnoozeScheduler.scheduleSnooze(
                this,
                alarmId,
                alarmTitle,
                minutes,
                alarmKey,
                placeId,
                ownerUid,
                isRepeat
        )

        Log.d("AlarmFullscreen", "✅ AlarmManager 스누즈 스케줄 완료: ${minutes}분 후")
    }

    /// ⏸️ 잠시 멈춤 — 시간 선택 후 pause_until 저장 + 오발동 후처리
    private fun showPauseOptions() {
        val options = arrayOf("15분", "1시간 (60분)", "4시간 (240분)", "직접 입력...")
        val minutes = arrayOf(15, 60, 240, -1)

        val builder = android.app.AlertDialog.Builder(
            this,
            android.R.style.Theme_DeviceDefault_Dialog_Alert
        )
        builder.setTitle("⏸ 얼마 동안 멈출까요?")
        builder.setItems(options) { _, which ->
            if (minutes[which] == -1) {
                showCustomPauseDialog()
            } else {
                handlePause(minutes[which])
            }
        }
        builder.setNegativeButton("취소") { dialog, _ ->
            Log.d("AlarmFullscreen", "⏸ 잠시 멈춤 취소")
            dialog.dismiss()
            if (flutterRingtone?.isPlaying != true) playAlarmRingtone()
        }
        builder.setCancelable(false)
        builder.show()
    }

    private fun showCustomPauseDialog() {
        val input = android.widget.EditText(this).apply {
            inputType = android.text.InputType.TYPE_CLASS_NUMBER
            hint = "분 단위로 입력 (1~720)"
        }
        val builder = android.app.AlertDialog.Builder(
            this,
            android.R.style.Theme_DeviceDefault_Dialog_Alert
        )
        builder.setTitle("잠시 멈춤 시간")
        builder.setView(input)
        builder.setPositiveButton("확인") { _, _ ->
            val v = input.text.toString().toIntOrNull()
            if (v != null && v in 1..720) {
                handlePause(v)
            } else {
                if (flutterRingtone?.isPlaying != true) playAlarmRingtone()
            }
        }
        builder.setNegativeButton("취소") { dialog, _ ->
            dialog.dismiss()
            if (flutterRingtone?.isPlaying != true) playAlarmRingtone()
        }
        builder.setCancelable(false)
        builder.show()
    }

    private fun handlePause(pauseMinutes: Int) {
        Log.d("AlarmFullscreen", "⏸ 잠시 멈춤 처리: ${pauseMinutes}분, trigger=$triggerType, alarmKey=$alarmKey")

        // 1. pause_until_{trigger}_{alarmKey} → FlutterSharedPreferences에 저장
        //    Flutter SharedPreferences 플러그인은 'flutter.' 접두사를 사용
        val pauseUntilMs = System.currentTimeMillis() + pauseMinutes.toLong() * 60 * 1000
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            if (alarmKey.isNotEmpty()) {
                putLong("flutter.pause_until_${triggerType}_$alarmKey", pauseUntilMs)
                Log.d("AlarmFullscreen", "✅ pause_until_${triggerType}_$alarmKey = $pauseUntilMs (+${pauseMinutes}분)")
            }
            // 2. 오발동과 동일: native_alarm_active 클리어 + 당일 트리거 기록 초기화
            remove("flutter.native_alarm_active")
            remove("flutter.native_alarm_title")
            remove("flutter.native_alarm_place_id")
            remove("flutter.native_alarm_id")
            if (alarmKey.isNotEmpty()) {
                remove("flutter.alarm_triggered_date_$alarmKey")
                remove("flutter.cooldown_until_$alarmKey")
            }
            apply()
        }

        // 3. 트리거 카운트 원복 (오발동과 동일)
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        val current = prefs.getInt("trigger_count_$alarmId", 0)
        if (current > 0) {
            prefs.edit().putInt("trigger_count_$alarmId", current - 1).apply()
            Log.d("AlarmFullscreen", "⏸ 트리거 카운트 원복: $current → ${current - 1}")
        }

        // 4. Toast 피드백
        val triggerLabel = if (triggerType == "exit") "이탈" else "진입"
        val timeLabel = if (pauseMinutes < 60) "${pauseMinutes}분" else "${pauseMinutes / 60}시간"
        android.widget.Toast.makeText(
            this,
            "$triggerLabel 알람을 $timeLabel 동안 멈췄어요",
            android.widget.Toast.LENGTH_SHORT
        ).show()

        // 5. 같은 장소 2회째 잠시 멈춤 → 이슈 안내 다이얼로그 자동 노출
        val placeKey = placeId.ifEmpty { alarmKey }
        val flutterPrefs2 = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val cntKey = "flutter.native_pause_count_$placeKey"
        val pauseCnt = flutterPrefs2.getInt(cntKey, 0) + 1
        flutterPrefs2.edit().putInt(cntKey, pauseCnt).apply()
        val shownKey = "flutter.native_pause_coaching_$placeKey"
        val alreadyShown = flutterPrefs2.getBoolean(shownKey, false)

        if (pauseCnt >= 2 && !alreadyShown) {
            flutterPrefs2.edit().putBoolean(shownKey, true).apply()
            Handler(Looper.getMainLooper()).postDelayed({
                if (!isFinishing) showPauseCoachingDialog()
            }, 400)
        } else {
            if (pendingAlarms.isNotEmpty()) showNextQueuedAlarm() else stopAlarmAndGoHome()
        }
    }

    private fun showPauseCoachingDialog() {
        val builder = android.app.AlertDialog.Builder(
            this, android.R.style.Theme_DeviceDefault_Dialog_Alert
        )
        builder.setTitle("🔧 알람이 자꾸 울리는 이유")
        builder.setMessage(
            "같은 알람이 반복해서 울린다면 아래를 시도해 보세요:\n\n" +
            "• 장소 핀을 자주 머무는 곳에서 조금 더 떨어진 위치로 옮겨 보세요.\n" +
            "• 반경을 더 크게 설정해 보세요 (예: 100m → 200m). 잠깐 들락날락하는 소음이 무시됩니다.\n" +
            "• 트리거 타입을 바꿔 보세요. 떠날 때만 알면 된다면 진입 대신 이탈을 설정하세요.\n" +
            "• GPS와 Wi-Fi가 켜져 있는지 확인하세요."
        )
        builder.setPositiveButton("확인") { _, _ ->
            if (pendingAlarms.isNotEmpty()) showNextQueuedAlarm() else stopAlarmAndGoHome()
        }
        builder.setCancelable(false)
        builder.show()
    }

    /// ⚡ 오발동 처리 — 소리만 끄고 알람 enabled=true 유지 (트리거 카운트 -1)
    private fun handleFalseTrigger() {
        Log.d("AlarmFullscreen", "⚡ 오발동 처리 — 소리만 끄고 알람 유지")
        android.widget.Toast.makeText(
            this, "GPS 오류로 처리했어요. 알람은 유지됩니다.", android.widget.Toast.LENGTH_SHORT
        ).show()

        // triggerCount -1 (오발동이므로 카운트 원복)
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        val current = prefs.getInt("trigger_count_$alarmId", 0)
        if (current > 0) {
            prefs.edit().putInt("trigger_count_$alarmId", current - 1).apply()
            Log.d("AlarmFullscreen", "⚡ 트리거 카운트 원복: $current → ${current - 1}")
        }

        // alarm_disabled 플래그 설정 안 함 — 알람 enabled 유지
        // native_alarm_active 플래그 클리어 + 당일 트리거 기록 초기화
        // ★ cooldown은 Flutter(_onFalseTrigger)에서 30초로 재설정 — 여기서는 건드리지 않음
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            remove("flutter.native_alarm_active")
            remove("flutter.native_alarm_title")
            remove("flutter.native_alarm_place_id")
            remove("flutter.native_alarm_id")
            // 오발동 = 트리거 안 된 것으로 처리 → 당일 트리거 기록만 초기화
            // cooldown은 Flutter에서 30초로 재설정하므로 여기서는 제거하지 않음
            if (alarmKey.isNotEmpty()) {
                remove("flutter.alarm_triggered_date_$alarmKey")
                Log.d("AlarmFullscreen", "⚡ 당일 트리거 기록 초기화 (cooldown은 Flutter에서 30초 유지): $alarmKey")
            }
            apply()
        }

        // ✅ 큐에 대기 중인 알람이 있으면 다음 알람으로 전환
        if (pendingAlarms.isNotEmpty()) {
            showNextQueuedAlarm()
        } else {
            stopAlarmAndGoHome()
        }
    }

    private fun dismissAlarm() {
        Log.d("AlarmFullscreen", "🔴 알람 종료 처리 (반복알람: $isRepeat)")

        // ✅ FlutterSharedPreferences에 기록
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        flutterPrefs.edit().apply {
            if (alarmKey.isNotEmpty()) {
                // ✅ 반복 알람이면 alarm_disabled_ 플래그 설정하지 않음! (enabled 유지)
                if (!isRepeat) {
                    putBoolean("flutter.alarm_disabled_$alarmKey", true)
                    Log.d("AlarmFullscreen", "🔕 일회성 알람 비활성화: $alarmKey")
                } else {
                    Log.d("AlarmFullscreen", "🔄 반복 알람 — alarm_disabled 스킵 (enabled 유지, 내일 다시 울림)")
                }
            }
            apply()
        }

        // ✅ 알람 해제 처리는 Flutter 측 LocationMonitorService에서 관리
        if (alarmKey.isNotEmpty()) {
            Log.d(
                    "AlarmFullscreen",
                    "✅ 알람 해제 완료: alarmKey=$alarmKey, placeId=$placeId, isRepeat=$isRepeat (Flutter 측 관리)"
            )
        }

        // ✅ 스누즈 스케줄도 취소
        SnoozeScheduler.cancelSnooze(this, alarmId)

        // 목표 달성 기록 (Flutter에 전달)
        val intent =
                Intent("com.bnt0514.ringinout.ALARM_DISMISSED").apply {
                    putExtra("alarmId", alarmId)
                    putExtra("achieved", true)
                    putExtra("disabled", !isRepeat) // ✅ 반복알람이면 비활성화 안 됨
                    putExtra("isRepeat", isRepeat)
                }
        sendBroadcast(intent)

        // ✅ 큐에 대기 중인 알람이 있으면 다음 알람으로 전환
        if (pendingAlarms.isNotEmpty()) {
            showNextQueuedAlarm()
        } else {
            stopAlarmAndGoHome()
        }
    }

    // ═══════════════════════════════════════════════════════════
    //  ✅ 큐에서 다음 알람을 꺼내서 UI 교체
    // ═══════════════════════════════════════════════════════════
    private fun showNextQueuedAlarm() {
        val next = pendingAlarms.removeFirst()
        Log.d("AlarmFullscreen", "📤 큐에서 다음 알람 로드: ${next.alarmTitle} (남은 큐: ${pendingAlarms.size})")

        // 현재 알람 데이터를 큐의 다음 알람으로 교체
        alarmId = next.alarmId
        alarmTitle = next.alarmTitle
        alarmKey = next.alarmKey
        placeId = next.placeId
        ownerUid = next.ownerUid
        isRepeat = next.isRepeat

        // triggerCount 갱신
        val prefs = getSharedPreferences("ringinout", Context.MODE_PRIVATE)
        triggerCount = prefs.getInt("trigger_count_$alarmId", 0)

        // UI 갱신
        setupNativeUI()

        // 벨소리가 꺼져있으면 다시 재생
        if (flutterRingtone?.isPlaying != true) {
            playAlarmRingtone()
        }
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

        // 벨소리 + 진동 정지
        try {
            flutterRingtone?.stop()
            flutterRingtone = null
            Log.d("AlarmFullscreen", "🔕 벨소리 정지")
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "❌ 벨소리 정지 실패: ${e.message}")
        }
        stopAlarmVibration()

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

        // ✅ alarm_dismissing 플래그 설정 (AppDeathDetectorService 오작동 방지)
        //   타임스탬프도 함께 저장하여 stale 플래그 감지 가능
        try {
            val watchdogPrefs = getSharedPreferences("ringinout_watchdog", Context.MODE_PRIVATE)
            watchdogPrefs.edit()
                .putBoolean("alarm_dismissing", true)
                .putLong("alarm_dismissing_timestamp", System.currentTimeMillis())
                .apply()
        } catch (e: Exception) {
            Log.e("AlarmFullscreen", "⚠️ alarm_dismissing 플래그 설정 실패: ${e.message}")
        }

        // ✅ 앱 메인화면(MainActivity)으로 복귀
        // ⚠️ startActivity() 호출 시 onUserLeaveHint()가 트리거되므로
        // isAlarmDismissing 플래그로 native_alarm_active 재설정 방지
        isAlarmDismissing = true

        val mainIntent =
                Intent(this, MainActivity::class.java).apply {
                    // ⚠️ FLAG_ACTIVITY_NEW_TASK 필수: AlarmFullscreenActivity는 별도 taskAffinity를 가지므로
                    //    NEW_TASK 없이 startActivity하면 알람 task 안에 새 MainActivity가 생성됨
                    //    NEW_TASK + CLEAR_TOP + SINGLE_TOP = 기존 MainActivity task의 기존 인스턴스로 복귀
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                }
        startActivity(mainIntent)

        // ✅ Activity 종료 — finish()만 사용 (finishAndRemoveTask는 onTaskRemoved 오발동 유발)
        // excludeFromRecents="true" 설정이므로 최근 앱 목록에 남지 않음
        finish()

        Log.d("AlarmFullscreen", "✅ 앱 메인화면으로 복귀 (finish)")
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
            putString("flutter.native_alarm_id", if (alarmKey.isNotEmpty()) alarmKey else alarmId.toString())
            apply()
        }
        Log.d(
                "AlarmFullscreen",
                "✅ 알람 상태 저장 완료: title=$alarmTitle, placeId=$placeId, alarmKey=$alarmKey, alarmId=$alarmId"
        )
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
        stopAlarmVibration()
        AlarmFullscreenActivity.isActive = false
        Log.d("AlarmFullscreen", "🛑 AlarmFullscreenActivity 종료 — isActive = false")
    }

    override fun onTouchEvent(event: MotionEvent?): Boolean {
        // 화면 터치는 허용 (버튼 클릭 가능하도록)
        return super.onTouchEvent(event)
    }
}

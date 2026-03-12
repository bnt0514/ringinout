package com.example.ringinout.location

import android.Manifest
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityTransition
import com.google.android.gms.location.ActivityTransitionRequest
import com.google.android.gms.location.ActivityTransitionResult
import com.google.android.gms.location.DetectedActivity

/**
 * Activity Transition API - 이동 시작/정지 감지
 *
 * 배터리 소모: 거의 0% (하드웨어 가속) 감지 속도: ~15초 이내
 *
 * STILL → WALKING/IN_VEHICLE: 이동 시작 → ARMED 모드로 전환 WALKING/IN_VEHICLE → STILL: 이동 정지 → IDLE 모드로 복귀
 */
class ActivityTransitionManager(private val context: Context) {

    companion object {
        private const val TAG = "ActivityTransition"
        const val ACTION_TRANSITION = "com.example.ringinout.ACTION_ACTIVITY_TRANSITION"
        private const val REQUEST_CODE = 1001
    }

    private var pendingIntent: PendingIntent? = null
    private var onTransitionCallback: ((isMoving: Boolean) -> Unit)? = null

    /** Activity Transition 구독 시작 */
    fun startMonitoring(onTransition: (isMoving: Boolean) -> Unit) {
        onTransitionCallback = onTransition

        if (ActivityCompat.checkSelfPermission(context, Manifest.permission.ACTIVITY_RECOGNITION) !=
                        PackageManager.PERMISSION_GRANTED
        ) {
            Log.e(TAG, "❌ ACTIVITY_RECOGNITION 권한 없음")
            return
        }

        val transitions =
                listOf(
                        // 정지 → 걷기 시작
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.STILL)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_EXIT)
                                .build(),
                        // 걷기 시작
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.WALKING)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                                .build(),
                        // 달리기 시작
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.RUNNING)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                                .build(),
                        // 차량 탑승
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.IN_VEHICLE)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                                .build(),
                        // 자전거 탑승
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.ON_BICYCLE)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                                .build(),
                        // 정지 상태 진입 (이동 종료)
                        ActivityTransition.Builder()
                                .setActivityType(DetectedActivity.STILL)
                                .setActivityTransition(ActivityTransition.ACTIVITY_TRANSITION_ENTER)
                                .build()
                )

        val request = ActivityTransitionRequest(transitions)

        val intent =
                Intent(context, ActivityTransitionReceiver::class.java).apply {
                    action = ACTION_TRANSITION
                }

        pendingIntent =
                PendingIntent.getBroadcast(
                        context,
                        REQUEST_CODE,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )

        ActivityRecognition.getClient(context)
                .requestActivityTransitionUpdates(request, pendingIntent!!)
                .addOnSuccessListener { Log.d(TAG, "✅ Activity Transition 구독 시작") }
                .addOnFailureListener { e ->
                    Log.e(TAG, "❌ Activity Transition 구독 실패: ${e.message}")
                }
    }

    /** Activity Transition 구독 중지 */
    fun stopMonitoring() {
        pendingIntent?.let { pi ->
            ActivityRecognition.getClient(context)
                    .removeActivityTransitionUpdates(pi)
                    .addOnSuccessListener { Log.d(TAG, "🛑 Activity Transition 구독 중지") }
        }
        pendingIntent = null
        onTransitionCallback = null
    }

    /** 콜백 설정 (BroadcastReceiver에서 호출) */
    fun setCallback(callback: (isMoving: Boolean) -> Unit) {
        onTransitionCallback = callback
    }

    fun notifyTransition(isMoving: Boolean) {
        onTransitionCallback?.invoke(isMoving)
    }
}

/** Activity Transition BroadcastReceiver 앱이 죽어도 시스템이 호출 */
class ActivityTransitionReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ActivityTransitionRcv"
        // 콜백을 위한 정적 참조 (SmartLocationManager에서 설정)
        var onTransitionCallback: ((isMoving: Boolean) -> Unit)? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ActivityTransitionManager.ACTION_TRANSITION) return

        if (!ActivityTransitionResult.hasResult(intent)) {
            Log.w(TAG, "⚠️ ActivityTransitionResult 없음")
            return
        }

        val result = ActivityTransitionResult.extractResult(intent) ?: return

        for (event in result.transitionEvents) {
            val activityType =
                    when (event.activityType) {
                        DetectedActivity.STILL -> "STILL"
                        DetectedActivity.WALKING -> "WALKING"
                        DetectedActivity.RUNNING -> "RUNNING"
                        DetectedActivity.IN_VEHICLE -> "IN_VEHICLE"
                        DetectedActivity.ON_BICYCLE -> "ON_BICYCLE"
                        else -> "UNKNOWN(${event.activityType})"
                    }

            val transitionType =
                    when (event.transitionType) {
                        ActivityTransition.ACTIVITY_TRANSITION_ENTER -> "ENTER"
                        ActivityTransition.ACTIVITY_TRANSITION_EXIT -> "EXIT"
                        else -> "UNKNOWN"
                    }

            Log.d(TAG, "🚶 Activity: $activityType, Transition: $transitionType")

            // 이동 시작 감지
            val isMoving =
                    when {
                        event.activityType == DetectedActivity.STILL &&
                                event.transitionType ==
                                        ActivityTransition.ACTIVITY_TRANSITION_EXIT -> true
                        event.activityType in
                                listOf(
                                        DetectedActivity.WALKING,
                                        DetectedActivity.RUNNING,
                                        DetectedActivity.IN_VEHICLE,
                                        DetectedActivity.ON_BICYCLE
                                ) &&
                                event.transitionType ==
                                        ActivityTransition.ACTIVITY_TRANSITION_ENTER -> true
                        event.activityType == DetectedActivity.STILL &&
                                event.transitionType ==
                                        ActivityTransition.ACTIVITY_TRANSITION_ENTER -> false
                        else -> null
                    }

            isMoving?.let { moving ->
                Log.d(TAG, if (moving) "🏃 이동 시작 감지!" else "🛑 정지 감지!")

                // 콜백 호출
                onTransitionCallback?.invoke(moving)

                // 참고: SmartLocationManager에서 ActivityTransition은 더 이상 사용하지 않음
                // 지오펜스 중심 구조로 전환됨
            }
        }
    }
}

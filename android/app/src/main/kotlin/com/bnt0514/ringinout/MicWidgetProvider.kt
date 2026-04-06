package com.bnt0514.ringinout

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews

class MicWidgetProvider : AppWidgetProvider() {

    companion object {
        const val TAG = "MicWidgetProvider"
        const val ACTION_VOICE_ALARM = "com.bnt0514.ringinout.ACTION_VOICE_ALARM"
    }

    override fun onUpdate(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
    ) {
        Log.d(TAG, "🎤 위젯 업데이트 시작")

        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
    ) {
        // RemoteViews 생성
        val views = RemoteViews(context.packageName, R.layout.mic_widget)

        // 마이크 버튼 클릭 시 앱 실행 (음성 알람 모드)
        val intent =
                Intent(context, MainActivity::class.java).apply {
                    action = ACTION_VOICE_ALARM
                    putExtra("start_with_voice", true)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

        val pendingIntent =
                PendingIntent.getActivity(
                        context,
                        0,
                        intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        // 전체 위젯 컨테이너에 클릭 리스너 설정
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)
        views.setOnClickPendingIntent(R.id.mic_button, pendingIntent)

        // 위젯 업데이트
        appWidgetManager.updateAppWidget(appWidgetId, views)
        Log.d(TAG, "✅ 위젯 업데이트 완료 (ID: $appWidgetId)")
    }

    override fun onEnabled(context: Context) {
        Log.d(TAG, "🎤 첫 번째 위젯 활성화")
    }

    override fun onDisabled(context: Context) {
        Log.d(TAG, "🎤 마지막 위젯 비활성화")
    }
}

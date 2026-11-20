package com.stockmanager.stock_manager

import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val listener by lazy { ComponentName(this, KakaoNotificationListener::class.java) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 카톡 배당 알림 시험 (lib/services/kakao_probe.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "stock_manager/kakao_probe")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> {
                        val granted = isGranted()
                        // 권한은 있는데 연결이 끊겨 있으면 다시 붙여 달라고 요청
                        if (granted && KakaoNotificationListener.instance == null && Build.VERSION.SDK_INT >= 24) {
                            NotificationListenerService.requestRebind(listener)
                        }
                        result.success(
                            ProbeStore.stats(this) + mapOf(
                                "granted" to granted,
                                "connected" to (KakaoNotificationListener.instance != null),
                            ),
                        )
                    }
                    "openSettings" -> {
                        openListenerSettings()
                        result.success(null)
                    }
                    "records" -> result.success(ProbeStore.readAll(this))
                    "scan" -> result.success(KakaoNotificationListener.instance?.scanActive() ?: -1)
                    "clear" -> {
                        ProbeStore.clear(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isGranted(): Boolean =
        if (Build.VERSION.SDK_INT >= 27) {
            getSystemService(NotificationManager::class.java).isNotificationListenerAccessGranted(listener)
        } else {
            Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                ?.contains(listener.flattenToString()) == true
        }

    private fun openListenerSettings() {
        // 안드로이드 11+ 는 이 앱의 '알림 읽기' 스위치로 바로, 안 되면 목록 화면으로
        if (Build.VERSION.SDK_INT >= 30) {
            try {
                startActivity(
                    Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS)
                        .putExtra(Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME, listener.flattenToString()),
                )
                return
            } catch (_: ActivityNotFoundException) {
            }
        }
        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
    }
}

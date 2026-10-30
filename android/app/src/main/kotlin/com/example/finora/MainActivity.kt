package com.example.finora

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.finora/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Guarda referência para o serviço usar
        FinoraNotificationService.methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    // Verifica se o serviço tem permissão de acesso a notificações
                    val enabled = android.provider.Settings.Secure.getString(
                        contentResolver,
                        "enabled_notification_listeners"
                    )
                    result.success(enabled?.contains(packageName) == true)
                }
                "requestPermission" -> {
                    // Abre a tela de configurações de acesso a notificações
                    startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

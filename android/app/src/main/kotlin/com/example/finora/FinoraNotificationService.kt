package com.example.finora

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class FinoraNotificationService : NotificationListenerService() {

    companion object {
        const val CHANNEL_ID = "finora_service"
        const val FOREGROUND_ID = 1001
        var methodChannel: MethodChannel? = null
    }

    override fun onCreate() {
        super.onCreate()
        startForeground()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        val titulo = sbn.notification.extras.getString(Notification.EXTRA_TITLE) ?: ""
        val corpo  = sbn.notification.extras.getString(Notification.EXTRA_TEXT)  ?: ""
        val pacote = sbn.packageName ?: ""

        if (titulo.isEmpty() && corpo.isEmpty()) return

        // Envia para o Flutter via MethodChannel
        methodChannel?.invokeMethod("onNotification", mapOf(
            "titulo" to titulo,
            "corpo"  to corpo,
            "pacote" to pacote,
        ))
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // ignorar remoções
    }

    private fun startForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Finora em execução",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Finora monitorando notificações bancárias"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }

        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Finora ativo")
            .setContentText("Monitorando notificações bancárias")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()

        startForeground(FOREGROUND_ID, notification)
    }
}

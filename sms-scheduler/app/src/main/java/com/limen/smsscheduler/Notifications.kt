package com.limen.smsscheduler

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

object Notifications {

    private const val CHANNEL_ID = "sms_scheduler_status"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Scheduled SMS status",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Tells you when a scheduled text was sent or failed" }
            val nm = context.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    fun show(context: Context, id: Long, title: String, text: String) {
        ensureChannel(context)
        // POST_NOTIFICATIONS is only required at runtime on Android 13+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .build()
        NotificationManagerCompat.from(context).notify(id.toInt(), notification)
    }
}

package com.limenArc.terminal.terminal

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.limenArc.terminal.R

class TerminalService : Service() {

    inner class LocalBinder : Binder() {
        fun getService() = this@TerminalService
    }

    private val binder = LocalBinder()

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = getString(R.string.notification_channel_desc) }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.app_name))
            .setContentText("Terminal session running")
            .setSmallIcon(android.R.drawable.ic_menu_myplaces)
            .setOngoing(true)
            .build()

    companion object {
        private const val CHANNEL_ID = "terminal_service"
        private const val NOTIFICATION_ID = 1001
    }
}

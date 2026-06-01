package com.limen.smsscheduler

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Wraps AlarmManager so a message is delivered to [SendSmsReceiver] at its
 * scheduled wall-clock time, even when the device is idle (Doze).
 */
object SmsScheduler {

    const val EXTRA_ID = "message_id"

    private fun alarmManager(context: Context) =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(context: Context, id: Long): PendingIntent {
        val intent = Intent(context, SendSmsReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return PendingIntent.getBroadcast(context, id.toInt(), intent, flags)
    }

    /** Returns true on Android 12+ if exact alarms are allowed for this app. */
    fun canScheduleExact(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager(context).canScheduleExactAlarms()
        } else true
    }

    fun schedule(context: Context, msg: ScheduledMessage) {
        val pi = pendingIntent(context, msg.id)
        val am = alarmManager(context)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, msg.timeMillis, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, msg.timeMillis, pi)
        }
    }

    fun cancel(context: Context, id: Long) {
        alarmManager(context).cancel(pendingIntent(context, id))
    }

    /** Re-arms every still-pending, future-dated message (e.g. after a reboot). */
    fun rescheduleAll(context: Context) {
        val now = System.currentTimeMillis()
        MessageStore.all(context)
            .filter { it.status == ScheduledMessage.Status.SCHEDULED && it.timeMillis > now }
            .forEach { schedule(context, it) }
    }
}

package com.limen.smsscheduler

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsManager

/**
 * Triggered by AlarmManager at the scheduled time. Loads the message from the
 * store and hands it to the system SMS service. Delivery success/failure is
 * reported back asynchronously via [SmsSentReceiver].
 */
class SendSmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getLongExtra(SmsScheduler.EXTRA_ID, -1L)
        if (id < 0) return

        val msg = MessageStore.get(context, id) ?: return
        if (msg.status != ScheduledMessage.Status.SCHEDULED) return

        try {
            val smsManager = smsManager(context)
            val parts = smsManager.divideMessage(msg.body)

            // Result callback so we know whether the radio actually accepted it.
            val sentIntent = Intent(context, SmsSentReceiver::class.java).apply {
                putExtra(SmsScheduler.EXTRA_ID, id)
            }
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val sentPi = PendingIntent.getBroadcast(context, id.toInt(), sentIntent, flags)

            if (parts.size > 1) {
                val sentIntents = ArrayList<PendingIntent>(parts.size).apply {
                    add(sentPi)
                    for (i in 1 until parts.size) add(sentPi)
                }
                smsManager.sendMultipartTextMessage(msg.number, null, parts, sentIntents, null)
            } else {
                smsManager.sendTextMessage(msg.number, null, msg.body, sentPi, null)
            }
            // SmsSentReceiver will flip the status to SENT or FAILED.
        } catch (e: Exception) {
            MessageStore.updateStatus(context, id, ScheduledMessage.Status.FAILED)
            Notifications.show(
                context, id,
                "Couldn't send text",
                "To ${msg.number}: ${e.localizedMessage ?: "permission or SIM error"}"
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun smsManager(context: Context): SmsManager =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            SmsManager.getDefault()
        }
}

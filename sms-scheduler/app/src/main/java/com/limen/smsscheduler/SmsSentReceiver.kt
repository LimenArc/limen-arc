package com.limen.smsscheduler

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Receives the system result of an SMS send attempt and records whether it
 * actually went out, then surfaces a notification to the user.
 */
class SmsSentReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getLongExtra(SmsScheduler.EXTRA_ID, -1L)
        if (id < 0) return
        val msg = MessageStore.get(context, id) ?: return

        if (resultCode == Activity.RESULT_OK) {
            MessageStore.updateStatus(context, id, ScheduledMessage.Status.SENT)
            Notifications.show(
                context, id,
                "Text sent",
                "To ${msg.number}: ${msg.body.take(60)}"
            )
        } else {
            MessageStore.updateStatus(context, id, ScheduledMessage.Status.FAILED)
            Notifications.show(
                context, id,
                "Text failed to send",
                "To ${msg.number}. Check signal, SIM, and SMS permission."
            )
        }
    }
}

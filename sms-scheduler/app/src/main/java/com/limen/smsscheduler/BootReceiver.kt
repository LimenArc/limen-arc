package com.limen.smsscheduler

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Alarms are cleared on reboot, so re-arm every pending message. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            SmsScheduler.rescheduleAll(context)
        }
    }
}

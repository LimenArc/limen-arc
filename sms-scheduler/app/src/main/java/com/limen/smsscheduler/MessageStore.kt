package com.limen.smsscheduler

import android.content.Context
import org.json.JSONArray

/**
 * Tiny persistence layer backed by SharedPreferences + JSON.
 * Keeps things dependency-free (no Room/SQLite) since the data set is small.
 */
object MessageStore {

    private const val PREFS = "sms_scheduler_prefs"
    private const val KEY = "messages"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    @Synchronized
    fun all(context: Context): MutableList<ScheduledMessage> {
        val raw = prefs(context).getString(KEY, "[]") ?: "[]"
        val arr = JSONArray(raw)
        val list = ArrayList<ScheduledMessage>(arr.length())
        for (i in 0 until arr.length()) {
            list.add(ScheduledMessage.fromJson(arr.getJSONObject(i)))
        }
        // newest scheduled time first
        list.sortByDescending { it.timeMillis }
        return list
    }

    @Synchronized
    fun get(context: Context, id: Long): ScheduledMessage? =
        all(context).firstOrNull { it.id == id }

    @Synchronized
    private fun persist(context: Context, list: List<ScheduledMessage>) {
        val arr = JSONArray()
        list.forEach { arr.put(it.toJson()) }
        prefs(context).edit().putString(KEY, arr.toString()).apply()
    }

    @Synchronized
    fun add(context: Context, msg: ScheduledMessage) {
        val list = all(context)
        list.add(msg)
        persist(context, list)
    }

    @Synchronized
    fun update(context: Context, msg: ScheduledMessage) {
        val list = all(context)
        val idx = list.indexOfFirst { it.id == msg.id }
        if (idx >= 0) list[idx] = msg else list.add(msg)
        persist(context, list)
    }

    @Synchronized
    fun updateStatus(context: Context, id: Long, status: ScheduledMessage.Status) {
        val list = all(context)
        list.firstOrNull { it.id == id }?.let { it.status = status }
        persist(context, list)
    }

    @Synchronized
    fun remove(context: Context, id: Long) {
        val list = all(context).filterNot { it.id == id }
        persist(context, list)
    }
}

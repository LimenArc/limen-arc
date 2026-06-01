package com.limen.smsscheduler

import org.json.JSONObject

/**
 * A single scheduled text message.
 *
 * @param id          unique id (also used as the AlarmManager request code)
 * @param number      the recipient phone number the SMS is sent to
 * @param body        the text content of the message
 * @param timeMillis  the wall-clock time (epoch millis) the message should be sent
 * @param status      current lifecycle state of the message
 */
data class ScheduledMessage(
    val id: Long,
    val number: String,
    val body: String,
    val timeMillis: Long,
    var status: Status = Status.SCHEDULED
) {
    enum class Status { SCHEDULED, SENT, FAILED, CANCELLED }

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("number", number)
        put("body", body)
        put("timeMillis", timeMillis)
        put("status", status.name)
    }

    companion object {
        fun fromJson(o: JSONObject): ScheduledMessage = ScheduledMessage(
            id = o.getLong("id"),
            number = o.getString("number"),
            body = o.getString("body"),
            timeMillis = o.getLong("timeMillis"),
            status = runCatching { Status.valueOf(o.getString("status")) }
                .getOrDefault(Status.SCHEDULED)
        )
    }
}

package com.limen.smsscheduler

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.RecyclerView
import com.limen.smsscheduler.databinding.ItemMessageBinding
import java.text.DateFormat
import java.util.Date

class MessageAdapter(
    private val onCancel: (ScheduledMessage) -> Unit,
    private val onDelete: (ScheduledMessage) -> Unit
) : RecyclerView.Adapter<MessageAdapter.VH>() {

    private val items = mutableListOf<ScheduledMessage>()

    fun submit(list: List<ScheduledMessage>) {
        items.clear()
        items.addAll(list)
        notifyDataSetChanged()
    }

    inner class VH(val binding: ItemMessageBinding) : RecyclerView.ViewHolder(binding.root)

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): VH {
        val binding = ItemMessageBinding.inflate(
            LayoutInflater.from(parent.context), parent, false
        )
        return VH(binding)
    }

    override fun getItemCount() = items.size

    override fun onBindViewHolder(holder: VH, position: Int) {
        val msg = items[position]
        val b = holder.binding

        b.toNumber.text = msg.number
        b.body.text = msg.body
        b.whenLabel.text = DateFormat.getDateTimeInstance(
            DateFormat.MEDIUM, DateFormat.SHORT
        ).format(Date(msg.timeMillis))

        val (statusText, statusColor) = when (msg.status) {
            ScheduledMessage.Status.SCHEDULED -> "Scheduled" to 0xFF1565C0.toInt()
            ScheduledMessage.Status.SENT -> "Sent" to 0xFF2E7D32.toInt()
            ScheduledMessage.Status.FAILED -> "Failed" to 0xFFC62828.toInt()
            ScheduledMessage.Status.CANCELLED -> "Cancelled" to 0xFF757575.toInt()
        }
        b.status.text = statusText
        b.status.setTextColor(statusColor)

        // Only a still-pending message can be cancelled.
        b.cancelButton.visibility =
            if (msg.status == ScheduledMessage.Status.SCHEDULED)
                android.view.View.VISIBLE else android.view.View.GONE

        b.cancelButton.setOnClickListener { onCancel(msg) }
        b.deleteButton.setOnClickListener { onDelete(msg) }
    }
}

package com.limen.smsscheduler

import android.Manifest
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import com.limen.smsscheduler.databinding.ActivityMainBinding
import java.text.DateFormat
import java.util.Calendar
import java.util.Date

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var adapter: MessageAdapter

    // Holds the date + time the user has chosen for the next message.
    private val chosen: Calendar = Calendar.getInstance().apply {
        add(Calendar.HOUR_OF_DAY, 1)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    private val requestPermissions = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* result handled lazily when the user tries to schedule */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        Notifications.ensureChannel(this)
        askForPermissions()

        adapter = MessageAdapter(
            onCancel = { msg -> cancelMessage(msg) },
            onDelete = { msg -> deleteMessage(msg) }
        )
        binding.recycler.layoutManager = LinearLayoutManager(this)
        binding.recycler.adapter = adapter

        binding.pickDateButton.setOnClickListener { showDatePicker() }
        binding.pickTimeButton.setOnClickListener { showTimePicker() }
        binding.scheduleButton.setOnClickListener { onSchedule() }

        updateDateTimeLabels()
        refreshList()
    }

    override fun onResume() {
        super.onResume()
        refreshList()
    }

    // ── Permissions ────────────────────────────────────────────────────────────

    private fun askForPermissions() {
        val needed = mutableListOf(Manifest.permission.SEND_SMS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            needed.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = needed.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) requestPermissions.launch(missing.toTypedArray())
    }

    private fun hasSmsPermission() =
        ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS) ==
            PackageManager.PERMISSION_GRANTED

    // ── Date / time pickers ──────────────────────────────────────────────────

    private fun showDatePicker() {
        DatePickerDialog(
            this,
            { _, year, month, day ->
                chosen.set(Calendar.YEAR, year)
                chosen.set(Calendar.MONTH, month)
                chosen.set(Calendar.DAY_OF_MONTH, day)
                updateDateTimeLabels()
            },
            chosen.get(Calendar.YEAR),
            chosen.get(Calendar.MONTH),
            chosen.get(Calendar.DAY_OF_MONTH)
        ).apply {
            datePicker.minDate = System.currentTimeMillis() - 1000
        }.show()
    }

    private fun showTimePicker() {
        TimePickerDialog(
            this,
            { _, hour, minute ->
                chosen.set(Calendar.HOUR_OF_DAY, hour)
                chosen.set(Calendar.MINUTE, minute)
                chosen.set(Calendar.SECOND, 0)
                chosen.set(Calendar.MILLISECOND, 0)
                updateDateTimeLabels()
            },
            chosen.get(Calendar.HOUR_OF_DAY),
            chosen.get(Calendar.MINUTE),
            android.text.format.DateFormat.is24HourFormat(this)
        ).show()
    }

    private fun updateDateTimeLabels() {
        val df = DateFormat.getDateInstance(DateFormat.FULL)
        val tf = DateFormat.getTimeInstance(DateFormat.SHORT)
        binding.pickDateButton.text = df.format(chosen.time)
        binding.pickTimeButton.text = tf.format(chosen.time)
    }

    // ── Scheduling ───────────────────────────────────────────────────────────

    private fun onSchedule() {
        val number = binding.numberInput.text?.toString()?.trim().orEmpty()
        val body = binding.messageInput.text?.toString().orEmpty()

        if (number.isEmpty()) {
            binding.numberLayout.error = "Enter a phone number"
            return
        }
        binding.numberLayout.error = null
        if (body.isEmpty()) {
            binding.messageLayout.error = "Enter a message"
            return
        }
        binding.messageLayout.error = null

        if (chosen.timeInMillis <= System.currentTimeMillis()) {
            toast("Pick a time in the future")
            return
        }
        if (!hasSmsPermission()) {
            toast("SMS permission is required")
            askForPermissions()
            return
        }
        if (!SmsScheduler.canScheduleExact(this)) {
            promptForExactAlarmPermission()
            return
        }

        val msg = ScheduledMessage(
            id = System.currentTimeMillis(),
            number = number,
            body = body,
            timeMillis = chosen.timeInMillis
        )
        MessageStore.add(this, msg)
        SmsScheduler.schedule(this, msg)

        toast("Scheduled for ${DateFormat.getDateTimeInstance().format(Date(msg.timeMillis))}")
        binding.messageInput.text?.clear()
        refreshList()
    }

    private fun promptForExactAlarmPermission() {
        AlertDialog.Builder(this)
            .setTitle("Allow exact alarms")
            .setMessage(
                "To send your text at the precise time you chose, this app needs " +
                    "permission to schedule exact alarms. Tap Open Settings and enable it."
            )
            .setPositiveButton("Open Settings") { _, _ ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    startActivity(
                        Intent(
                            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                            Uri.parse("package:$packageName")
                        )
                    )
                }
            }
            .setNegativeButton("Cancel", null)
            .show()
    }

    private fun cancelMessage(msg: ScheduledMessage) {
        SmsScheduler.cancel(this, msg.id)
        MessageStore.updateStatus(this, msg.id, ScheduledMessage.Status.CANCELLED)
        refreshList()
    }

    private fun deleteMessage(msg: ScheduledMessage) {
        SmsScheduler.cancel(this, msg.id)
        MessageStore.remove(this, msg.id)
        refreshList()
    }

    private fun refreshList() {
        val list = MessageStore.all(this)
        adapter.submit(list)
        binding.emptyLabel.visibility =
            if (list.isEmpty()) android.view.View.VISIBLE else android.view.View.GONE
    }

    private fun toast(text: String) = Toast.makeText(this, text, Toast.LENGTH_SHORT).show()
}

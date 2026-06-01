# SMS Scheduler

A small native Android app that sends a text message to **any phone number you
enter**, at a **date and time you choose**, with the **content you write**.
Put in your own number to text yourself.

<p align="center">
  <em>Compose → pick a number → pick a date & time → write the message → Schedule.</em>
</p>

---

## What it does

- Enter any recipient phone number (e.g. your own number to text yourself).
- Pick the **day** with a calendar picker and the **time** with a clock picker.
- Write the **message content**.
- Tap **Schedule text** — the message is queued and sent automatically at that
  exact moment, even if the app is closed or the phone has been rebooting.
- See a list of all your scheduled / sent / failed messages, and cancel or
  delete any of them.
- You get a notification when each message is actually sent (or if it fails).

## How it works (technical)

| Piece | Android API |
|-------|-------------|
| Sending the SMS | `SmsManager.sendTextMessage` / `sendMultipartTextMessage` |
| Firing at the chosen time | `AlarmManager.setExactAndAllowWhileIdle` (survives Doze) |
| Surviving reboot | `BootReceiver` re-arms pending alarms on `BOOT_COMPLETED` |
| Storage | JSON in `SharedPreferences` (no database dependency) |
| UI | Single Material 3 activity + RecyclerView list |

Permissions requested: `SEND_SMS`, `POST_NOTIFICATIONS` (Android 13+),
`SCHEDULE_EXACT_ALARM` (Android 12+), `RECEIVE_BOOT_COMPLETED`.

## ⚠️ Important: about the sender number

The text is always sent **from the phone's own SIM / phone number** — that is
the only thing Android allows an app to do. **You cannot make the message appear
to come from an arbitrary "from" number.** Spoofing the sender ID is blocked by
the OS and the carrier; the only legitimate way to set a custom sender is to go
through a paid SMS gateway service (e.g. Twilio), which is out of scope for an
on-device app and is itself heavily restricted to prevent fraud.

So in this app, the number you type is the **recipient** the message is sent to.

## Requirements to actually send

- A device (not most emulators) with an **active SIM** and SMS capability.
- Standard carrier SMS rates apply to each message sent.

---

## Getting the APK

Every push to this folder triggers the **Build SMS Scheduler APK** GitHub
Action, which publishes a ready-to-install `sms-scheduler-debug.apk` to the
`sms-apk-latest` GitHub Release. See [BUILD.md](BUILD.md) to build it yourself.

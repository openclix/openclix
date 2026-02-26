package ai.openclix.notification

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import ai.openclix.engine.parseIso8601
import ai.openclix.models.ClixLocalMessageScheduler
import ai.openclix.models.QueuedMessage
import ai.openclix.models.QueuedMessageStatus
import org.json.JSONArray
import java.io.File

private const val CHANNEL_ID = "openclix_notifications"
private const val CHANNEL_NAME = "OpenClix Notifications"
private const val CHANNEL_DESCRIPTION = "Notifications from OpenClix campaigns"

private const val EXTRA_ID = "openclix_id"
private const val EXTRA_CAMPAIGN_ID = "openclix_campaignId"
private const val EXTRA_EXECUTE_AT = "openclix_executeAt"
private const val EXTRA_CREATED_AT = "openclix_createdAt"
private const val EXTRA_CONTENT_TITLE = "openclix_contentTitle"
private const val EXTRA_CONTENT_BODY = "openclix_contentBody"

private const val PENDING_RECORDS_FILENAME = "openclix_pending_notifications.json"

class OpenClixAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(EXTRA_CONTENT_TITLE) ?: return
        val body = intent.getStringExtra(EXTRA_CONTENT_BODY) ?: return
        val id = intent.getStringExtra(EXTRA_ID) ?: return

        createNotificationChannel(context)

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_CAMPAIGN_ID, intent.getStringExtra(EXTRA_CAMPAIGN_ID))
        }

        val contentIntent = if (launchIntent != null) {
            PendingIntent.getActivity(
                context,
                id.hashCode(),
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            null
        }

        val notificationBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            Notification.Builder(context)
        }

        @Suppress("DEPRECATION")
        notificationBuilder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_DEFAULT)
        contentIntent?.let { notificationBuilder.setContentIntent(it) }
        val notification = notificationBuilder.build()

        notificationManager.notify(id.hashCode(), notification)

        removePendingRecord(context, id)
    }
}

private fun createNotificationChannel(context: Context) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = CHANNEL_DESCRIPTION
        }
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.createNotificationChannel(channel)
    }
}

private fun getPendingRecordsFile(context: Context): File {
    val openclixDir = File(context.filesDir, "openclix")
    if (!openclixDir.exists()) openclixDir.mkdirs()
    return File(openclixDir, PENDING_RECORDS_FILENAME)
}

private fun loadPendingRecords(context: Context): MutableList<QueuedMessage> {
    val file = getPendingRecordsFile(context)
    if (!file.exists()) return mutableListOf()

    return try {
        val content = file.readText(Charsets.UTF_8)
        val jsonArray = JSONArray(content)
        val records = mutableListOf<QueuedMessage>()
        for (i in 0 until jsonArray.length()) {
            records.add(QueuedMessage.fromJson(jsonArray.getJSONObject(i)))
        }
        records
    } catch (_: Exception) {
        mutableListOf()
    }
}

private fun savePendingRecords(context: Context, records: List<QueuedMessage>) {
    val file = getPendingRecordsFile(context)
    val jsonArray = JSONArray()
    for (record in records) {
        jsonArray.put(record.toJson())
    }
    val tempFile = File(file.parentFile, "${file.name}.tmp")
    tempFile.writeText(jsonArray.toString(), Charsets.UTF_8)
    tempFile.renameTo(file)
}

private fun removePendingRecord(context: Context, id: String) {
    val records = loadPendingRecords(context)
    val updated = records.filter { it.id != id }
    savePendingRecords(context, updated)
}

class LocalNotificationScheduler(
    private val context: Context
) : ClixLocalMessageScheduler {

    init {
        createNotificationChannel(context)
    }

    override suspend fun schedule(record: QueuedMessage) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, OpenClixAlarmReceiver::class.java).apply {
            action = "ai.openclix.ALARM_${record.id}"
            putExtra(EXTRA_ID, record.id)
            putExtra(EXTRA_CAMPAIGN_ID, record.campaign_id)
            putExtra(EXTRA_EXECUTE_AT, record.execute_at)
            putExtra(EXTRA_CREATED_AT, record.created_at)
            putExtra(EXTRA_CONTENT_TITLE, record.content.title)
            putExtra(EXTRA_CONTENT_BODY, record.content.body)
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            record.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val triggerTimeMs = parseIso8601(record.execute_at)
        val effectiveTriggerTime = maxOf(triggerTimeMs, System.currentTimeMillis() + 1000)

        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            effectiveTriggerTime,
            pendingIntent
        )

        synchronized(this) {
            val records = loadPendingRecords(context)
            val updated = records.filter { it.id != record.id }.toMutableList()
            updated.add(record)
            savePendingRecords(context, updated)
        }
    }

    override suspend fun cancel(id: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, OpenClixAlarmReceiver::class.java).apply {
            action = "ai.openclix.ALARM_$id"
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()

        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id.hashCode())

        synchronized(this) {
            removePendingRecord(context, id)
        }
    }

    override suspend fun listPending(): List<QueuedMessage> {
        synchronized(this) {
            val records = loadPendingRecords(context)
            return records.filter { record ->
                record.status == QueuedMessageStatus.SCHEDULED
            }
        }
    }
}

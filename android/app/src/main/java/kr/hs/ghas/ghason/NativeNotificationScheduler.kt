package kr.hs.ghas.ghason

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

object NativeNotificationScheduler {
    const val PREFS_NAME = "ghas_lunch_preferences"
    const val KEY_NOTIFICATIONS_ENABLED = "native_notifications_enabled"
    const val KEY_MEAL_NOTIFICATIONS = "native_notifications_meal"
    const val KEY_TIMETABLE_NOTIFICATIONS = "native_notifications_timetable"
    const val KEY_NOTICE_NOTIFICATIONS = "native_notifications_notice"
    const val KEY_MEAL_HOUR = "native_notifications_meal_hour"
    const val KEY_MEAL_MINUTE = "native_notifications_meal_minute"
    const val KEY_TIMETABLE_HOUR = "native_notifications_timetable_hour"
    const val KEY_TIMETABLE_MINUTE = "native_notifications_timetable_minute"
    const val KEY_NOTICE_HOUR = "native_notifications_notice_hour"
    const val KEY_NOTICE_MINUTE = "native_notifications_notice_minute"

    private const val EXTRA_CATEGORY = "local_notification_category"
    private const val CATEGORY_MEAL = "meal"
    private const val CATEGORY_TIMETABLE = "timetable"
    private const val CATEGORY_SCHOOL_NOTICE = "school_notice"
    private const val KEY_CACHE_PREFIX = "native_notification_cached_"

    private val categories = listOf(
        NotificationCategory(
            key = CATEGORY_MEAL,
            enabledKey = KEY_MEAL_NOTIFICATIONS,
            hourKey = KEY_MEAL_HOUR,
            minuteKey = KEY_MEAL_MINUTE,
            defaultHour = 11,
            defaultMinute = 0,
            requestCode = 1100,
            notificationId = 1100,
            channelId = "meal_notifications",
            channelNameResId = R.string.meal_notification_channel_name,
            channelDescriptionResId = R.string.meal_notification_channel_description,
            titleResId = R.string.meal_notification_title,
            bodyResId = R.string.meal_notification_body,
            supportsCachedContent = true
        ),
        NotificationCategory(
            key = CATEGORY_TIMETABLE,
            enabledKey = KEY_TIMETABLE_NOTIFICATIONS,
            hourKey = KEY_TIMETABLE_HOUR,
            minuteKey = KEY_TIMETABLE_MINUTE,
            defaultHour = 7,
            defaultMinute = 30,
            requestCode = 730,
            notificationId = 730,
            channelId = "timetable_notifications",
            channelNameResId = R.string.timetable_notification_channel_name,
            channelDescriptionResId = R.string.timetable_notification_channel_description,
            titleResId = R.string.timetable_notification_title,
            bodyResId = R.string.timetable_notification_body,
            supportsCachedContent = true
        ),
        NotificationCategory(
            key = CATEGORY_SCHOOL_NOTICE,
            enabledKey = KEY_NOTICE_NOTIFICATIONS,
            hourKey = KEY_NOTICE_HOUR,
            minuteKey = KEY_NOTICE_MINUTE,
            defaultHour = 18,
            defaultMinute = 0,
            requestCode = 1800,
            notificationId = 1800,
            channelId = "school_notice_notifications",
            channelNameResId = R.string.notice_notification_channel_name,
            channelDescriptionResId = R.string.notice_notification_channel_description,
            titleResId = R.string.notice_notification_title,
            bodyResId = R.string.notice_notification_body,
            supportsCachedContent = false
        )
    )

    fun cacheContent(context: Context, categoryKey: String?, date: String?, body: String?) {
        val category = categories.firstOrNull { it.key == categoryKey && it.supportsCachedContent }
            ?: return
        val safeDate = date?.takeIf { it.matches(Regex("\\d{8}")) } ?: return
        val safeBody = body?.trim()?.takeIf { it.isNotEmpty() }?.take(240) ?: return
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(cacheDateKey(category), safeDate)
            .putString(cacheBodyKey(category), safeBody)
            .apply()
    }

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        categories.forEach { category ->
            manager.createNotificationChannel(
                NotificationChannel(
                    category.channelId,
                    context.getString(category.channelNameResId),
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = context.getString(category.channelDescriptionResId)
                }
            )
        }
    }

    fun applySavedSettings(context: Context) {
        createChannels(context)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_NOTIFICATIONS_ENABLED, false)) {
            cancelAll(context)
            return
        }

        categories.forEach { category ->
            if (prefs.getBoolean(category.enabledKey, false)) {
                schedule(context, category)
            } else {
                cancelCategory(context, category)
            }
        }
    }

    fun cancelAll(context: Context) {
        categories.forEach { cancelCategory(context, it) }
    }

    fun receiveAlarm(context: Context, categoryKey: String?) {
        val category = categories.firstOrNull { it.key == categoryKey } ?: return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (
            !prefs.getBoolean(KEY_NOTIFICATIONS_ENABLED, false) ||
            !prefs.getBoolean(category.enabledKey, false)
        ) {
            cancelCategory(context, category)
            return
        }

        showNotification(context, category)
        schedule(context, category)
    }

    private fun schedule(context: Context, category: NotificationCategory) {
        cancelAlarmOnly(context, category)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val hour = prefs.getInt(category.hourKey, category.defaultHour)
        val minute = prefs.getInt(category.minuteKey, category.defaultMinute)
        val triggerAt = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }.timeInMillis
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val alarm = alarmPendingIntent(context, category)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, alarm)
        } else {
            manager.set(AlarmManager.RTC_WAKEUP, triggerAt, alarm)
        }
    }

    private fun cancelAlarmOnly(context: Context, category: NotificationCategory) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(alarmPendingIntent(context, category))
    }

    private fun cancelPostedNotification(context: Context, category: NotificationCategory) {
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancel(category.notificationId)
    }

    private fun cancelCategory(context: Context, category: NotificationCategory) {
        cancelAlarmOnly(context, category)
        cancelPostedNotification(context, category)
    }

    private fun alarmPendingIntent(context: Context, category: NotificationCategory): PendingIntent {
        return PendingIntent.getBroadcast(
            context,
            category.requestCode,
            Intent(context, LocalNotificationReceiver::class.java).apply {
                action = "kr.hs.ghas.ghason.LOCAL_NOTIFICATION.${category.key}"
                putExtra(EXTRA_CATEGORY, category.key)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun showNotification(context: Context, category: NotificationCategory) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            category.requestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, category.channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val body = notificationBody(context, category)
        builder
            .setSmallIcon(R.drawable.ic_stat_lunch)
            .setContentTitle(context.getString(category.titleResId))
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_DEFAULT)
        }
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .notify(category.notificationId, builder.build())
    }

    private fun notificationBody(context: Context, category: NotificationCategory): String {
        if (category.supportsCachedContent) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val today = SimpleDateFormat("yyyyMMdd", Locale.KOREA).format(Calendar.getInstance().time)
            if (prefs.getString(cacheDateKey(category), null) == today) {
                prefs.getString(cacheBodyKey(category), null)?.takeIf { it.isNotBlank() }?.let {
                    return it
                }
            }
        }

        // TODO(FCM/Functions): send authoritative same-day meal, timetable and
        // school-notice content from scheduled server push when that backend exists.
        return context.getString(category.bodyResId)
    }

    private fun cacheDateKey(category: NotificationCategory): String =
        "$KEY_CACHE_PREFIX${category.key}_date"

    private fun cacheBodyKey(category: NotificationCategory): String =
        "$KEY_CACHE_PREFIX${category.key}_body"

    private data class NotificationCategory(
        val key: String,
        val enabledKey: String,
        val hourKey: String,
        val minuteKey: String,
        val defaultHour: Int,
        val defaultMinute: Int,
        val requestCode: Int,
        val notificationId: Int,
        val channelId: String,
        val channelNameResId: Int,
        val channelDescriptionResId: Int,
        val titleResId: Int,
        val bodyResId: Int,
        val supportsCachedContent: Boolean
    )

    fun categoryFromIntent(intent: Intent): String? = intent.getStringExtra(EXTRA_CATEGORY)
}

class LocalNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        NativeNotificationScheduler.receiveAlarm(
            context,
            NativeNotificationScheduler.categoryFromIntent(intent)
        )
    }
}

class NotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            NativeNotificationScheduler.applySavedSettings(context)
        }
    }
}

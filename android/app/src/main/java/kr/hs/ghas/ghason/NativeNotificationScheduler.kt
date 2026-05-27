package kr.hs.ghas.ghason

import android.Manifest
import android.annotation.SuppressLint
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
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

internal enum class NativeNotificationCategory(
    val key: String,
    val channelId: String,
    val alarmRequestCode: Int,
    val contentRequestCode: Int,
    val notificationId: Int,
    val defaultTime: String,
    val titleResId: Int,
    val fallbackBodyResId: Int,
    val channelNameResId: Int,
    val channelDescriptionResId: Int
) {
    MEAL(
        key = "meal",
        channelId = "meal_notifications",
        alarmRequestCode = 1001,
        contentRequestCode = 3001,
        notificationId = 2001,
        defaultTime = "11:00",
        titleResId = R.string.meal_notification_title,
        fallbackBodyResId = R.string.meal_notification_body_fallback,
        channelNameResId = R.string.meal_notification_channel_name,
        channelDescriptionResId = R.string.meal_notification_channel_description
    ),
    TIMETABLE(
        key = "timetable",
        channelId = "timetable_notifications",
        alarmRequestCode = 1002,
        contentRequestCode = 3002,
        notificationId = 2002,
        defaultTime = "07:30",
        titleResId = R.string.timetable_notification_title,
        fallbackBodyResId = R.string.timetable_notification_body_fallback,
        channelNameResId = R.string.timetable_notification_channel_name,
        channelDescriptionResId = R.string.timetable_notification_channel_description
    ),
    SCHOOL_NOTICE(
        key = "school_notice",
        channelId = "school_notice_notifications",
        alarmRequestCode = 1003,
        contentRequestCode = 3003,
        notificationId = 2003,
        defaultTime = "18:00",
        titleResId = R.string.school_notice_notification_title,
        fallbackBodyResId = R.string.school_notice_notification_body_fallback,
        channelNameResId = R.string.school_notice_notification_channel_name,
        channelDescriptionResId = R.string.school_notice_notification_channel_description
    );

    companion object {
        fun fromKey(key: String?): NativeNotificationCategory? =
            entries.firstOrNull { it.key == key }
    }
}

internal data class NativeNotificationSettings(
    val enabled: Boolean,
    val mealEnabled: Boolean,
    val timetableEnabled: Boolean,
    val schoolNoticeEnabled: Boolean,
    val mealTime: String,
    val timetableTime: String,
    val schoolNoticeTime: String
) {
    fun isEnabled(category: NativeNotificationCategory): Boolean = when (category) {
        NativeNotificationCategory.MEAL -> mealEnabled
        NativeNotificationCategory.TIMETABLE -> timetableEnabled
        NativeNotificationCategory.SCHOOL_NOTICE -> schoolNoticeEnabled
    }

    fun timeFor(category: NativeNotificationCategory): String = when (category) {
        NativeNotificationCategory.MEAL -> mealTime
        NativeNotificationCategory.TIMETABLE -> timetableTime
        NativeNotificationCategory.SCHOOL_NOTICE -> schoolNoticeTime
    }
}

internal class NativeNotificationScheduler(private val context: Context) {
    private val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    fun settings(): NativeNotificationSettings = NativeNotificationSettings(
        enabled = preferences.getBoolean(KEY_MASTER_ENABLED, false),
        mealEnabled = preferences.getBoolean(KEY_MEAL_ENABLED, true),
        timetableEnabled = preferences.getBoolean(KEY_TIMETABLE_ENABLED, true),
        schoolNoticeEnabled = preferences.getBoolean(KEY_SCHOOL_NOTICE_ENABLED, true),
        mealTime = savedTime(KEY_MEAL_TIME, NativeNotificationCategory.MEAL.defaultTime),
        timetableTime = savedTime(KEY_TIMETABLE_TIME, NativeNotificationCategory.TIMETABLE.defaultTime),
        schoolNoticeTime = savedTime(
            KEY_SCHOOL_NOTICE_TIME,
            NativeNotificationCategory.SCHOOL_NOTICE.defaultTime
        )
    )

    fun updateSettings(
        enabled: Boolean,
        mealEnabled: Boolean,
        timetableEnabled: Boolean,
        schoolNoticeEnabled: Boolean,
        mealTime: String?,
        timetableTime: String?,
        schoolNoticeTime: String?
    ): NativeNotificationSettings {
        val updated = NativeNotificationSettings(
            enabled = enabled,
            mealEnabled = mealEnabled,
            timetableEnabled = timetableEnabled,
            schoolNoticeEnabled = schoolNoticeEnabled,
            mealTime = normalizeTime(mealTime, NativeNotificationCategory.MEAL.defaultTime),
            timetableTime = normalizeTime(
                timetableTime,
                NativeNotificationCategory.TIMETABLE.defaultTime
            ),
            schoolNoticeTime = normalizeTime(
                schoolNoticeTime,
                NativeNotificationCategory.SCHOOL_NOTICE.defaultTime
            )
        )
        persistSettings(updated)
        return updated
    }

    fun setMasterEnabled(enabled: Boolean): NativeNotificationSettings {
        val updated = settings().copy(enabled = enabled)
        persistSettings(updated)
        return updated
    }

    fun setCategoryEnabled(
        category: NativeNotificationCategory,
        enabled: Boolean
    ): NativeNotificationSettings {
        val current = settings()
        val updated = when (category) {
            NativeNotificationCategory.MEAL -> current.copy(mealEnabled = enabled)
            NativeNotificationCategory.TIMETABLE -> current.copy(timetableEnabled = enabled)
            NativeNotificationCategory.SCHOOL_NOTICE -> current.copy(schoolNoticeEnabled = enabled)
        }
        persistSettings(updated)
        return updated
    }

    fun setCategoryTime(category: NativeNotificationCategory, time: String?): Boolean {
        val normalized = time?.trim()?.takeIf { TIME_PATTERN.matches(it) } ?: return false
        val current = settings()
        val updated = when (category) {
            NativeNotificationCategory.MEAL -> current.copy(mealTime = normalized)
            NativeNotificationCategory.TIMETABLE -> current.copy(timetableTime = normalized)
            NativeNotificationCategory.SCHOOL_NOTICE -> current.copy(schoolNoticeTime = normalized)
        }
        persistSettings(updated)
        return true
    }

    fun settingsJson(): String {
        val current = settings()
        return JSONObject()
            .put("enabled", current.enabled)
            .put("mealEnabled", current.mealEnabled)
            .put("timetableEnabled", current.timetableEnabled)
            .put("schoolNoticeEnabled", current.schoolNoticeEnabled)
            .put("mealTime", current.mealTime)
            .put("timetableTime", current.timetableTime)
            .put("schoolNoticeTime", current.schoolNoticeTime)
            .toString()
    }

    fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        NativeNotificationCategory.entries.forEach { category ->
            val channel = NotificationChannel(
                category.channelId,
                context.getString(category.channelNameResId),
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = context.getString(category.channelDescriptionResId)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun canPostNotifications(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    fun scheduleSelectedNotifications() {
        val current = settings()
        if (!current.enabled) {
            cancelAllLocalNotifications()
            return
        }
        if (!canPostNotifications()) {
            cancelAllScheduledAlarms()
            return
        }

        createNotificationChannels()
        NativeNotificationCategory.entries.forEach { category ->
            if (current.isEnabled(category)) {
                scheduleCategory(category, current.timeFor(category))
            } else {
                cancelCategory(category, cancelVisible = true)
            }
        }
    }

    fun cancelAllLocalNotifications() {
        NativeNotificationCategory.entries.forEach { category ->
            cancelCategory(category, cancelVisible = true)
        }
    }

    fun cancelCategory(category: NativeNotificationCategory, cancelVisible: Boolean) {
        cancelScheduledAlarm(category)
        if (cancelVisible) {
            notificationManager.cancel(category.notificationId)
        }
    }

    fun deliverScheduledNotification(category: NativeNotificationCategory) {
        val current = settings()
        if (!current.enabled || !current.isEnabled(category)) {
            cancelScheduledAlarm(category)
            return
        }
        if (!canPostNotifications()) {
            cancelScheduledAlarm(category)
            Log.w(TAG, "Notification permission missing; cancelled ${category.key} alarm")
            return
        }

        createNotificationChannels()
        showNotification(
            category = category,
            title = context.getString(category.titleResId),
            body = bodyFor(category)
        )
        scheduleCategory(category, current.timeFor(category))
    }

    fun displayLegacyMealNotification(title: String?, body: String?) {
        if (!settings().enabled || !canPostNotifications()) {
            Log.d(TAG, "Ignored legacy meal FCM notification while notifications are disabled")
            return
        }

        createNotificationChannels()
        showNotification(
            category = NativeNotificationCategory.MEAL,
            title = title.normalizedOrNull()
                ?: context.getString(NativeNotificationCategory.MEAL.titleResId),
            body = body.normalizedOrNull()
                ?: context.getString(NativeNotificationCategory.MEAL.fallbackBodyResId)
        )
    }

    fun cacheTodayMealContent(renderedTitle: String?, body: String?) {
        if (renderedTitle != TODAY_MEAL_TITLE) {
            return
        }
        saveTodayCache(KEY_MEAL_CACHE_DATE, KEY_MEAL_CACHE_BODY, body)
    }

    fun cacheTodayTimetableContent(renderedTitle: String?, body: String?) {
        if (renderedTitle != TODAY_TIMETABLE_TITLE) {
            return
        }
        saveTodayCache(KEY_TIMETABLE_CACHE_DATE, KEY_TIMETABLE_CACHE_BODY, body)
    }

    private fun bodyFor(category: NativeNotificationCategory): String {
        val cached = when (category) {
            NativeNotificationCategory.MEAL ->
                readTodayCache(KEY_MEAL_CACHE_DATE, KEY_MEAL_CACHE_BODY)
            NativeNotificationCategory.TIMETABLE ->
                readTodayCache(KEY_TIMETABLE_CACHE_DATE, KEY_TIMETABLE_CACHE_BODY)
            NativeNotificationCategory.SCHOOL_NOTICE -> null
        }
        return cached ?: context.getString(category.fallbackBodyResId)
    }

    @SuppressLint("MissingPermission")
    private fun scheduleCategory(category: NativeNotificationCategory, time: String) {
        cancelScheduledAlarm(category)
        val pendingIntent = alarmPendingIntent(category, PendingIntent.FLAG_UPDATE_CURRENT) ?: return
        val triggerAtMillis = nextTriggerAtMillis(time)

        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }
        } catch (error: SecurityException) {
            Log.w(TAG, "Exact alarm access unavailable; using an inexact alarm", error)
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
    }

    private fun showNotification(
        category: NativeNotificationCategory,
        title: String,
        body: String
    ) {
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            category.contentRequestCode,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, category.channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_DEFAULT)
        }

        try {
            notificationManager.notify(category.notificationId, builder.build())
        } catch (error: SecurityException) {
            Log.w(TAG, "Unable to display ${category.key} notification", error)
        }
    }

    private fun cancelAllScheduledAlarms() {
        NativeNotificationCategory.entries.forEach(::cancelScheduledAlarm)
    }

    private fun cancelScheduledAlarm(category: NativeNotificationCategory) {
        val pendingIntent = alarmPendingIntent(category, PendingIntent.FLAG_NO_CREATE) ?: return
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    private fun alarmPendingIntent(
        category: NativeNotificationCategory,
        creationFlag: Int
    ): PendingIntent? {
        val intent = Intent(context, NativeNotificationReceiver::class.java).apply {
            action = ACTION_DELIVER_NOTIFICATION
            putExtra(EXTRA_CATEGORY, category.key)
        }
        return PendingIntent.getBroadcast(
            context,
            category.alarmRequestCode,
            intent,
            creationFlag or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextTriggerAtMillis(time: String): Long {
        val parts = time.split(":")
        val now = Calendar.getInstance()
        return Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, parts[0].toInt())
            set(Calendar.MINUTE, parts[1].toInt())
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) {
                add(Calendar.DATE, 1)
            }
        }.timeInMillis
    }

    private fun savedTime(key: String, fallback: String): String =
        normalizeTime(preferences.getString(key, null), fallback)

    private fun normalizeTime(value: String?, fallback: String): String =
        value?.trim()?.takeIf { TIME_PATTERN.matches(it) } ?: fallback

    private fun persistSettings(settings: NativeNotificationSettings) {
        preferences.edit()
            .putBoolean(KEY_MASTER_ENABLED, settings.enabled)
            .putBoolean(KEY_MEAL_ENABLED, settings.mealEnabled)
            .putBoolean(KEY_TIMETABLE_ENABLED, settings.timetableEnabled)
            .putBoolean(KEY_SCHOOL_NOTICE_ENABLED, settings.schoolNoticeEnabled)
            .putString(KEY_MEAL_TIME, settings.mealTime)
            .putString(KEY_TIMETABLE_TIME, settings.timetableTime)
            .putString(KEY_SCHOOL_NOTICE_TIME, settings.schoolNoticeTime)
            .apply()
    }

    private fun saveTodayCache(dateKey: String, bodyKey: String, body: String?) {
        val normalized = body.normalizedOrNull() ?: return
        preferences.edit()
            .putString(dateKey, todayKey())
            .putString(bodyKey, normalized.take(MAX_CACHED_BODY_LENGTH))
            .apply()
    }

    private fun readTodayCache(dateKey: String, bodyKey: String): String? {
        if (preferences.getString(dateKey, null) != todayKey()) {
            return null
        }
        return preferences.getString(bodyKey, null).normalizedOrNull()
    }

    private fun todayKey(): String =
        SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())

    private fun String?.normalizedOrNull(): String? =
        this?.trim()?.takeIf { it.isNotEmpty() }

    companion object {
        const val ACTION_DELIVER_NOTIFICATION =
            "kr.hs.ghas.ghason.action.DELIVER_NATIVE_NOTIFICATION"
        const val EXTRA_CATEGORY = "notification_category"

        private const val PREFS_NAME = "ghas_lunch_preferences"
        private const val KEY_MASTER_ENABLED = "native_notification_enabled"
        private const val KEY_MEAL_ENABLED = "native_notification_meal_enabled"
        private const val KEY_TIMETABLE_ENABLED = "native_notification_timetable_enabled"
        private const val KEY_SCHOOL_NOTICE_ENABLED = "native_notification_school_notice_enabled"
        private const val KEY_MEAL_TIME = "native_notification_meal_time"
        private const val KEY_TIMETABLE_TIME = "native_notification_timetable_time"
        private const val KEY_SCHOOL_NOTICE_TIME = "native_notification_school_notice_time"
        private const val KEY_MEAL_CACHE_DATE = "native_notification_meal_cache_date"
        private const val KEY_MEAL_CACHE_BODY = "native_notification_meal_cache_body"
        private const val KEY_TIMETABLE_CACHE_DATE = "native_notification_timetable_cache_date"
        private const val KEY_TIMETABLE_CACHE_BODY = "native_notification_timetable_cache_body"
        private const val TODAY_MEAL_TITLE = "오늘의 급식"
        private const val TODAY_TIMETABLE_TITLE = "오늘의 시간표"
        private const val MAX_CACHED_BODY_LENGTH = 500
        private val TIME_PATTERN = Regex("""^(?:[01]\d|2[0-3]):[0-5]\d$""")
        private const val TAG = "NativeNotification"
    }
}

class NativeNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != NativeNotificationScheduler.ACTION_DELIVER_NOTIFICATION) {
            return
        }
        val category = NativeNotificationCategory.fromKey(
            intent.getStringExtra(NativeNotificationScheduler.EXTRA_CATEGORY)
        ) ?: return
        NativeNotificationScheduler(context.applicationContext)
            .deliverScheduledNotification(category)
    }
}

class NativeNotificationRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (
            intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            NativeNotificationScheduler(context.applicationContext)
                .scheduleSelectedNotifications()
        }
    }
}

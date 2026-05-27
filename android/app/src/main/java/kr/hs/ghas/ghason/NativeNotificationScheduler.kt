package kr.hs.ghas.ghason

<<<<<<< HEAD
import android.annotation.SuppressLint
import android.Manifest
=======
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
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
<<<<<<< HEAD
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

    @SuppressLint("MissingPermission") // Android 12+ exact alarms are gated and have a fallback.
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
        Log.d(TAG, "Scheduled ${category.key} notification at $time")
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
=======
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
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, category.channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
<<<<<<< HEAD

        builder
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentTitle(title)
=======
        val body = notificationBody(context, category)
        builder
            .setSmallIcon(R.drawable.ic_stat_lunch)
            .setContentTitle(context.getString(category.titleResId))
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
<<<<<<< HEAD

=======
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_DEFAULT)
        }
<<<<<<< HEAD

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
        val pendingIntent = alarmPendingIntent(
            category,
            PendingIntent.FLAG_NO_CREATE
        ) ?: return
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
=======
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
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
        }
    }
}

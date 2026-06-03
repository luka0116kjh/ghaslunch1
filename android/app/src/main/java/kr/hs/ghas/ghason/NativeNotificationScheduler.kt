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
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
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
    val alarmAction: String,
    val contentAction: String,
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
        alarmAction = "kr.hs.ghas.ghason.action.DELIVER_NATIVE_NOTIFICATION.meal",
        contentAction = "kr.hs.ghas.ghason.action.OPEN_NOTIFICATION.meal",
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
        alarmAction = "kr.hs.ghas.ghason.action.DELIVER_NATIVE_NOTIFICATION.timetable",
        contentAction = "kr.hs.ghas.ghason.action.OPEN_NOTIFICATION.timetable",
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
        alarmAction = "kr.hs.ghas.ghason.action.DELIVER_NATIVE_NOTIFICATION.school_notice",
        contentAction = "kr.hs.ghas.ghason.action.OPEN_NOTIFICATION.school_notice",
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
    val mealEnabled: Boolean,
    val timetableEnabled: Boolean,
    val schoolNoticeEnabled: Boolean,
    val mealTime: String,
    val timetableTime: String,
    val schoolNoticeTime: String
) {
    // Derived aggregate: notifications are "on" when at least one category is enabled.
    // There is no separate master gate anymore; categories work independently.
    val enabled: Boolean
        get() = mealEnabled || timetableEnabled || schoolNoticeEnabled

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

    init {
        // Guarantee the legacy master-gate migration runs before any caller can read state,
        // schedule, reschedule, or deliver. Headless entry points (alarm receiver, boot /
        // package-replaced / time-change reschedule receiver, FCM service) construct their own
        // scheduler without opening MainActivity, so the migration cannot rely on onCreate().
        migrateMasterGateIfNeeded()
    }

    fun settings(): NativeNotificationSettings = NativeNotificationSettings(
        mealEnabled = preferences.getBoolean(KEY_MEAL_ENABLED, false),
        timetableEnabled = preferences.getBoolean(KEY_TIMETABLE_ENABLED, false),
        schoolNoticeEnabled = preferences.getBoolean(KEY_SCHOOL_NOTICE_ENABLED, false),
        mealTime = savedTime(KEY_MEAL_TIME, NativeNotificationCategory.MEAL.defaultTime),
        timetableTime = savedTime(KEY_TIMETABLE_TIME, NativeNotificationCategory.TIMETABLE.defaultTime),
        schoolNoticeTime = savedTime(
            KEY_SCHOOL_NOTICE_TIME,
            NativeNotificationCategory.SCHOOL_NOTICE.defaultTime
        )
    )

    fun updateSettings(
        mealEnabled: Boolean,
        timetableEnabled: Boolean,
        schoolNoticeEnabled: Boolean,
        mealTime: String?,
        timetableTime: String?,
        schoolNoticeTime: String?
    ): NativeNotificationSettings {
        val updated = NativeNotificationSettings(
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

    // Convenience action behind "모든 알림 켜기" / "모든 알림 끄기": flips every category at once.
    fun setAllCategoriesEnabled(enabled: Boolean): NativeNotificationSettings {
        val updated = settings().copy(
            mealEnabled = enabled,
            timetableEnabled = enabled,
            schoolNoticeEnabled = enabled
        )
        persistSettings(updated)
        return updated
    }

    /**
     * One-time migration away from the old master-gate model. Previously a single master flag
     * gated all categories; now each category is independent. To preserve every user's prior
     * effective state we collapse `effectiveCategory = oldMaster && storedCategory` exactly once.
     * Invoked from `init` so every instance (including headless receivers/services) migrates
     * before reading or acting on state; the migrated flag keeps it idempotent.
     */
    private fun migrateMasterGateIfNeeded() {
        if (preferences.getBoolean(KEY_MASTER_GATE_MIGRATED, false)) {
            return
        }
        val oldMaster = preferences.getBoolean(KEY_MASTER_ENABLED, false)
        val meal = oldMaster && preferences.getBoolean(KEY_MEAL_ENABLED, true)
        val timetable = oldMaster && preferences.getBoolean(KEY_TIMETABLE_ENABLED, true)
        val schoolNotice = oldMaster && preferences.getBoolean(KEY_SCHOOL_NOTICE_ENABLED, true)
        preferences.edit {
            putBoolean(KEY_MEAL_ENABLED, meal)
            putBoolean(KEY_TIMETABLE_ENABLED, timetable)
            putBoolean(KEY_SCHOOL_NOTICE_ENABLED, schoolNotice)
            putBoolean(KEY_MASTER_GATE_MIGRATED, true)
        }
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
            notificationManager.cancel(category.key, category.notificationId)
            // Remove notifications posted by earlier app versions that did not use tags.
            notificationManager.cancel(category.notificationId)
        }
    }

    fun deliverScheduledNotification(category: NativeNotificationCategory) {
        val current = settings()
        if (!current.isEnabled(category)) {
            cancelScheduledAlarm(category)
            return
        }
        if (!canPostNotifications()) {
            cancelScheduledAlarm(category)
            Log.w(TAG, "Notification permission missing; cancelled ${category.key} alarm")
            return
        }

        if (shouldSkipScheduledNotification(category)) {
            Log.d(TAG, "Skipped ${category.key} notification for a non-school meal day")
            scheduleCategory(category, current.timeFor(category))
            return
        }

        val body: String
        if (category == NativeNotificationCategory.MEAL) {
            // Meal notifications are sent ONLY when the NEIS API positively confirms a menu for today.
            // Every other outcome — no-meal result, request failure, timeout, parse error, or offline —
            // suppresses today's notification. A false "check today's meal" alert is worse than a missed
            // one, so NO cached content is consulted for delivery. Future alarms are still rescheduled.
            val lookup = lookupTodayMeal()
            if (lookup is MealLookup.Available) {
                body = lookup.body
            } else {
                val reason = if (lookup is MealLookup.Empty) {
                    "API reports no meal today"
                } else {
                    "API request failed/timed out/unparseable or device offline"
                }
                Log.d(TAG, "Suppressed meal notification ($reason)")
                scheduleCategory(category, current.timeFor(category))
                return
            }
        } else {
            body = bodyFor(category)
            if (shouldSuppressNotification(category, body)) {
                Log.d(TAG, "Suppressed ${category.key} notification with empty meal content")
                scheduleCategory(category, current.timeFor(category))
                return
            }
        }

        createNotificationChannels()
        showNotification(
            category = category,
            title = context.getString(category.titleResId),
            body = body
        )
        scheduleCategory(category, current.timeFor(category))
    }

    private sealed interface MealLookup {
        data class Available(val body: String) : MealLookup
        object Empty : MealLookup
        object Unknown : MealLookup
    }

    /**
     * Fetches today's meal straight from the NEIS open API (the same endpoint the web app uses,
     * no key required). Returns [MealLookup.Empty] when the API has no menu for today
     * (no `mealServiceDietInfo` section / `RESULT.CODE = INFO-200`), [MealLookup.Available] with a
     * cleaned menu string when there is one, or [MealLookup.Unknown] on any network/parse failure.
     */
    private fun lookupTodayMeal(): MealLookup {
        val ymd = todayKey()
        val urlString = "$NEIS_MEAL_URL?Type=json" +
            "&ATPT_OFCDC_SC_CODE=$NEIS_OFFICE_CODE" +
            "&SD_SCHUL_CODE=$NEIS_SCHOOL_CODE" +
            "&MLSV_YMD=$ymd&pSize=100"
        return try {
            val connection = (URL(urlString).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = NEIS_TIMEOUT_MS
                readTimeout = NEIS_TIMEOUT_MS
            }
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    return MealLookup.Unknown
                }
                val text = connection.inputStream.bufferedReader().use { it.readText() }
                parseMealLookup(text)
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Meal API lookup failed; will fall back to cache", error)
            MealLookup.Unknown
        }
    }

    private fun parseMealLookup(json: String): MealLookup {
        return try {
            val root = JSONObject(json)
            // No-meal days omit "mealServiceDietInfo" entirely (RESULT.CODE = INFO-200).
            val sections = root.optJSONArray("mealServiceDietInfo") ?: return MealLookup.Empty
            var rows: JSONArray? = null
            for (i in 0 until sections.length()) {
                val r = sections.optJSONObject(i)?.optJSONArray("row")
                if (r != null) {
                    rows = r
                    break
                }
            }
            if (rows == null || rows.length() == 0) return MealLookup.Empty

            var lunch: String? = null
            var firstAny: String? = null
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val menu = cleanMenuText(row.optString("DDISH_NM"))
                if (menu.isEmpty()) continue
                if (firstAny == null) firstAny = menu
                if (row.optString("MMEAL_SC_CODE") == "2") { // 2 = lunch
                    lunch = menu
                    break
                }
            }
            val body = lunch ?: firstAny ?: return MealLookup.Empty
            MealLookup.Available(body)
        } catch (error: Exception) {
            Log.w(TAG, "Meal API parse failed; will fall back to cache", error)
            MealLookup.Unknown
        }
    }

    /** Mirrors the web app's normalizeMenuText: drop allergen brackets and <br> markers. */
    private fun cleanMenuText(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        return raw
            .replace(Regex("\\([^)]*\\)"), "")
            .replace(Regex("(?i)<br\\s*/?>"), " ")
            .split(Regex("\\s+"))
            .filter { it.isNotEmpty() }
            .joinToString(", ")
    }

    fun displayLegacyMealNotification(title: String?, body: String?) {
        val current = settings()
        if (!current.mealEnabled || !canPostNotifications()) {
            Log.d(TAG, "Ignored legacy meal FCM notification while meal notifications are disabled")
            return
        }

        val resolvedTitle = title.normalizedOrNull()
            ?: context.getString(NativeNotificationCategory.MEAL.titleResId)
        val resolvedBody = body.normalizedOrNull()
            ?: context.getString(NativeNotificationCategory.MEAL.fallbackBodyResId)
        if (shouldSuppressNotification(NativeNotificationCategory.MEAL, resolvedBody)) {
            Log.d(TAG, "Suppressed legacy meal FCM notification with empty meal content")
            return
        }

        createNotificationChannels()
        showNotification(
            category = NativeNotificationCategory.MEAL,
            title = resolvedTitle,
            body = resolvedBody
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

    private fun shouldSkipScheduledNotification(category: NativeNotificationCategory): Boolean {
        if (category != NativeNotificationCategory.MEAL) {
            return false
        }
        val dayOfWeek = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        return dayOfWeek == Calendar.SATURDAY || dayOfWeek == Calendar.SUNDAY
    }

    private fun shouldSuppressNotification(
        category: NativeNotificationCategory,
        body: String
    ): Boolean =
        category == NativeNotificationCategory.MEAL && isEmptyMealContent(body)

    private fun isEmptyMealContent(body: String): Boolean {
        val normalized = body.trim()
        return normalized.contains("급식 정보가 없습니다") ||
            normalized.contains("주말/휴일") ||
            normalized.contains("오늘의 급식에서")
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
            action = category.contentAction
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_CATEGORY, category.key)
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
            notificationManager.notify(category.key, category.notificationId, builder.build())
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
            action = category.alarmAction
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
        preferences.edit {
            // Kept in sync (as the derived aggregate) only for backward compatibility.
            putBoolean(KEY_MASTER_ENABLED, settings.enabled)
            putBoolean(KEY_MEAL_ENABLED, settings.mealEnabled)
            putBoolean(KEY_TIMETABLE_ENABLED, settings.timetableEnabled)
            putBoolean(KEY_SCHOOL_NOTICE_ENABLED, settings.schoolNoticeEnabled)
            putString(KEY_MEAL_TIME, settings.mealTime)
            putString(KEY_TIMETABLE_TIME, settings.timetableTime)
            putString(KEY_SCHOOL_NOTICE_TIME, settings.schoolNoticeTime)
        }
    }

    private fun saveTodayCache(dateKey: String, bodyKey: String, body: String?) {
        val normalized = body.normalizedOrNull() ?: return
        preferences.edit {
            putString(dateKey, todayKey())
            putString(bodyKey, normalized.take(MAX_CACHED_BODY_LENGTH))
        }
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
        const val EXTRA_CATEGORY = "notification_category"

        private const val PREFS_NAME = "ghas_lunch_preferences"
        private const val KEY_MASTER_ENABLED = "native_notification_enabled"
        private const val KEY_MASTER_GATE_MIGRATED = "native_notification_master_gate_migrated_v1"
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

        // NEIS open API (same endpoint/school as the web app; no API key required).
        private const val NEIS_MEAL_URL = "https://open.neis.go.kr/hub/mealServiceDietInfo"
        private const val NEIS_OFFICE_CODE = "J10"
        private const val NEIS_SCHOOL_CODE = "7530908"
        private const val NEIS_TIMEOUT_MS = 4000
        private val TIME_PATTERN = Regex("""^(?:[01]\d|2[0-3]):[0-5]\d$""")
        private const val TAG = "NativeNotification"
    }
}

class NativeNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val category = NativeNotificationCategory.fromKey(
            intent.getStringExtra(NativeNotificationScheduler.EXTRA_CATEGORY)
        ) ?: return
        if (intent.action != category.alarmAction) {
            return
        }
        // deliverScheduledNotification now queries the meal API for the MEAL category, so it must
        // not run on the main thread. goAsync keeps the broadcast alive (~10s) for the network call.
        val appContext = context.applicationContext
        val pendingResult = goAsync()
        Thread {
            try {
                NativeNotificationScheduler(appContext).deliverScheduledNotification(category)
            } finally {
                pendingResult.finish()
            }
        }.start()
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

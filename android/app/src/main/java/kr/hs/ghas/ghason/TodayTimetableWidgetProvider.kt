package kr.hs.ghas.ghason

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.edit
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * "오늘 시간표" 위젯. 급식 위젯(TodayMealWidgetProvider)과 동일한 자기완결 패턴을 따르되,
 * 데이터는 하이브리드로 구한다.
 *
 *  1) 앱(WebView)이 기존 buildTimetableForDate(NEIS+보정 병합, 휴일/방학/시험 처리) 결과를
 *     TimetableWidgetStore 캐시로 push한다. → 방학/휴일/보정 데이터까지 정확.
 *  2) 위젯 새로고침/자동 갱신 시 NEIS hisTimetable을 직접 조회해 최신 행이 있으면 우선 표시한다.
 *     NEIS가 비어 있으면 오늘자 캐시로, 캐시도 없으면 empty/error로 폴백한다.
 *
 * 학년·반은 앱이 push한 값(TimetableWidgetStore)만 사용한다. 값이 없으면 classNotConfigured.
 */
class TodayTimetableWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 자동/푸시 갱신: 네트워크 없이 캐시 상태를 즉시 그린 뒤, 백그라운드에서 NEIS로 보강한다.
        val cachedState = TimetableWidgetStore.cachedOnlyState(context)
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it, cachedState) }
        refreshWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayTimetableWidgetProvider::class.java)
            )
            // 사용자가 새로고침을 누른 경우엔 로딩을 보여준 뒤 다시 요청한다.
            ids.forEach { updateWidget(context, manager, it, TimetableWidgetState.Loading) }
            refreshWidgets(context, manager, ids)
        }
    }

    private fun refreshWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        if (appWidgetIds.isEmpty()) return
        Thread {
            val state = resolveTimetableState(context)
            appWidgetIds.forEach { updateWidget(context, appWidgetManager, it, state) }
        }.start()
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        state: TimetableWidgetState
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_timetable)
        views.setTextViewText(
            R.id.today_timetable_widget_title,
            context.getString(R.string.widget_today_timetable_title)
        )
        views.setTextViewText(R.id.today_timetable_widget_date, todayLabel())
        views.setOnClickPendingIntent(R.id.today_timetable_widget_root, openTimetableIntent(context))
        views.setOnClickPendingIntent(R.id.today_timetable_widget_refresh, refreshIntent(context))
        bindState(context, views, state)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun bindState(context: Context, views: RemoteViews, state: TimetableWidgetState) {
        val classLabel = state.classLabel(context)
        views.setTextViewText(R.id.today_timetable_widget_class, classLabel)
        views.setViewVisibility(
            R.id.today_timetable_widget_class,
            if (classLabel.isEmpty()) View.GONE else View.VISIBLE
        )

        if (state is TimetableWidgetState.Available) {
            views.setViewVisibility(R.id.today_timetable_widget_rows, View.VISIBLE)
            views.setViewVisibility(R.id.today_timetable_widget_message, View.GONE)
            bindRows(context, views, state.periods)
        } else {
            views.setViewVisibility(R.id.today_timetable_widget_rows, View.GONE)
            views.setViewVisibility(R.id.today_timetable_widget_message, View.VISIBLE)
            views.setTextViewText(R.id.today_timetable_widget_message, state.message(context))
        }
    }

    private fun bindRows(context: Context, views: RemoteViews, periods: List<TimetablePeriod>) {
        // 최대 7행. 데이터가 있는 행만 표시하고 나머지는 숨긴다.
        val visible = periods.take(ROW_IDS.size)
        ROW_IDS.forEachIndexed { index, ids ->
            val period = visible.getOrNull(index)
            if (period == null) {
                views.setViewVisibility(ids.row, View.GONE)
            } else {
                views.setViewVisibility(ids.row, View.VISIBLE)
                views.setTextViewText(
                    ids.period,
                    context.getString(R.string.widget_today_timetable_period_format, period.period)
                )
                views.setTextViewText(ids.subject, period.subject)
            }
        }
    }

    /** 위젯 본문/미설정 안내 탭 → 앱을 열고 시간표 탭으로 이동시킨다(외부 브라우저 금지). */
    private fun openTimetableIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse(APP_URL)
            putExtra(MainActivity.EXTRA_OPEN_TARGET, MainActivity.OPEN_TARGET_TIMETABLE)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun refreshIntent(context: Context): PendingIntent {
        val intent = Intent(context, TodayTimetableWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    /**
     * 하이브리드 상태 해석(백그라운드 스레드에서만 호출). NEIS 우선, 없으면 오늘자 캐시로 폴백.
     */
    private fun resolveTimetableState(context: Context): TimetableWidgetState {
        val grade = TimetableWidgetStore.grade(context)
        val classNum = TimetableWidgetStore.classNum(context)
        if (grade.isBlank() || classNum.isBlank()) {
            return TimetableWidgetState.ClassNotConfigured
        }

        // 1) 앱이 push한 오늘자 캐시(NEIS+보정+휴일/방학 병합 결과)가 있으면 최우선(권위 있음).
        when (TimetableWidgetStore.cachedStateForToday(context)) {
            "available" -> {
                val cached = TimetableWidgetStore.cachedPeriodsForToday(context)
                if (!cached.isNullOrEmpty()) {
                    return TimetableWidgetState.Available(grade, classNum, cached)
                }
                return TimetableWidgetState.Empty(grade, classNum)
            }
            "empty" -> return TimetableWidgetState.Empty(grade, classNum)
        }

        // 2) 캐시가 없을 때만 로컬 주말/방학 판정을 적용한다.
        if (isWeekend() || isSchoolBreak()) {
            return TimetableWidgetState.Empty(grade, classNum)
        }

        // 3) NEIS + 번들 보정 시간표를 교시별로 병합(NEIS 우선, 빈 교시는 보정).
        val neisPeriods = lookupTodayTimetable(grade, classNum)
        val neisByPeriod = neisPeriods?.associate { it.period to it.subject } ?: emptyMap()
        val fallback = loadFallbackPeriods(context, grade, classNum)

        val merged = (MIN_PERIOD..MAX_PERIOD).mapNotNull { period ->
            val subject = (neisByPeriod[period] ?: fallback[period])?.trim()
            if (!subject.isNullOrEmpty() && subject != "공강") {
                TimetablePeriod(period, subject)
            } else {
                null
            }
        }
        if (merged.isNotEmpty()) {
            return TimetableWidgetState.Available(grade, classNum, merged)
        }

        // 3) 병합 결과가 없고 NEIS도 실패했으면 오류, 그 외엔 없음.
        return if (neisPeriods == null && fallback.isEmpty()) {
            TimetableWidgetState.Error(grade, classNum)
        } else {
            TimetableWidgetState.Empty(grade, classNum)
        }
    }

    // 웹 SCHEDULE_SOURCE의 방학식~개학식 구간을 미러링(배포 전에도 방학이면 "없음").
    private fun isSchoolBreak(): Boolean {
        val today = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
        return BREAK_RANGES.any { today >= it.first && today <= it.second }
    }

    // 번들 보정 시간표(res/raw/class_timetable_2026.json, 웹과 동일 데이터)에서 오늘 교시를 읽는다.
    private fun loadFallbackPeriods(
        context: Context,
        grade: String,
        classNum: String
    ): Map<Int, String> {
        val root = loadFallbackJson(context) ?: return emptyMap()
        val classObject = root.optJSONObject("$grade-$classNum") ?: return emptyMap()
        val subjects = classObject.optJSONArray(todayDayName()) ?: return emptyMap()
        val result = LinkedHashMap<Int, String>()
        val count = minOf(subjects.length(), MAX_PERIOD)
        for (index in 0 until count) {
            val subject = subjects.optString(index).trim()
            if (subject.isNotEmpty()) {
                result[index + 1] = subject
            }
        }
        return result
    }

    private fun loadFallbackJson(context: Context): JSONObject? {
        cachedFallback?.let { return it }
        return try {
            val text = context.resources.openRawResource(R.raw.class_timetable_2026)
                .bufferedReader()
                .use { it.readText() }
            JSONObject(text).also { cachedFallback = it }
        } catch (error: Exception) {
            Log.w(TAG, "Fallback timetable load failed", error)
            null
        }
    }

    private fun todayDayName(): String {
        val dow = Calendar.getInstance().get(Calendar.DAY_OF_WEEK) // 1=일 ... 7=토
        return WEEKDAY_NAMES[dow - 1]
    }

    /**
     * NEIS hisTimetable 직접 조회(급식 위젯과 동일한 keyless 엔드포인트/학교 코드).
     * 네트워크/HTTP 실패 시 null(→오류), 행이 없으면 빈 리스트(→없음/캐시 폴백)를 돌려준다.
     */
    private fun lookupTodayTimetable(grade: String, classNum: String): List<TimetablePeriod>? {
        val ymd = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
        val urlString = "$NEIS_TIMETABLE_URL?Type=json" +
            "&ATPT_OFCDC_SC_CODE=$NEIS_OFFICE_CODE" +
            "&SD_SCHUL_CODE=$NEIS_SCHOOL_CODE" +
            "&ALL_TI_YMD=$ymd" +
            "&GRADE=${urlEncode(grade)}" +
            "&CLASS_NM=${urlEncode(classNum)}" +
            "&pSize=100"
        return try {
            val connection = (URL(urlString).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = NEIS_TIMEOUT_MS
                readTimeout = NEIS_TIMEOUT_MS
            }
            try {
                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    return null
                }
                parseTimetable(connection.inputStream.bufferedReader().use { it.readText() })
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Today timetable widget lookup failed", error)
            null
        }
    }

    private fun parseTimetable(json: String): List<TimetablePeriod> {
        return try {
            val sections = JSONObject(json).optJSONArray("hisTimetable") ?: return emptyList()
            val rows = findRows(sections) ?: return emptyList()

            val byPeriod = LinkedHashMap<Int, String>()
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                val period = row.optString("PERIO").toIntOrNull() ?: continue
                if (period < MIN_PERIOD || period > MAX_PERIOD) continue
                val subject = cleanSubject(row.optString("ITRT_CNTNT"))
                if (subject.isEmpty()) continue
                if (!byPeriod.containsKey(period)) {
                    byPeriod[period] = subject
                }
            }
            byPeriod.entries
                .sortedBy { it.key }
                .map { TimetablePeriod(it.key, it.value) }
        } catch (error: Exception) {
            Log.w(TAG, "Today timetable widget parse failed", error)
            emptyList()
        }
    }

    private fun findRows(sections: JSONArray): JSONArray? {
        for (index in 0 until sections.length()) {
            val rows = sections.optJSONObject(index)?.optJSONArray("row")
            if (rows != null) return rows
        }
        return null
    }

    /** 웹 cleanTimetableSubject와 동일하게 별표를 제거하고 다듬는다. */
    private fun cleanSubject(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        return raw.replace("*", "").trim()
    }

    private fun urlEncode(value: String): String =
        URLEncoder.encode(value, "UTF-8")

    private fun todayLabel(): String =
        SimpleDateFormat("M월 d일 EEEE", Locale.KOREAN).format(Date())

    private fun isWeekend(): Boolean {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        return day == Calendar.SATURDAY || day == Calendar.SUNDAY
    }

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    private data class RowIds(val row: Int, val period: Int, val subject: Int)

    companion object {
        private const val TAG = "TodayTimetableWidget"
        private const val ACTION_REFRESH = "kr.hs.ghas.ghason.action.REFRESH_TODAY_TIMETABLE_WIDGET"
        private const val APP_URL = "https://ghaslunch1.web.app/"
        private const val NEIS_TIMETABLE_URL = "https://open.neis.go.kr/hub/hisTimetable"
        private const val NEIS_OFFICE_CODE = "J10"
        private const val NEIS_SCHOOL_CODE = "7530908"
        private const val NEIS_TIMEOUT_MS = 4000
        private const val MIN_PERIOD = 1
        private const val MAX_PERIOD = 7

        private val WEEKDAY_NAMES = listOf("일", "월", "화", "수", "목", "금", "토")
        // 웹 schedule.js 방학식~개학식 구간(yyyyMMdd).
        private val BREAK_RANGES = listOf(
            "20260721" to "20260819", // 여름방학
            "20270106" to "20270228"  // 겨울방학(개학 미정 근사)
        )
        @Volatile
        private var cachedFallback: JSONObject? = null

        private val ROW_IDS = listOf(
            RowIds(R.id.today_timetable_row_1, R.id.today_timetable_period_1, R.id.today_timetable_subject_1),
            RowIds(R.id.today_timetable_row_2, R.id.today_timetable_period_2, R.id.today_timetable_subject_2),
            RowIds(R.id.today_timetable_row_3, R.id.today_timetable_period_3, R.id.today_timetable_subject_3),
            RowIds(R.id.today_timetable_row_4, R.id.today_timetable_period_4, R.id.today_timetable_subject_4),
            RowIds(R.id.today_timetable_row_5, R.id.today_timetable_period_5, R.id.today_timetable_subject_5),
            RowIds(R.id.today_timetable_row_6, R.id.today_timetable_period_6, R.id.today_timetable_subject_6),
            RowIds(R.id.today_timetable_row_7, R.id.today_timetable_period_7, R.id.today_timetable_subject_7)
        )

        /** 앱(WebView 브리지)에서 학년·반/캐시가 갱신되면 등록된 위젯을 다시 그린다. */
        fun requestUpdate(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TodayTimetableWidgetProvider::class.java)
            )
            if (ids.isEmpty()) return
            val intent = Intent(context, TodayTimetableWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}

/** 위젯 상태. 급식 위젯의 sealed 패턴을 시간표에 맞게 확장했다. */
internal sealed interface TimetableWidgetState {
    fun message(context: Context): String
    fun classLabel(context: Context): String

    data class Available(
        val grade: String,
        val classNum: String,
        val periods: List<TimetablePeriod>
    ) : TimetableWidgetState {
        override fun message(context: Context): String = ""
        override fun classLabel(context: Context): String = classText(context, grade, classNum)
    }

    data class Empty(val grade: String, val classNum: String) : TimetableWidgetState {
        override fun message(context: Context): String =
            context.getString(R.string.widget_today_timetable_empty)

        override fun classLabel(context: Context): String = classText(context, grade, classNum)
    }

    data class Error(val grade: String, val classNum: String) : TimetableWidgetState {
        override fun message(context: Context): String =
            context.getString(R.string.widget_today_timetable_error)

        override fun classLabel(context: Context): String = classText(context, grade, classNum)
    }

    object Loading : TimetableWidgetState {
        override fun message(context: Context): String =
            context.getString(R.string.widget_today_timetable_loading)

        override fun classLabel(context: Context): String = ""
    }

    object ClassNotConfigured : TimetableWidgetState {
        override fun message(context: Context): String =
            context.getString(R.string.widget_today_timetable_not_configured)

        override fun classLabel(context: Context): String = ""
    }

    companion object {
        fun classText(context: Context, grade: String, classNum: String): String {
            if (grade.isBlank() || classNum.isBlank()) return ""
            return context.getString(
                R.string.widget_today_timetable_class_format,
                grade,
                classNum
            )
        }
    }
}

internal data class TimetablePeriod(val period: Int, val subject: String)

/**
 * 위젯이 사용하는 학년·반과 오늘 시간표 캐시 저장소. 앱과 위젯이 같은 패키지/UID이므로
 * 앱이 쓰는 SharedPreferences("ghas_lunch_preferences")를 위젯이 직접 읽는다(App Group 불필요).
 */
internal object TimetableWidgetStore {
    private const val PREFS_NAME = "ghas_lunch_preferences"
    private const val KEY_GRADE = "widget_timetable_grade"
    private const val KEY_CLASS = "widget_timetable_class"
    private const val KEY_CACHE_DATE = "widget_timetable_cache_date"
    private const val KEY_CACHE_STATE = "widget_timetable_cache_state"
    private const val KEY_CACHE_PERIODS = "widget_timetable_cache_periods"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun saveClass(context: Context, grade: String?, classNum: String?) {
        prefs(context).edit {
            putString(KEY_GRADE, grade?.trim().orEmpty())
            putString(KEY_CLASS, classNum?.trim().orEmpty())
        }
    }

    fun grade(context: Context): String = prefs(context).getString(KEY_GRADE, "").orEmpty()

    fun classNum(context: Context): String = prefs(context).getString(KEY_CLASS, "").orEmpty()

    /**
     * 웹이 push한 오늘 시간표 JSON을 저장한다.
     * 형식: {"date":"yyyyMMdd","grade":"3","classNum":"2","state":"available|empty|classNotConfigured",
     *        "periods":[{"period":1,"subject":"..."}]}
     */
    fun saveCache(context: Context, json: String?) {
        if (json.isNullOrBlank()) return
        try {
            val root = JSONObject(json)
            val date = root.optString("date")
            val state = root.optString("state")
            if (date.isBlank() || state.isBlank()) return
            val periods = root.optJSONArray("periods") ?: JSONArray()
            prefs(context).edit {
                putString(KEY_CACHE_DATE, date)
                putString(KEY_CACHE_STATE, state)
                putString(KEY_CACHE_PERIODS, periods.toString())
                // classNotConfigured가 아니면 학년·반도 최신값으로 함께 반영한다.
                val grade = root.optString("grade")
                val classNum = root.optString("classNum")
                if (grade.isNotBlank() && classNum.isNotBlank()) {
                    putString(KEY_GRADE, grade)
                    putString(KEY_CLASS, classNum)
                }
            }
        } catch (error: Exception) {
            Log.w("TimetableWidgetStore", "Failed to save timetable cache", error)
        }
    }

    fun cachedStateForToday(context: Context): String? {
        val prefs = prefs(context)
        val date = prefs.getString(KEY_CACHE_DATE, null) ?: return null
        if (date != todayKey()) return null
        return prefs.getString(KEY_CACHE_STATE, null)
    }

    fun cachedPeriodsForToday(context: Context): List<TimetablePeriod>? {
        if (cachedStateForToday(context) == null) return null
        val raw = prefs(context).getString(KEY_CACHE_PERIODS, null) ?: return null
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val period = item.optInt("period", -1)
                val subject = item.optString("subject")
                if (period < 1 || subject.isBlank()) null else TimetablePeriod(period, subject)
            }
        } catch (error: Exception) {
            null
        }
    }

    /** 네트워크 없이 캐시만으로 초기 상태를 만든다. 확정 못 하면 Loading. */
    fun cachedOnlyState(context: Context): TimetableWidgetState {
        val grade = grade(context)
        val classNum = classNum(context)
        if (grade.isBlank() || classNum.isBlank()) {
            return TimetableWidgetState.ClassNotConfigured
        }
        return when (cachedStateForToday(context)) {
            "available" -> {
                val periods = cachedPeriodsForToday(context)
                if (!periods.isNullOrEmpty()) {
                    TimetableWidgetState.Available(grade, classNum, periods)
                } else {
                    TimetableWidgetState.Loading
                }
            }
            "empty" -> TimetableWidgetState.Empty(grade, classNum)
            else -> TimetableWidgetState.Loading
        }
    }

    private fun todayKey(): String =
        SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
}

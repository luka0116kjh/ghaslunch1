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
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TodayMealWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId, MealWidgetState.Loading)
        }
        refreshWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayMealWidgetProvider::class.java))
            ids.forEach { updateWidget(context, manager, it, MealWidgetState.Loading) }
            refreshWidgets(context, manager, ids)
        }
    }

    private fun refreshWidgets(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        Thread {
            val state = lookupTodayMeal()
            appWidgetIds.forEach { appWidgetId ->
                updateWidget(context, appWidgetManager, appWidgetId, state)
            }
        }.start()
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        state: MealWidgetState
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_today_meal)
        views.setTextViewText(R.id.today_meal_widget_title, context.getString(R.string.widget_today_meal_title))
        views.setTextViewText(R.id.today_meal_widget_menu, state.displayText(context))
        views.setTextViewText(R.id.today_meal_widget_date, todayLabel())
        views.setOnClickPendingIntent(R.id.today_meal_widget_root, openAppIntent(context))
        views.setOnClickPendingIntent(R.id.today_meal_widget_refresh, refreshIntent(context))
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse(APP_URL)
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
        val intent = Intent(context, TodayMealWidgetProvider::class.java).apply {
            action = ACTION_REFRESH
        }
        return PendingIntent.getBroadcast(
            context,
            1,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        )
    }

    private fun lookupTodayMeal(): MealWidgetState {
        val ymd = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())
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
                    return MealWidgetState.Error
                }
                parseMeal(connection.inputStream.bufferedReader().use { it.readText() })
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Today meal widget lookup failed", error)
            MealWidgetState.Error
        }
    }

    private fun parseMeal(json: String): MealWidgetState {
        return try {
            val sections = JSONObject(json).optJSONArray("mealServiceDietInfo")
                ?: return MealWidgetState.Empty
            val rows = findRows(sections) ?: return MealWidgetState.Empty

            var lunch: List<String>? = null
            var firstAny: List<String>? = null
            for (index in 0 until rows.length()) {
                val row = rows.optJSONObject(index) ?: continue
                val items = cleanMenuItems(row.optString("DDISH_NM"))
                if (items.isEmpty()) continue
                if (firstAny == null) firstAny = items
                if (row.optString("MMEAL_SC_CODE") == "2") {
                    lunch = items
                    break
                }
            }

            val items = lunch ?: firstAny ?: return MealWidgetState.Empty
            MealWidgetState.Available(formatMenuLines(items))
        } catch (error: Exception) {
            Log.w(TAG, "Today meal widget parse failed", error)
            MealWidgetState.Error
        }
    }

    private fun findRows(sections: JSONArray): JSONArray? {
        for (index in 0 until sections.length()) {
            val rows = sections.optJSONObject(index)?.optJSONArray("row")
            if (rows != null) return rows
        }
        return null
    }

    private fun cleanMenuItems(raw: String?): List<String> {
        if (raw.isNullOrBlank()) return emptyList()
        return raw
            .replace(Regex("\\([^)]*\\)"), "")
            .replace(Regex("(?i)<br\\s*/?>"), "\n")
            .lines()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
    }

    private fun formatMenuLines(items: List<String>): String {
        return items
            .chunked(2)
            .mapIndexed { index, chunk ->
                val line = chunk.joinToString(" · ")
                if (index < (items.size - 1) / 2) "$line ·" else line
            }
            .joinToString("\n")
    }

    private fun todayLabel(): String =
        SimpleDateFormat("M월 d일 EEEE", Locale.KOREAN).format(Date())

    private fun immutableFlag(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0

    private sealed interface MealWidgetState {
        fun displayText(context: Context): String

        data class Available(val menu: String) : MealWidgetState {
            override fun displayText(context: Context): String = menu
        }

        object Loading : MealWidgetState {
            override fun displayText(context: Context): String =
                context.getString(R.string.widget_today_meal_loading)
        }

        object Empty : MealWidgetState {
            override fun displayText(context: Context): String =
                context.getString(R.string.widget_today_meal_empty)
        }

        object Error : MealWidgetState {
            override fun displayText(context: Context): String =
                context.getString(R.string.widget_today_meal_error)
        }
    }

    companion object {
        private const val TAG = "TodayMealWidget"
        private const val ACTION_REFRESH = "kr.hs.ghas.ghason.action.REFRESH_TODAY_MEAL_WIDGET"
        private const val APP_URL = "https://ghaslunch1.web.app/"
        private const val NEIS_MEAL_URL = "https://open.neis.go.kr/hub/mealServiceDietInfo"
        private const val NEIS_OFFICE_CODE = "J10"
        private const val NEIS_SCHOOL_CODE = "7530908"
        private const val NEIS_TIMEOUT_MS = 4000
    }
}

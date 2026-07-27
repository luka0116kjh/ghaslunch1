package kr.hs.ghas.ghason

import android.webkit.JavascriptInterface

class NativeNotificationBridge(private val activity: MainActivity) {
    @JavascriptInterface
    fun requestNotifications() {
        activity.runOnUiThread {
            activity.setNativeNotificationsEnabled(true)
        }
    }

    @JavascriptInterface
    fun cancelNotifications() {
        activity.runOnUiThread {
            activity.setNativeNotificationsEnabled(false)
        }
    }

    @JavascriptInterface
    fun setNotificationsEnabled(enabled: Boolean) {
        activity.runOnUiThread {
            activity.setNativeNotificationsEnabled(enabled)
        }
    }

    @JavascriptInterface
    fun setNotificationSettings(
        mealEnabled: Boolean,
        timetableEnabled: Boolean,
        schoolNoticeEnabled: Boolean,
        mealTime: String?,
        timetableTime: String?,
        schoolNoticeTime: String?
    ) {
        activity.runOnUiThread {
            activity.updateNativeNotificationSettings(
                mealEnabled,
                timetableEnabled,
                schoolNoticeEnabled,
                mealTime,
                timetableTime,
                schoolNoticeTime
            )
        }
    }

    @JavascriptInterface
    fun setMealNotificationEnabled(enabled: Boolean) {
        setCategoryEnabled("meal", enabled)
    }

    @JavascriptInterface
    fun setTimetableNotificationEnabled(enabled: Boolean) {
        setCategoryEnabled("timetable", enabled)
    }

    @JavascriptInterface
    fun setSchoolNoticeNotificationEnabled(enabled: Boolean) {
        setCategoryEnabled("school_notice", enabled)
    }

    @JavascriptInterface
    fun setMealNotificationTime(time: String?): Boolean =
        activity.setNativeNotificationCategoryTime("meal", time)

    @JavascriptInterface
    fun setTimetableNotificationTime(time: String?): Boolean =
        activity.setNativeNotificationCategoryTime("timetable", time)

    @JavascriptInterface
    fun setSchoolNoticeNotificationTime(time: String?): Boolean =
        activity.setNativeNotificationCategoryTime("school_notice", time)

    @JavascriptInterface
    fun getNotificationSettings(): String = activity.getNativeNotificationSettings()

    @JavascriptInterface
    fun cacheTodayMealContent(renderedTitle: String?, body: String?) {
        activity.cacheTodayMealNotificationContent(renderedTitle, body)
    }

    @JavascriptInterface
    fun cacheTodayTimetableContent(renderedTitle: String?, body: String?) {
        activity.cacheTodayTimetableNotificationContent(renderedTitle, body)
    }

    /** 앱에서 설정한 학년·반을 위젯 공유 저장소에 반영한다. */
    @JavascriptInterface
    fun setStudentClass(grade: String?, classNum: String?) {
        activity.saveStudentClass(grade, classNum)
    }

    /** 웹이 계산한 오늘 시간표(JSON)를 위젯 캐시에 저장하고 위젯을 갱신한다. */
    @JavascriptInterface
    fun cacheTodayTimetable(json: String?) {
        activity.cacheTodayTimetableWidget(json)
    }

    @JavascriptInterface
    fun enableBarcodeScanMode() {
        activity.runOnUiThread {
            activity.enableBarcodeScanMode()
        }
    }

    @JavascriptInterface
    fun disableBarcodeScanMode() {
        activity.runOnUiThread {
            activity.disableBarcodeScanMode()
        }
    }

    @JavascriptInterface
    fun setTheme(theme: String?) {
        activity.saveTheme(theme)
    }

    @JavascriptInterface
    fun getTheme(): String = activity.getSavedTheme()

    @JavascriptInterface
    fun getPlatform(): String = "android"

    @JavascriptInterface
    fun getAppVersion(): String = BuildConfig.VERSION_NAME

    @JavascriptInterface
    fun openExternalUrl(url: String?) {
        activity.openExternalUrl(url)
    }

    private fun setCategoryEnabled(category: String, enabled: Boolean) {
        activity.runOnUiThread {
            activity.setNativeNotificationCategoryEnabled(category, enabled)
        }
    }
}

package kr.hs.ghas.ghason

import android.webkit.JavascriptInterface

class NativeNotificationBridge(private val activity: MainActivity) {
    @JavascriptInterface
    fun requestNotifications() {
        activity.runOnUiThread {
            activity.requestMealNotifications()
        }
    }

    @JavascriptInterface
    fun cancelNotifications() {
        activity.runOnUiThread {
            activity.cancelMealNotifications()
        }
    }

    @JavascriptInterface
    fun setTheme(theme: String?) {
        activity.saveTheme(theme)
    }

    @JavascriptInterface
    fun getTheme(): String = activity.getSavedTheme()

    @JavascriptInterface
    fun cacheNotificationContent(category: String?, date: String?, body: String?) {
        activity.cacheNotificationContent(category, date, body)
    }
}

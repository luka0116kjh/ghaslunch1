package com.ghas.lunch;

import android.webkit.JavascriptInterface;

public class NativeNotificationBridge {
    private final MainActivity activity;

    NativeNotificationBridge(MainActivity activity) {
        this.activity = activity;
    }

    @JavascriptInterface
    public void requestNotifications() {
        activity.runOnUiThread(activity::requestMealNotifications);
    }

    @JavascriptInterface
    public void cancelNotifications() {
        activity.runOnUiThread(activity::cancelMealNotifications);
    }

    @JavascriptInterface
    public void setTheme(String theme) {
        activity.saveTheme(theme);
    }

    @JavascriptInterface
    public String getTheme() {
        return activity.getSavedTheme();
    }
}

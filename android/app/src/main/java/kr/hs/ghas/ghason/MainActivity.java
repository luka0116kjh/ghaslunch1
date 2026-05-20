package kr.hs.ghas.ghason;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.google.firebase.messaging.FirebaseMessaging;

public class MainActivity extends AppCompatActivity {
    static final String NOTIFICATION_TOPIC = "meal";
    static final String NOTIFICATION_CHANNEL_ID = "meal_notifications";
    private static final String PREFS_NAME = "ghas_lunch_preferences";
    private static final String KEY_THEME = "theme";
    private static final String SCHEME_HTTPS = "https";
    private static final String SCHEME_MAILTO = "mailto";
    private static final String APP_URL = "https://ghaslunch1.web.app/?v=20260520-afterschool-select";

    private WebView webView;
    private SharedPreferences preferences;

    private final ActivityResultLauncher<String> notificationPermissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestPermission(), isGranted -> {
                if (isGranted) {
                    subscribeToMealNotifications();
                } else {
                    updateWebNotificationState(false);
                    Toast.makeText(this, "알림 권한이 없어 앱 알림을 받을 수 없습니다.", Toast.LENGTH_SHORT).show();
                }
            });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();
        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setCacheMode(WebSettings.LOAD_NO_CACHE);

        webView.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return handleUrl(request.getUrl());
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, String url) {
                return handleUrl(Uri.parse(url));
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                applySavedThemeToPage();
            }
        });
        NativeNotificationBridge bridge = new NativeNotificationBridge(this);
        webView.addJavascriptInterface(bridge, "GHASAndroidApp");
        webView.addJavascriptInterface(bridge, "GHASAndroidNotifications");
        webView.clearCache(true);
        webView.loadUrl(APP_URL);
        getOnBackPressedDispatcher().addCallback(this, new androidx.activity.OnBackPressedCallback(true) {
            @Override
            public void handleOnBackPressed() {
                if (webView != null && webView.canGoBack()) {
                    webView.goBack();
                    return;
                }
                setEnabled(false);
                getOnBackPressedDispatcher().onBackPressed();
            }
        });
    }

    private boolean handleUrl(Uri uri) {
        if (uri == null) {
            return true;
        }

        String scheme = uri.getScheme();
        String host = uri.getHost();

        // The page uses addJavascriptInterface for the native bridge, so only the
        // trusted HTTPS app hosts may run inside this WebView. Hostless or local
        // schemes such as javascript:, data:, file:, and about: are blocked.
        if (SCHEME_HTTPS.equalsIgnoreCase(scheme) && isTrustedAppHost(host)) {
            return false;
        }

        if (SCHEME_HTTPS.equalsIgnoreCase(scheme) || SCHEME_MAILTO.equalsIgnoreCase(scheme)) {
            openExternally(uri);
        }

        return true;
    }

    private boolean isTrustedAppHost(String host) {
        return "ghaslunch1.web.app".equalsIgnoreCase(host)
                || "ghaslunch1.firebaseapp.com".equalsIgnoreCase(host);
    }

    private void openExternally(Uri uri) {
        try {
            Intent intent = new Intent(Intent.ACTION_VIEW, uri);
            startActivity(intent);
        } catch (ActivityNotFoundException error) {
            Toast.makeText(this, "외부 링크를 열 수 없습니다.", Toast.LENGTH_SHORT).show();
        }
    }

    void requestMealNotifications() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS);
            return;
        }

        subscribeToMealNotifications();
    }

    void cancelMealNotifications() {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(NOTIFICATION_TOPIC)
                .addOnCompleteListener(task -> {
                    updateWebNotificationState(!task.isSuccessful());
                    String message = task.isSuccessful()
                            ? "앱 알림이 취소되었습니다."
                            : "앱 알림 취소에 실패했습니다.";
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                });
    }

    private void subscribeToMealNotifications() {
        FirebaseMessaging.getInstance().subscribeToTopic(NOTIFICATION_TOPIC)
                .addOnCompleteListener(task -> {
                    updateWebNotificationState(task.isSuccessful());
                    String message = task.isSuccessful()
                            ? "앱 알림 설정이 완료되었습니다."
                            : "앱 알림 설정에 실패했습니다.";
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                });
    }

    private void updateWebNotificationState(boolean enabled) {
        if (webView == null) {
            return;
        }

        runOnUiThread(() -> webView.evaluateJavascript(
                "window.setNativeNotificationEnabled && window.setNativeNotificationEnabled(" + enabled + ")",
                null
        ));
    }

    void saveTheme(String theme) {
        if ("dark".equals(theme) || "light".equals(theme)) {
            preferences.edit().putString(KEY_THEME, theme).apply();
        }
    }

    String getSavedTheme() {
        return preferences.getString(KEY_THEME, "");
    }

    private void applySavedThemeToPage() {
        if (webView == null) {
            return;
        }

        String theme = getSavedTheme();
        if (!"dark".equals(theme) && !"light".equals(theme)) {
            return;
        }

        String script = "(function(){"
                + "var theme='" + theme + "';"
                + "try{localStorage.setItem('theme',theme);}catch(e){}"
                + "document.documentElement.classList.toggle('dark-theme',theme==='dark');"
                + "document.documentElement.classList.toggle('light-theme',theme==='light');"
                + "if(document.body){"
                + "document.body.classList.toggle('dark-theme',theme==='dark');"
                + "document.body.classList.toggle('light-theme',theme==='light');"
                + "}"
                + "})();";

        runOnUiThread(() -> webView.evaluateJavascript(script, null));
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationChannel channel = new NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                getString(R.string.meal_notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT
        );
        channel.setDescription(getString(R.string.meal_notification_channel_description));

        NotificationManager notificationManager = getSystemService(NotificationManager.class);
        if (notificationManager != null) {
            notificationManager.createNotificationChannel(channel);
        }
    }
}

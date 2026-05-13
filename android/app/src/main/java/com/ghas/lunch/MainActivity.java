package com.ghas.lunch;

import android.Manifest;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.content.ContextCompat;

import com.google.firebase.messaging.FirebaseMessaging;

public class MainActivity extends AppCompatActivity {
    static final String NOTIFICATION_TOPIC = "meal";
    static final String NOTIFICATION_CHANNEL_ID = "meal_notifications";

    private WebView webView;

    private final ActivityResultLauncher<String> notificationPermissionLauncher =
            registerForActivityResult(new ActivityResultContracts.RequestPermission(), isGranted -> {
                if (isGranted) {
                    subscribeToMealNotifications();
                } else {
                    Toast.makeText(this, "알림 권한이 없어 앱 알림을 받을 수 없습니다.", Toast.LENGTH_SHORT).show();
                }
            });

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannel();

        webView = new WebView(this);
        setContentView(webView);

        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);

        webView.setWebViewClient(new WebViewClient());
        webView.addJavascriptInterface(new NativeNotificationBridge(this), "GHASAndroidNotifications");
        webView.loadUrl("https://ghaslunch1.web.app/");
    }

    @Override
    public void onBackPressed() {
        if (webView != null && webView.canGoBack()) {
            webView.goBack();
            return;
        }
        super.onBackPressed();
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
                    String message = task.isSuccessful()
                            ? "앱 알림이 취소되었습니다."
                            : "앱 알림 취소에 실패했습니다.";
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                });
    }

    private void subscribeToMealNotifications() {
        FirebaseMessaging.getInstance().subscribeToTopic(NOTIFICATION_TOPIC)
                .addOnCompleteListener(task -> {
                    String message = task.isSuccessful()
                            ? "앱 알림 설정이 완료되었습니다."
                            : "앱 알림 설정에 실패했습니다.";
                    Toast.makeText(this, message, Toast.LENGTH_SHORT).show();
                });
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

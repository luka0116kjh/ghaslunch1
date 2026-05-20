package kr.hs.ghas.ghason

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.ViewGroup
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import com.google.firebase.messaging.FirebaseMessaging

class MainActivity : Activity() {
    private lateinit var webView: WebView
    private lateinit var preferences: SharedPreferences
    private val nativeBridge by lazy { NativeNotificationBridge(this) }
    private var bridgeAttached = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        webView = WebView(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            configureSettings(settings)
            webViewClient = createWebViewClient()
        }

        setContentView(webView)
        updateNativeBridge(APP_URL)
        webView.loadUrl(APP_URL)
    }

    private fun configureSettings(settings: WebSettings) {
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
    }

    private fun createWebViewClient(): WebViewClient {
        return object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView,
                request: WebResourceRequest
            ): Boolean = handleUrl(request.url)

            @Deprecated("Deprecated by Android WebView, still called on older devices.")
            override fun shouldOverrideUrlLoading(view: WebView, url: String): Boolean {
                return handleUrl(Uri.parse(url))
            }

            override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                updateNativeBridge(url)
                Log.d(TAG, "Loading $url")
            }

            override fun onPageFinished(view: WebView, url: String?) {
                applySavedThemeToPage()
            }

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: WebResourceError
            ) {
                if (request.isForMainFrame) {
                    Log.e(TAG, "WebView error ${error.errorCode}: ${error.description}")
                }
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse
            ) {
                if (request.isForMainFrame) {
                    Log.e(TAG, "HTTP ${errorResponse.statusCode} while loading ${request.url}")
                }
            }
        }
    }

    private fun handleUrl(uri: Uri?): Boolean {
        if (uri == null) {
            return true
        }

        return when (uri.scheme?.lowercase()) {
            "http", "https" -> {
                updateNativeBridge(uri.toString())
                false
            }
            "mailto", "tel", "sms", "geo" -> {
                openExternally(uri)
                true
            }
            else -> {
                Log.w(TAG, "Blocked unsupported URL scheme: $uri")
                true
            }
        }
    }

    private fun updateNativeBridge(url: String?) {
        val trusted = url?.let { isTrustedAppUri(Uri.parse(it)) } ?: false
        if (trusted && !bridgeAttached) {
            webView.addJavascriptInterface(nativeBridge, "GHASAndroidApp")
            webView.addJavascriptInterface(nativeBridge, "GHASAndroidNotifications")
            bridgeAttached = true
        } else if (!trusted && bridgeAttached) {
            webView.removeJavascriptInterface("GHASAndroidApp")
            webView.removeJavascriptInterface("GHASAndroidNotifications")
            bridgeAttached = false
        }
    }

    private fun isTrustedAppUri(uri: Uri): Boolean {
        if (uri.scheme?.lowercase() != "https") {
            return false
        }

        return uri.host.equals("ghaslunch1.web.app", ignoreCase = true) ||
            uri.host.equals("ghaslunch1.firebaseapp.com", ignoreCase = true)
    }

    private fun openExternally(uri: Uri) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (error: ActivityNotFoundException) {
            Log.e(TAG, "No activity can open $uri", error)
            Toast.makeText(this, R.string.external_link_error, Toast.LENGTH_SHORT).show()
        }
    }

    fun requestMealNotifications() {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
            return
        }

        subscribeToMealNotifications()
    }

    fun cancelMealNotifications() {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(NOTIFICATION_TOPIC)
            .addOnCompleteListener { task ->
                updateWebNotificationState(!task.isSuccessful)
                val message = if (task.isSuccessful) {
                    R.string.notification_disabled
                } else {
                    R.string.notification_disable_failed
                }
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
    }

    private fun subscribeToMealNotifications() {
        FirebaseMessaging.getInstance().subscribeToTopic(NOTIFICATION_TOPIC)
            .addOnCompleteListener { task ->
                updateWebNotificationState(task.isSuccessful)
                val message = if (task.isSuccessful) {
                    R.string.notification_enabled
                } else {
                    R.string.notification_enable_failed
                }
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
            }
    }

    private fun updateWebNotificationState(enabled: Boolean) {
        runOnUiThread {
            webView.evaluateJavascript(
                "window.setNativeNotificationEnabled && window.setNativeNotificationEnabled($enabled)",
                null
            )
        }
    }

    fun saveTheme(theme: String?) {
        if (theme == "dark" || theme == "light") {
            preferences.edit().putString(KEY_THEME, theme).apply()
        }
    }

    fun getSavedTheme(): String = preferences.getString(KEY_THEME, "") ?: ""

    private fun applySavedThemeToPage() {
        val theme = getSavedTheme()
        if (theme != "dark" && theme != "light") {
            return
        }

        val script = """
            (function(){
              var theme='$theme';
              try{localStorage.setItem('theme',theme);}catch(e){}
              document.documentElement.classList.toggle('dark-theme',theme==='dark');
              document.documentElement.classList.toggle('light-theme',theme==='light');
              if(document.body){
                document.body.classList.toggle('dark-theme',theme==='dark');
                document.body.classList.toggle('light-theme',theme==='light');
              }
            })();
        """.trimIndent()

        runOnUiThread {
            webView.evaluateJavascript(script, null)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.meal_notification_channel_name),
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = getString(R.string.meal_notification_channel_description)
        }

        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) {
            return
        }

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            subscribeToMealNotifications()
        } else {
            updateWebNotificationState(false)
            Toast.makeText(this, R.string.notification_permission_denied, Toast.LENGTH_SHORT)
                .show()
        }
    }

    @Suppress("DEPRECATION", "OVERRIDE_DEPRECATION")
    override fun onBackPressed() {
        if (::webView.isInitialized && webView.canGoBack()) {
            webView.goBack()
            return
        }

        super.onBackPressed()
    }

    override fun onDestroy() {
        if (::webView.isInitialized) {
            webView.destroy()
        }
        super.onDestroy()
    }

    companion object {
        const val NOTIFICATION_CHANNEL_ID = "meal_notifications"
        const val NOTIFICATION_TOPIC = "meal"

        private const val APP_URL = "https://ghaslunch1.web.app/"
        private const val KEY_THEME = "theme"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1001
        private const val PREFS_NAME = "ghas_lunch_preferences"
        private const val TAG = "GHASLunch"
    }
}

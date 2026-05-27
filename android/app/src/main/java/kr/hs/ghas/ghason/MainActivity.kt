package kr.hs.ghas.ghason

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.TimePickerDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.content.res.ColorStateList
import android.content.res.Configuration
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.widget.TextView
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import com.google.firebase.messaging.FirebaseMessaging
import java.util.Locale

class MainActivity : ComponentActivity() {
    private lateinit var webView: WebView
    private lateinit var preferences: SharedPreferences
    private lateinit var fileChooserLauncher: ActivityResultLauncher<Intent>
    private lateinit var notificationPermissionLauncher: ActivityResultLauncher<String>
    private lateinit var notificationSettingsCard: LinearLayout
    private lateinit var notificationSettingsIcon: ImageView
    private lateinit var notificationSettingsLabel: TextView
    private val nativeBridge by lazy { NativeNotificationBridge(this) }
    private val notificationScheduler by lazy { NativeNotificationScheduler(applicationContext) }
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var bridgeAttached = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerActivityResultLaunchers()
        notificationScheduler.createNotificationChannels()

        preferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        webView = WebView(this).apply {
            configureSettings(settings)
            webViewClient = createWebViewClient()
            webChromeClient = createWebChromeClient()
        }

        val contentView = FrameLayout(this).apply {
            addView(webView)
            addView(createNotificationSettingsButton())
        }
        setContentView(contentView)
        registerBackHandler()
        updateNativeBridge(APP_URL)
        webView.loadUrl(APP_URL)
    }

    private fun registerBackHandler() {
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() {
                    if (::webView.isInitialized && webView.canGoBack()) {
                        webView.goBack()
                    } else {
                        finish()
                    }
                }
            }
        )
    }

    private fun registerActivityResultLaunchers() {
        fileChooserLauncher = registerForActivityResult(
            ActivityResultContracts.StartActivityForResult()
        ) { result ->
            val results = if (result.resultCode == Activity.RESULT_OK) {
                result.data?.let { collectFileChooserResults(it) } ?: emptyArray()
            } else {
                null
            }
            fileChooserCallback?.onReceiveValue(results)
            fileChooserCallback = null
        }

        notificationPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (granted) {
                notificationScheduler.scheduleSelectedNotifications()
                updateWebNotificationState(true)
                Toast.makeText(this, R.string.notification_enabled, Toast.LENGTH_SHORT).show()
            } else {
                notificationScheduler.setMasterEnabled(false)
                notificationScheduler.cancelAllLocalNotifications()
                updateWebNotificationState(false)
                Toast.makeText(
                    this,
                    R.string.notification_permission_denied,
                    Toast.LENGTH_SHORT
                )
                    .show()
            }
        }

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
                syncNativeThemeFromPage()
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

    private fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onShowFileChooser(
                webView: WebView,
                filePathCallback: ValueCallback<Array<Uri>>,
                fileChooserParams: FileChooserParams
            ): Boolean {
                this@MainActivity.fileChooserCallback?.onReceiveValue(null)
                this@MainActivity.fileChooserCallback = filePathCallback

                val acceptTypes = fileChooserParams.acceptTypes
                    ?.filter { it.isNotBlank() }
                    ?.toTypedArray()
                    ?: emptyArray()
                val mimeType = acceptTypes.firstOrNull()
                    ?.takeIf { it != "*/*" }
                    ?: "image/*"

                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    putExtra(Intent.EXTRA_MIME_TYPES, acceptTypes.ifEmpty { arrayOf("image/*") })
                    putExtra(
                        Intent.EXTRA_ALLOW_MULTIPLE,
                        fileChooserParams.mode == FileChooserParams.MODE_OPEN_MULTIPLE
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                }

                return try {
                    fileChooserLauncher.launch(intent)
                    true
                } catch (error: ActivityNotFoundException) {
                    Log.e(TAG, "No activity can choose an image", error)
                    this@MainActivity.fileChooserCallback = null
                    filePathCallback.onReceiveValue(null)
                    false
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

    private fun createNotificationSettingsButton(): LinearLayout {
        notificationSettingsIcon = ImageView(this).apply {
            setImageResource(R.drawable.ic_notifications)
            layoutParams = LinearLayout.LayoutParams(dp(20), dp(20))
        }
        notificationSettingsLabel = TextView(this).apply {
            text = getString(R.string.notification_settings_button)
            textSize = 14f
            setPadding(dp(8), 0, 0, 0)
        }
        return LinearLayout(this).apply {
            notificationSettingsCard = this
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            contentDescription = getString(R.string.notification_settings_title)
            isClickable = true
            isFocusable = true
            elevation = dp(5).toFloat()
            setPadding(dp(14), dp(11), dp(16), dp(11))
            addView(notificationSettingsIcon)
            addView(notificationSettingsLabel)
            setOnClickListener { showNotificationSettingsDialog() }
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.END or Gravity.BOTTOM
            ).apply {
                val margin = dp(14)
                setMargins(margin, margin, margin, margin)
            }
            applyNativeThemeToCard()
        }
    }

    private fun showNotificationSettingsDialog() {
        val palette = nativePalette()
        val current = notificationScheduler.settings()
        var mealTime = current.mealTime
        var timetableTime = current.timetableTime
        var schoolNoticeTime = current.schoolNoticeTime

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(10), dp(22), dp(10))
        }
        val masterSwitch = createNotificationSwitch(
            R.string.notification_master_enabled,
            current.enabled,
            palette
        )
        val mealSwitch = createNotificationSwitch(
            R.string.notification_meal_enabled,
            current.mealEnabled,
            palette
        )
        val mealTimeButton = createNotificationTimeButton(
            R.string.notification_meal_time,
            mealTime,
            palette
        )
        val timetableSwitch = createNotificationSwitch(
            R.string.notification_timetable_enabled,
            current.timetableEnabled,
            palette
        )
        val timetableTimeButton = createNotificationTimeButton(
            R.string.notification_timetable_time,
            timetableTime,
            palette
        )
        val schoolNoticeSwitch = createNotificationSwitch(
            R.string.notification_school_notice_enabled,
            current.schoolNoticeEnabled,
            palette
        )
        val schoolNoticeTimeButton = createNotificationTimeButton(
            R.string.notification_school_notice_time,
            schoolNoticeTime,
            palette
        )

        content.addView(masterSwitch)
        content.addView(mealSwitch)
        content.addView(mealTimeButton)
        content.addView(timetableSwitch)
        content.addView(timetableTimeButton)
        content.addView(schoolNoticeSwitch)
        content.addView(schoolNoticeTimeButton)

        fun updateAvailability() {
            val masterEnabled = masterSwitch.isChecked
            mealSwitch.isEnabled = masterEnabled
            timetableSwitch.isEnabled = masterEnabled
            schoolNoticeSwitch.isEnabled = masterEnabled
            mealTimeButton.isEnabled = masterEnabled && mealSwitch.isChecked
            timetableTimeButton.isEnabled = masterEnabled && timetableSwitch.isChecked
            schoolNoticeTimeButton.isEnabled =
                masterEnabled && schoolNoticeSwitch.isChecked
        }

        masterSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        mealSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        timetableSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        schoolNoticeSwitch.setOnCheckedChangeListener { _, _ -> updateAvailability() }
        mealTimeButton.setOnClickListener {
            showTimePicker(mealTime) { selectedTime ->
                mealTime = selectedTime
                updateNotificationTimeButton(
                    mealTimeButton,
                    R.string.notification_meal_time,
                    selectedTime
                )
            }
        }
        timetableTimeButton.setOnClickListener {
            showTimePicker(timetableTime) { selectedTime ->
                timetableTime = selectedTime
                updateNotificationTimeButton(
                    timetableTimeButton,
                    R.string.notification_timetable_time,
                    selectedTime
                )
            }
        }
        schoolNoticeTimeButton.setOnClickListener {
            showTimePicker(schoolNoticeTime) { selectedTime ->
                schoolNoticeTime = selectedTime
                updateNotificationTimeButton(
                    schoolNoticeTimeButton,
                    R.string.notification_school_notice_time,
                    selectedTime
                )
            }
        }
        updateAvailability()

        val dialog = AlertDialog.Builder(this)
            .setTitle(R.string.notification_settings_title)
            .setView(ScrollView(this).apply { addView(content) })
            .setNegativeButton(R.string.notification_settings_cancel, null)
            .setPositiveButton(R.string.notification_settings_save) { _, _ ->
                updateNativeNotificationSettings(
                    masterSwitch.isChecked,
                    mealSwitch.isChecked,
                    timetableSwitch.isChecked,
                    schoolNoticeSwitch.isChecked,
                    mealTime,
                    timetableTime,
                    schoolNoticeTime
                )
            }
            .create()
        dialog.setOnShowListener {
            dialog.window?.setBackgroundDrawable(
                roundedBackground(palette.surface, palette.border, 24)
            )
            dialog.findViewById<TextView>(
                resources.getIdentifier("alertTitle", "id", "android")
            )?.setTextColor(palette.text)
            dialog.getButton(AlertDialog.BUTTON_POSITIVE)?.setTextColor(palette.accent)
            dialog.getButton(AlertDialog.BUTTON_NEGATIVE)?.setTextColor(palette.accent)
        }
        dialog.show()
    }

    private fun createNotificationSwitch(
        labelResId: Int,
        checked: Boolean,
        palette: NativePalette
    ): Switch =
        Switch(this).apply {
            text = getString(labelResId)
            isChecked = checked
            setTextColor(palette.text)
            buttonTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(palette.accent, palette.muted)
            )
            thumbTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(palette.accent, palette.muted)
            )
            trackTintList = ColorStateList(
                arrayOf(
                    intArrayOf(android.R.attr.state_checked),
                    intArrayOf()
                ),
                intArrayOf(
                    Color.argb(110, Color.red(palette.accent), Color.green(palette.accent), Color.blue(palette.accent)),
                    palette.border
                )
            )
            setPadding(0, dp(10), 0, dp(10))
        }

    private fun createNotificationTimeButton(
        labelResId: Int,
        time: String,
        palette: NativePalette
    ): Button =
        Button(this).apply {
            isAllCaps = false
            minHeight = 0
            minimumHeight = 0
            setTextColor(palette.text)
            background = roundedBackground(palette.control, palette.border, 16)
            setPadding(dp(12), dp(7), dp(12), dp(7))
            updateNotificationTimeButton(this, labelResId, time)
        }

    private fun updateNotificationTimeButton(button: Button, labelResId: Int, time: String) {
        button.text = getString(R.string.notification_time_format, getString(labelResId), time)
    }

    private fun showTimePicker(time: String, onSelected: (String) -> Unit) {
        val timeParts = time.split(":")
        TimePickerDialog(
            this,
            { _, hour, minute ->
                onSelected(String.format(Locale.US, "%02d:%02d", hour, minute))
            },
            timeParts[0].toInt(),
            timeParts[1].toInt(),
            true
        ).show()
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private fun applyNativeThemeToCard() {
        if (!::notificationSettingsCard.isInitialized) {
            return
        }
        val palette = nativePalette()
        notificationSettingsCard.background =
            roundedBackground(palette.surface, palette.border, 22)
        notificationSettingsLabel.setTextColor(palette.text)
        notificationSettingsIcon.setColorFilter(palette.accent)
    }

    private fun nativePalette(): NativePalette {
        val dark = when (getSavedTheme()) {
            "dark" -> true
            "light" -> false
            else -> (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
                Configuration.UI_MODE_NIGHT_YES
        }
        return if (dark) {
            NativePalette(
                surface = Color.parseColor("#242424"),
                control = Color.parseColor("#303030"),
                text = Color.parseColor("#F5F7FA"),
                border = Color.parseColor("#383838"),
                muted = Color.parseColor("#70757D"),
                accent = Color.parseColor("#0B73FF")
            )
        } else {
            NativePalette(
                surface = Color.WHITE,
                control = Color.parseColor("#F5F7FB"),
                text = Color.parseColor("#20242A"),
                border = Color.parseColor("#E4E8EF"),
                muted = Color.parseColor("#B8C0CC"),
                accent = Color.parseColor("#0B73FF")
            )
        }
    }

    private fun roundedBackground(fillColor: Int, strokeColor: Int, radiusDp: Int) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = dp(radiusDp).toFloat()
            setColor(fillColor)
            setStroke(dp(1), strokeColor)
        }

    private data class NativePalette(
        val surface: Int,
        val control: Int,
        val text: Int,
        val border: Int,
        val muted: Int,
        val accent: Int
    )

    fun setNativeNotificationsEnabled(enabled: Boolean) {
        notificationScheduler.setMasterEnabled(enabled)
        if (!enabled) {
            notificationScheduler.cancelAllLocalNotifications()
            unsubscribeFromLegacyMealTopic()
            updateWebNotificationState(false)
            Toast.makeText(this, R.string.notification_disabled, Toast.LENGTH_SHORT).show()
            return
        }

        requestNotificationPermissionAndSchedule(showConfirmation = true)
    }

    fun updateNativeNotificationSettings(
        enabled: Boolean,
        mealEnabled: Boolean,
        timetableEnabled: Boolean,
        schoolNoticeEnabled: Boolean,
        mealTime: String?,
        timetableTime: String?,
        schoolNoticeTime: String?
    ) {
        notificationScheduler.updateSettings(
            enabled,
            mealEnabled,
            timetableEnabled,
            schoolNoticeEnabled,
            mealTime,
            timetableTime,
            schoolNoticeTime
        )
        if (!enabled) {
            setNativeNotificationsEnabled(false)
            return
        }

        requestNotificationPermissionAndSchedule(showConfirmation = false)
    }

    fun setNativeNotificationCategoryEnabled(categoryKey: String, enabled: Boolean) {
        val category = NativeNotificationCategory.fromKey(categoryKey) ?: return
        notificationScheduler.setCategoryEnabled(category, enabled)
        if (!enabled) {
            notificationScheduler.cancelCategory(category, cancelVisible = true)
            return
        }

        if (notificationScheduler.settings().enabled) {
            requestNotificationPermissionAndSchedule(showConfirmation = false)
        }
    }

    fun setNativeNotificationCategoryTime(categoryKey: String, time: String?): Boolean {
        val category = NativeNotificationCategory.fromKey(categoryKey) ?: return false
        val saved = notificationScheduler.setCategoryTime(category, time)
        if (
            saved &&
            notificationScheduler.settings().enabled &&
            notificationScheduler.canPostNotifications()
        ) {
            notificationScheduler.scheduleSelectedNotifications()
        }
        return saved
    }

    fun getNativeNotificationSettings(): String = notificationScheduler.settingsJson()

    fun cacheTodayMealNotificationContent(renderedTitle: String?, body: String?) {
        notificationScheduler.cacheTodayMealContent(renderedTitle, body)
    }

    fun cacheTodayTimetableNotificationContent(renderedTitle: String?, body: String?) {
        notificationScheduler.cacheTodayTimetableContent(renderedTitle, body)
    }

    private fun requestNotificationPermissionAndSchedule(showConfirmation: Boolean) {
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            return
        }

        notificationScheduler.scheduleSelectedNotifications()
        updateWebNotificationState(true)
        if (showConfirmation) {
            Toast.makeText(this, R.string.notification_enabled, Toast.LENGTH_SHORT).show()
        }
    }

    private fun unsubscribeFromLegacyMealTopic() {
        FirebaseMessaging.getInstance().unsubscribeFromTopic(NOTIFICATION_TOPIC)
            .addOnCompleteListener { task ->
                if (!task.isSuccessful) {
                    Log.w(TAG, "Failed to unsubscribe from legacy meal FCM topic", task.exception)
                }
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
            runOnUiThread { applyNativeThemeToCard() }
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

    private fun syncNativeThemeFromPage() {
        webView.evaluateJavascript(
            "(function(){try{return localStorage.getItem('theme') || '';}catch(e){return '';}})();"
        ) { value ->
            val theme = value?.trim()?.trim('"')
            if (theme == "dark" || theme == "light") {
                saveTheme(theme)
            } else {
                applyNativeThemeToCard()
            }
        }
    }

    private fun collectFileChooserResults(data: Intent): Array<Uri> {
        val result = mutableListOf<Uri>()
        data.clipData?.let { clipData ->
            for (index in 0 until clipData.itemCount) {
                clipData.getItemAt(index)?.uri?.let { uri ->
                    persistReadPermission(uri)
                    result += uri
                }
            }
        }

        data.data?.let { uri ->
            persistReadPermission(uri)
            result += uri
        }

        return result.distinct().toTypedArray()
    }

    private fun persistReadPermission(uri: Uri) {
        try {
            contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        } catch (error: SecurityException) {
            Log.d(TAG, "Read permission is transient for $uri")
        } catch (error: IllegalArgumentException) {
            Log.d(TAG, "URI does not support persistable permission: $uri")
        }
    }

    override fun onDestroy() {
        fileChooserCallback?.onReceiveValue(null)
        fileChooserCallback = null
        if (::webView.isInitialized) {
            webView.destroy()
        }
        super.onDestroy()
    }

    companion object {
        const val NOTIFICATION_TOPIC = "meal"

        private const val APP_URL = "https://ghaslunch1.web.app/"
        private const val PREFS_NAME = "ghas_lunch_preferences"
        private const val KEY_THEME = "theme"
        private const val TAG = "GHASLunch"
    }
}

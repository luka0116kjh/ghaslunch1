package kr.hs.ghas.ghason

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.TimePickerDialog
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
<<<<<<< HEAD
=======
import android.util.TypedValue
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Switch
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.Switch
import android.widget.TextView
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
    private lateinit var localNotificationPermissionLauncher: ActivityResultLauncher<String>
    private val nativeBridge by lazy { NativeNotificationBridge(this) }
    private val notificationScheduler by lazy { NativeNotificationScheduler(applicationContext) }
    private var fileChooserCallback: ValueCallback<Array<Uri>>? = null
    private var bridgeAttached = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerActivityResultLaunchers()
<<<<<<< HEAD
        notificationScheduler.createNotificationChannels()
=======
        NativeNotificationScheduler.createChannels(this)
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14

        preferences = getSharedPreferences(NativeNotificationScheduler.PREFS_NAME, MODE_PRIVATE)
        webView = WebView(this).apply {
            configureSettings(settings)
            webViewClient = createWebViewClient()
            webChromeClient = createWebChromeClient()
        }

<<<<<<< HEAD
        val contentView = FrameLayout(this).apply {
            addView(webView)
            addView(createNotificationSettingsButton())
        }
        setContentView(contentView)
=======
        setContentView(createNativeShell())
>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
        registerBackHandler()
        updateNativeBridge(APP_URL)
        webView.loadUrl(APP_URL)
    }

    private fun createNativeShell(): LinearLayout {
        val shell = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
        }
        shell.addView(
            webView,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                1f
            )
        )
        shell.addView(createNotificationToolbar())
        return shell
    }

    private fun createNotificationToolbar(): FrameLayout {
        val toolbar = FrameLayout(this).apply {
            setBackgroundColor(Color.WHITE)
            elevation = dp(2).toFloat()
        }
        val button = ImageButton(this).apply {
            setImageResource(R.drawable.ic_notifications)
            contentDescription = getString(R.string.notification_settings_open)
            setColorFilter(Color.rgb(45, 45, 45))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(245, 245, 245))
            }
            setPadding(dp(11), dp(11), dp(11), dp(11))
            setOnClickListener { showNotificationSettingsDialog() }
        }
        toolbar.addView(
            button,
            FrameLayout.LayoutParams(dp(44), dp(44), Gravity.END or Gravity.CENTER_VERTICAL).apply {
                marginEnd = dp(16)
            }
        )
        return toolbar.apply {
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(56)
            )
        }
    }

    private fun showNotificationSettingsDialog() {
        val form = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(8), dp(24), 0)
        }
        val enabled = notificationSwitch(
            R.string.notification_settings_enable,
            preferences.getBoolean(NativeNotificationScheduler.KEY_NOTIFICATIONS_ENABLED, false)
        )
        val meal = categorySettingsRow(
            labelResId = R.string.notification_settings_meal,
            enabled = preferences.getBoolean(NativeNotificationScheduler.KEY_MEAL_NOTIFICATIONS, false),
            hour = preferences.getInt(NativeNotificationScheduler.KEY_MEAL_HOUR, 11),
            minute = preferences.getInt(NativeNotificationScheduler.KEY_MEAL_MINUTE, 0)
        )
        val timetable = categorySettingsRow(
            labelResId = R.string.notification_settings_timetable,
            enabled = preferences.getBoolean(NativeNotificationScheduler.KEY_TIMETABLE_NOTIFICATIONS, false),
            hour = preferences.getInt(NativeNotificationScheduler.KEY_TIMETABLE_HOUR, 7),
            minute = preferences.getInt(NativeNotificationScheduler.KEY_TIMETABLE_MINUTE, 30)
        )
        val notice = categorySettingsRow(
            labelResId = R.string.notification_settings_notice,
            enabled = preferences.getBoolean(NativeNotificationScheduler.KEY_NOTICE_NOTIFICATIONS, false),
            hour = preferences.getInt(NativeNotificationScheduler.KEY_NOTICE_HOUR, 18),
            minute = preferences.getInt(NativeNotificationScheduler.KEY_NOTICE_MINUTE, 0)
        )
        val detailSwitches = listOf(meal, timetable, notice)
        val setDetailState = { available: Boolean ->
            detailSwitches.forEach { it.setAvailable(available) }
        }

        setDetailState(enabled.isChecked)
        enabled.setOnCheckedChangeListener { _, checked -> setDetailState(checked) }
        form.addView(enabled)
        listOf(meal, timetable, notice).forEach { form.addView(it.view) }

        AlertDialog.Builder(this)
            .setTitle(R.string.notification_settings_title)
            .setView(form)
            .setNegativeButton(android.R.string.cancel, null)
            .setPositiveButton(R.string.notification_settings_save) { _, _ ->
                saveNotificationPreferences(
                    enabled.isChecked,
                    meal,
                    timetable,
                    notice
                )
            }
            .show()
    }

    private fun notificationSwitch(labelResId: Int, checked: Boolean): Switch {
        return Switch(this).apply {
            text = getString(labelResId)
            isChecked = checked
            textSize = 16f
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(8), 0, dp(8))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(52)
            )
        }
    }

    private fun categorySettingsRow(
        labelResId: Int,
        enabled: Boolean,
        hour: Int,
        minute: Int
    ): CategorySettingsRow {
        val toggle = Switch(this).apply {
            text = getString(labelResId)
            isChecked = enabled
            textSize = 16f
            gravity = Gravity.CENTER_VERTICAL
        }
        val timeButton = TextView(this).apply {
            gravity = Gravity.CENTER
            textSize = 15f
            setTextColor(Color.rgb(45, 45, 45))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.rgb(245, 245, 245))
            }
            setPadding(dp(13), 0, dp(13), 0)
        }
        val state = CategorySettingsRow(toggle, timeButton, hour, minute)
        state.updateTimeLabel()
        timeButton.setOnClickListener {
            TimePickerDialog(this, { _, selectedHour, selectedMinute ->
                state.hour = selectedHour
                state.minute = selectedMinute
                state.updateTimeLabel()
            }, state.hour, state.minute, true).show()
        }
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, dp(5), 0, dp(5))
            addView(
                toggle,
                LinearLayout.LayoutParams(0, dp(52), 1f)
            )
            addView(
                timeButton,
                LinearLayout.LayoutParams(dp(76), dp(38))
            )
        }
        state.view = row
        return state
    }

    private fun saveNotificationPreferences(
        enabled: Boolean,
        meal: CategorySettingsRow,
        timetable: CategorySettingsRow,
        notice: CategorySettingsRow
    ) {
        preferences.edit()
            .putBoolean(NativeNotificationScheduler.KEY_NOTIFICATIONS_ENABLED, enabled)
            .putBoolean(NativeNotificationScheduler.KEY_MEAL_NOTIFICATIONS, meal.toggle.isChecked)
            .putBoolean(NativeNotificationScheduler.KEY_TIMETABLE_NOTIFICATIONS, timetable.toggle.isChecked)
            .putBoolean(NativeNotificationScheduler.KEY_NOTICE_NOTIFICATIONS, notice.toggle.isChecked)
            .putInt(NativeNotificationScheduler.KEY_MEAL_HOUR, meal.hour)
            .putInt(NativeNotificationScheduler.KEY_MEAL_MINUTE, meal.minute)
            .putInt(NativeNotificationScheduler.KEY_TIMETABLE_HOUR, timetable.hour)
            .putInt(NativeNotificationScheduler.KEY_TIMETABLE_MINUTE, timetable.minute)
            .putInt(NativeNotificationScheduler.KEY_NOTICE_HOUR, notice.hour)
            .putInt(NativeNotificationScheduler.KEY_NOTICE_MINUTE, notice.minute)
            .apply()

        if (!enabled) {
            NativeNotificationScheduler.cancelAll(this)
        } else if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            NativeNotificationScheduler.cancelAll(this)
            localNotificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            NativeNotificationScheduler.applySavedSettings(this)
        }

        // TODO(FCM): register the device token and remote category subscriptions only
        // when server-driven push delivery is introduced.
        Toast.makeText(this, R.string.notification_settings_saved, Toast.LENGTH_SHORT).show()
    }

    private class CategorySettingsRow(
        val toggle: Switch,
        private val timeLabel: TextView,
        var hour: Int,
        var minute: Int
    ) {
        lateinit var view: LinearLayout

        fun updateTimeLabel() {
            timeLabel.text = String.format("%02d:%02d", hour, minute)
        }

        fun setAvailable(available: Boolean) {
            toggle.isEnabled = available
            timeLabel.isEnabled = available
            timeLabel.alpha = if (available) 1f else 0.45f
        }
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics
    ).toInt()

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

        localNotificationPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestPermission()
        ) { granted ->
            if (granted) {
                NativeNotificationScheduler.applySavedSettings(this)
            } else {
                NativeNotificationScheduler.cancelAll(this)
                Toast.makeText(this, R.string.notification_permission_denied, Toast.LENGTH_SHORT)
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
                installNotificationContentCacheBridge()
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

    private fun createNotificationSettingsButton(): Button =
        Button(this).apply {
            text = getString(R.string.notification_settings_button)
            contentDescription = getString(R.string.notification_settings_title)
            isAllCaps = false
            elevation = dp(4).toFloat()
            setOnClickListener { showNotificationSettingsDialog() }
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.END or Gravity.BOTTOM
            ).apply {
                val margin = dp(16)
                setMargins(margin, margin, margin, margin)
            }
        }

    private fun showNotificationSettingsDialog() {
        val current = notificationScheduler.settings()
        var mealTime = current.mealTime
        var timetableTime = current.timetableTime
        var schoolNoticeTime = current.schoolNoticeTime

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(8), dp(20), dp(8))
        }
        val masterSwitch = createNotificationSwitch(
            R.string.notification_master_enabled,
            current.enabled
        )
        val mealSwitch = createNotificationSwitch(
            R.string.notification_meal_enabled,
            current.mealEnabled
        )
        val mealTimeButton = createNotificationTimeButton(
            R.string.notification_meal_time,
            mealTime
        )
        val timetableSwitch = createNotificationSwitch(
            R.string.notification_timetable_enabled,
            current.timetableEnabled
        )
        val timetableTimeButton = createNotificationTimeButton(
            R.string.notification_timetable_time,
            timetableTime
        )
        val schoolNoticeSwitch = createNotificationSwitch(
            R.string.notification_school_notice_enabled,
            current.schoolNoticeEnabled
        )
        val schoolNoticeTimeButton = createNotificationTimeButton(
            R.string.notification_school_notice_time,
            schoolNoticeTime
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

        AlertDialog.Builder(this)
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
            .show()
    }

    private fun createNotificationSwitch(labelResId: Int, checked: Boolean): Switch =
        Switch(this).apply {
            text = getString(labelResId)
            isChecked = checked
            setPadding(0, dp(8), 0, dp(8))
        }

    private fun createNotificationTimeButton(labelResId: Int, time: String): Button =
        Button(this).apply {
            isAllCaps = false
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
        }
    }

    fun getSavedTheme(): String = preferences.getString(KEY_THEME, "") ?: ""

    fun cacheNotificationContent(category: String?, date: String?, body: String?) {
        NativeNotificationScheduler.cacheContent(this, category, date, body)
    }

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

<<<<<<< HEAD
=======
    private fun installNotificationContentCacheBridge() {
        val script = """
            (function () {
              var nativeApp = window.GHASAndroidApp;
              if (!nativeApp || typeof nativeApp.cacheNotificationContent !== 'function') return;
              var todayKey = function () {
                var d = new Date();
                return String(d.getFullYear()) +
                  String(d.getMonth() + 1).padStart(2, '0') +
                  String(d.getDate()).padStart(2, '0');
              };
              var compact = function (value) {
                return String(value || '').replace(/\s+/g, ' ').trim();
              };
              var invalid = function (value) {
                return !value || /불러오는 중|정보가 없습니다|불러오지 못했습니다|주말|휴일/.test(value);
              };
              var flush = function () {
                var mealTitle = compact(document.getElementById('meal-view-title') && document.getElementById('meal-view-title').innerText);
                var lunch = document.getElementById('lunch-menu');
                var lunchText = compact(lunch && lunch.innerText);
                if (mealTitle === '오늘의 급식' && !invalid(lunchText)) {
                  nativeApp.cacheNotificationContent('meal', todayKey(), ('오늘 중식: ' + lunchText).slice(0, 240));
                }

                var title = compact(document.getElementById('timetable-title') && document.getElementById('timetable-title').innerText);
                var rows = Array.prototype.slice.call(document.querySelectorAll('#timetable-list .timetable-row')).map(function (row) {
                  var period = compact(row.querySelector('.period') && row.querySelector('.period').innerText);
                  var subject = compact(row.querySelector('.subject') && row.querySelector('.subject').innerText);
                  return period && subject && subject !== '공강' ? period + ' ' + subject : '';
                }).filter(Boolean);
                if (title === '오늘 시간표' && rows.length) {
                  nativeApp.cacheNotificationContent('timetable', todayKey(), ('오늘 시간표: ' + rows.join(', ')).slice(0, 240));
                }
              };
              if (!window.__ghasNativeContentCollector) {
                var observer = new MutationObserver(flush);
                observer.observe(document.body, { childList: true, subtree: true, characterData: true });
                window.__ghasNativeContentCollector = { flush: flush, observer: observer };
              }
              window.__ghasNativeContentCollector.flush();
            }());
        """.trimIndent()
        webView.evaluateJavascript(script, null)
    }

>>>>>>> 5ea2f2af732af2e5459223a63d5b151b06745e14
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
        private const val KEY_THEME = "theme"
        private const val TAG = "GHASLunch"
    }
}
